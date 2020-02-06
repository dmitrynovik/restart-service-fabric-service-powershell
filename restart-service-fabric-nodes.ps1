Param (
    [string] $ConnectionEndpoint = "localhost:19000",
    [int] $DisableNodeTimeout = 600
)

$DefaultPort = 19000;
if (-Not $ConnectionEndpoint.Contains(":")) {
    $ConnectionEndpoint = $ConnectionEndpoint + ":" + $DefaultPort;
}

Write-Host "Restarting nodes on cluster: $ConnectionEndpoint" -ForegroundColor Red

try {
    Write-Host "Connecting to $ConnectionEndpoint ..." -ForegroundColor Yellow
    Connect-ServiceFabricCluster -ConnectionEndpoint $ConnectionEndpoint | Out-Null
    Write-Host "  -> success!" -ForegroundColor Green
} catch {
    throw "Could not connect to $ConnectionEndpoint"
}

$nodes = Get-ServiceFabricNode -StatusFilter Up

$nodes | ForEach-Object {
    $nodeName = $_.NodeName

    Write-Host "  Disabling node $nodeName ..." -ForegroundColor Yellow
    Disable-ServiceFabricNode -NodeName $nodeName -Force -Intent Restart -TimeoutSec $DisableNodeTimeout
    $elapsedTime = 0
    $disabled = $false

    while ($true)  {
       $nodeState = Get-ServiceFabricNode $nodeName
       $nodeStatus = $nodeState.NodeStatus  
       if ($elapsedTime -gt $DisableNodeTimeout) {
            Write-Host "    Failed to timely disable node $nodeName" -ForegroundColor Red
    } elseif ($nodeStatus -eq [System.Fabric.Query.NodeStatus]::Up -or `
            $nodeStatus -eq [System.Fabric.Query.NodeStatus]::Disabling -or `
            $nodeStatus -eq [System.Fabric.Query.NodeStatus]::Enabling) {
            $timeToSleep = 1
            Write-Host "    Status of $nodeName : $nodeStatus, waiting $timeToSleep seconds ($elapsedTime out of $DisableNodeTimeout)..."
            Start-Sleep -Seconds $timeToSleep
            $elapsedTime += 1
       } else {
            $disabled = $true
            Write-Host "    Node $nodeName disabled"
            Break
       }
    } 

    if ($disabled) {
        Write-Host "  Restarting node $nodeName ..."
        Restart-ServiceFabricNode -NodeName $nodeName -CommandCompletionMode Verify

        Write-Host "  Enabling node $nodeName ..."
        Enable-ServiceFabricNode -NodeName $nodeName
    }
}

Write-Host "Done" -ForegroundColor Green
    