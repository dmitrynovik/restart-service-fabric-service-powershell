Param (
    [Parameter(Mandatory=$true)] [uri[]] $Apps,
    [string] $ConnectionEndpoint = "localhost:19000"
)

Write-Host "Restarting apps [$Apps] on cluster: $ConnectionEndpoint" -ForegroundColor Red

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
    Write-Host "Processing node: $nodeName" -ForegroundColor Yellow

    $restartAppJobs = New-Object Collections.Generic.List[Int]

    $Apps | ForEach-Object {

        $applicationName = $_            

        $restartAppJob = Start-Job -Name $nodeName+":"+$applicationName `
            -ArgumentList $ConnectionEndpoint, $nodeName, $applicationName `
            -ScriptBlock { 
            param([uri] $ConnectionEndpoint, [string] $nodeName, [string] $applicationName)

            if (-Not $applicationName.ToString().StartsWith("fabric:/")) {
                $applicationName = "fabric:/" + $applicationName;
            }

            try {
                Write-Host "Connecting to $ConnectionEndpoint ..." -ForegroundColor Yellow
                Connect-ServiceFabricCluster -ConnectionEndpoint $ConnectionEndpoint | Out-Null
                Write-Host "  -> success!" -ForegroundColor Green
            } catch {
                throw "Could not connect to $ConnectionEndpoint"
            }
                    
            $replicas = Get-ServiceFabricDeployedReplica -NodeName $nodeName -ApplicationName $applicationName

            $replicas | ForEach-Object {
                $partitionId = $_.partitionId
                $instanceId = $_.instanceId
                $serviceManifestName = $_.ServiceManifestName
                $codePackageName = $_.CodePackageName
                $serviceName = $_.ServiceName;

                Write-Host "  Restarting the service: $serviceName" -ForegroundColor Magenta

                # Remove the replica from the Node:
                Write-Host "    Removing $serviceName replica (partitionId: $partitionId, instanceId: $instanceId)"      
                $success = Remove-ServiceFabricReplica -NodeName $nodeName -PartitionId $partitionId -ReplicaOrInstanceId $instanceId -CommandCompletionMode Verify
                if ($success) {
                    Write-Host "      -> Successfully removed the replica of $serviceName on $nodeName" -ForegroundColor Green
                }

                # Restart the service replica's process on the Node:
                Write-Host "    Restarting $serviceName process (serviceManifestName: $serviceManifestName, codePackageName: $codePackageName)"
                $success = Restart-ServiceFabricDeployedCodePackage -NodeName $nodeName -ApplicationName $applicationName -CodePackageName $codePackageName -ServiceManifestName $serviceManifestName -CommandCompletionMode Verify
                if ($success) {
                    Write-Host "      -> Successfully restarted the process of $serviceName" -ForegroundColor Green
                }
            }
        }

        $restartAppJobs.Add($restartAppJob.Id)
    } # Apps | ...

    Write-Host "  Node $nodeName -> waiting for parallel app restart to finish ..."
    Wait-Job -Id $restartAppJobs
}
    