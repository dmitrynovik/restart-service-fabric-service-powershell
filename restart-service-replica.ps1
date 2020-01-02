Param (
    [Parameter(Mandatory=$true)] [uri] $ApplicationName
)

Write-Host "Restarting Service Fabric Application: $ApplicationName"

try {
    Test-ServiceFabricClusterConnection | Out-Null
}
catch {
    throw "Active connection to Service Fabric cluster required"
}

$nodes = Get-ServiceFabricNode -StatusFilter Up
$nodes | ForEach-Object {
    $nodeName = $_.NodeName
    $replicas = Get-ServiceFabricDeployedReplica -NodeName $nodeName -ApplicationName $ApplicationName
    Write-Host "=== Processing Node: $nodeName" -ForegroundColor Yellow

    $replicas | ForEach-Object {
		$partitionId = $_.partitionId
        $instanceId = $_.instanceId
        $serviceManifestName = $_.ServiceManifestName
        $codePackageName = $_.CodePackageName

        # Remove the replica from the Node:
        Write-Host "Removing $ApplicationName replica on $nodeName (partitionId: $partitionId, instanceId: $instanceId)"      
        $success = Remove-ServiceFabricReplica -NodeName $nodeName -PartitionId $partitionId -ReplicaOrInstanceId $instanceId -CommandCompletionMode Invalid
        if ($success) {
            Write-Host "Successfully removed the replica of $ApplicationName on $nodeName" -ForegroundColor Green
        }

        # Restart the process on the Node:
        Write-Host "Restarting $ApplicationName process on $nodeName (serviceManifestName: $serviceManifestName, codePackageName: $codePackageName)"
        $success = Restart-ServiceFabricDeployedCodePackage -NodeName $nodeName -ApplicationName $ApplicationName -CodePackageName $codePackageName -ServiceManifestName $serviceManifestName -CommandCompletionMode Invalid
        if ($success) {
            Write-Host "Successfully restarted the process of $ApplicationName on $nodeName" -ForegroundColor Green
        }
    }
}