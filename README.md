## Purpose
A powershell script to **gracefully** restart multiple Service Fabric apps, node-by-node.

## Usage 
### Restart Apps
.\restart-service-fabric-apps.ps1 -Apps _app1,app2,..._ [-ConnectionEndpoint _address_]

### Restart Nodes
.\restart-service-fabric-nodes.ps1 [-ConnectionEndpoint _address_]
