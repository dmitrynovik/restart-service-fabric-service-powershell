Param (
    [Parameter(Mandatory=$true)] [uri[]] $ApplicationNames
)

try {
    Test-ServiceFabricClusterConnection | Out-Null
}
catch {
    throw "Active connection to Service Fabric cluster required"
}

$nodes = Get-ServiceFabricNode -StatusFilter Up
$nodes | ForEach-Object {
    $nodeName = $_.NodeName
    Write-Host "Processing node: $nodeName" -ForegroundColor Yellow

    foreach ($applicationName in $ApplicationNames) {

        $replicas = Get-ServiceFabricDeployedReplica -NodeName $nodeName -ApplicationName $applicationName
        Write-Host "  Restarting the service fabric application: $applicationName" -ForegroundColor Magenta

        $replicas | ForEach-Object {
            $partitionId = $_.partitionId
            $instanceId = $_.instanceId
            $serviceManifestName = $_.ServiceManifestName
            $codePackageName = $_.CodePackageName

            # Remove the replica from the Node:
            Write-Host "    Removing $applicationName replica on $nodeName (partitionId: $partitionId, instanceId: $instanceId)"      
            $success = Remove-ServiceFabricReplica -NodeName $nodeName -PartitionId $partitionId -ReplicaOrInstanceId $instanceId -CommandCompletionMode Invalid
            if ($success) {
                Write-Host "      Successfully removed the replica of $applicationName on $nodeName" -ForegroundColor Green
            }

            # Restart the process on the Node:
            Write-Host "    Restarting $applicationName process on $nodeName (serviceManifestName: $serviceManifestName, codePackageName: $codePackageName)"
            $success = Restart-ServiceFabricDeployedCodePackage -NodeName $nodeName -ApplicationName $applicationName -CodePackageName $codePackageName -ServiceManifestName $serviceManifestName -CommandCompletionMode Invalid
            if ($success) {
                Write-Host "      Successfully restarted the process of $applicationName on $nodeName" -ForegroundColor Green
            }
        }
    }
}
    