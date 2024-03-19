/*string'10.0.2.32/27'locationnic
  Deploy vnet with subnets and NSGs
*/

param deployJumpBox bool = true

@description('The address prefix for the Azure Bastion subnet')
param bastionSubnetPrefix string = '10.0.3.0/26'

@description('This is the base name for each Azure resource name (6-12 chars)')
param uniqueid string

@description('A prefix that will be prepended to resource names')
param namePrefix string = 'dev'

@description('The resource group location')
param location string = resourceGroup().location

@description('The address prefix for the Virtual Network')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('The address prefix for the Application Gateway subnet')
param appGatewaySubnetPrefix string = '10.0.1.0/24'

@description('The address prefix for the App Services subnet')
param appServicesSubnetPrefix string = '10.0.0.0/24'

@description('The address prefix for the Private Endpoints subnet')
param privateEndpointsSubnetPrefix string = '10.0.2.0/27'

@description('The address prefix for the Agents subnet')
param agentsSubnetPrefix string = '10.0.2.32/27'

// variables
// var vnetName = 'vnet-${uniqueid}'
var vnetName = '${namePrefix}-vnet-${uniqueid}'
var ddosPlanName = 'ddos-${uniqueid}'



//Temp disable DDoS protection
param enableDdosProtection bool =false

// ---- Networking resources ----

// DDoS Protection Plan
resource ddosProtectionPlan 'Microsoft.Network/ddosProtectionPlans@2022-11-01' = if (enableDdosProtection) {
  name: ddosPlanName
  location: location
  properties: {}
}

//vnet and subnets
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  properties: {
    enableDdosProtection: enableDdosProtection
    ddosProtectionPlan: enableDdosProtection ? { id: ddosProtectionPlan.id } : null
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        //App services plan subnet
        name: 'snet-appServicePlan'
        properties: {
          addressPrefix: appServicesSubnetPrefix
          networkSecurityGroup: {
            id: appServiceSubnetNsg.id
          }
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        //App Gateway subnet
        name: 'snet-appGateway'
        properties: {
          addressPrefix: appGatewaySubnetPrefix
          networkSecurityGroup: {
            id: appGatewaySubnetNsg.id
          }
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        //Private endpoints subnet
        name: 'snet-privateEndpoints'
        properties: {
          addressPrefix: privateEndpointsSubnetPrefix
          networkSecurityGroup: {
            id: privateEndpointsSubnetNsg.id
          }
        }
      }
      {
        // Build agents subnet
        name: 'snet-agents'
        properties: {
          addressPrefix: agentsSubnetPrefix
          networkSecurityGroup: {
            id: agentsSubnetNsg.id
          }
        }
      }
      {
        // Build agents subnet
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
          networkSecurityGroup: {
            id: bastionSubnetNsg.id
          }
        }
      }
    ]
  }

  
  resource appGatewaySubnet 'subnets' existing = {
    name: 'snet-appGateway'
  }

  resource appServiceSubnet 'subnets' existing = {
    name: 'snet-appServicePlan'
  }

  resource privateEnpointsSubnet 'subnets' existing = {
    name: 'snet-privateEndpoints'
  }

  resource agentsSubnet 'subnets' existing = {
    name: 'snet-agents'
  }  
  resource bastionSubnet 'subnets' existing = {
    name: 'AzureBastionSubnet'
  }
}

// Create NSG for the AzureBastionSubnet
resource bastionSubnetNsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: 'nsg-AzureBastionSubnet'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPS'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowInboundRDP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowInboundSSH'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22' // SSH port
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120 // Ensure unique priority within the NSG
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowOutboundRDP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 121
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowOutboundSSH'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 166
          direction: 'Outbound'
        }
      }
      // Ingress from Azure Bastion Control Plane on Port 443
      {
        name: 'AllowAzureBastionControlPlaneInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      // Ingress for Data Plane Communication
      {
        name: 'AllowDataPlaneInbound8080'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '8080' // Specify only one port
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 140
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowDataPlaneInbound5701'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5701' // Specify only one port
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 150 // Ensure unique priority
          direction: 'Inbound'
        }
      }      
      {
        name: 'AllowDataPlaneEgress8080'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '8080'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 170
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowDataPlaneEgress5701'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5701'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 180
          direction: 'Outbound'
        }
      }
      
      // Egress to Azure Public Endpoints on Port 443
      {
        name: 'AllowAzureCloudEgress'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
      // Egress to Internet on Port 80
      {
        name: 'AllowInternetEgress'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 140
          direction: 'Outbound'
        }
      }      
      {
        name: 'AllowAzureLoadBalancerInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 160
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowVMConnectivityEgress'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['22', '3389'] // Assuming custom ports aren't used. If custom ports are used, they need to be explicitly allowed here.
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 145
          direction: 'Outbound'
        }
      }
      
    ]
  }
}

// // Associate the NSG with the AzureBastionSubnet
// resource subnetNsgBastion 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' = {
//   name: nsgBastion.name
//   properties: {
//     networkSecurityGroup: {
//       id: nsgBastion.id
//     }
//   }
// }

//App Gateway subnet NSG
resource appGatewaySubnetNsg 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'nsg-appGatewaySubnet'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AppGw.In.Allow.ControlPlane'
        properties: {
          description: 'Allow inbound Control Plane (https://docs.microsoft.com/azure/application-gateway/configuration-infrastructure#network-security-groups)'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AppGw.In.Allow443.Internet'
        properties: {
          description: 'Allow ALL inbound web traffic on port 443'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: appGatewaySubnetPrefix
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      // {
      //   name: 'AppGw.In.Allow443.Internet'
      //   properties: {
      //     description: 'Allow ALL inbound traffic on port 443 and 80 from bastion subnet'
      //     protocol: 'Tcp'
      //     sourcePortRange: '*'
      //     destinationPortRange: '443,80'
      //     sourceAddressPrefix: bastionSubnetPrefix
      //     destinationAddressPrefix: appGatewaySubnetPrefix
      //     access: 'Allow'
      //     priority: 110
      //     direction: 'Inbound'
      //   }
      // }
      {
        name: 'AppGw.In.Allow.LoadBalancer'
        properties: {
          description: 'Allow inbound traffic from azure load balancer'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }      
      {
        name: 'DenyAllInBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
        }
      }  
      {
        name: 'AppGw.Out.Allow.PrivateEndpoints'
        properties: {
          description: 'Allow outbound traffic from the App Gateway subnet to the Private Endpoints subnet.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: appGatewaySubnetPrefix
          destinationAddressPrefix: privateEndpointsSubnetPrefix
          access: 'Allow'
          priority: 166
          direction: 'Outbound'
        }
      }
      {
        name: 'AppPlan.Out.Allow.AzureMonitor'
        properties: {
          description: 'Allow outbound traffic from the App Gateway subnet to Azure Monitor'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: appGatewaySubnetPrefix
          destinationAddressPrefix: 'AzureMonitor'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
    ]
  }
}

//App service subnet nsg
resource appServiceSubnetNsg 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'nsg-appServicesSubnet'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AppPlan.Out.Allow.PrivateEndpoints'
        properties: {
          description: 'Allow outbound traffic from the app service subnet to the private endpoints subnet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: appServicesSubnetPrefix
          destinationAddressPrefix: privateEndpointsSubnetPrefix
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AppPlan.Out.Allow.AzureMonitor'
        properties: {
          description: 'Allow outbound traffic from App service to the AzureMonitor ServiceTag.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: appServicesSubnetPrefix
          destinationAddressPrefix: 'AzureMonitor'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
    ]
  }
}

//Private endpoints subnets NSG
resource privateEndpointsSubnetNsg 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'nsg-privateEndpointsSubnet'
  location: location
  properties: {
    securityRules: [
      {
        name: 'PE.Out.Deny.All'
        properties: {
          description: 'Deny outbound traffic from the private endpoints subnet'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: privateEndpointsSubnetPrefix
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 100
          direction: 'Outbound'
        }
      }      
    ]
  }
}

//Build agents subnets NSG
resource agentsSubnetNsg 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'nsg-agentsSubnet'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowInboundRDP'
        properties: {          
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: bastionSubnetPrefix // Azure Bastion subnet
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1009
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowInbound443'
        properties: {          
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: bastionSubnetPrefix // Azure Bastion subnet
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1010
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowInbound80'
        properties: {          
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: bastionSubnetPrefix // Azure Bastion subnet
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1011
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowInboundSSH'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22' // SSH port
          sourceAddressPrefix: bastionSubnetPrefix // Azure Bastion subnet
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1201 // Ensure unique priority within the NSG
          direction: 'Inbound'
        }
      }
    ]
  }
}

@description('The name of the vnet.')
output vnetNName string = vnet.name

@description('The name of the app service plan subnet.')
output appServicesSubnetName string = vnet::appServiceSubnet.name

@description('The name of the app gatewaysubnet.')
output appGatewaySubnetName string = vnet::appGatewaySubnet.name

@description('The name of the private endpoints subnet.')
output privateEndpointsSubnetName string = vnet::privateEnpointsSubnet.name

output privateEndpointsSubnetId string = vnet::privateEnpointsSubnet.id

@description('the name of the agents subnet')
output agentsSubnetName string = vnet::agentsSubnet.name

@description('The name of the Azure Bastion subnet.')
output bastionSubnetName string = deployJumpBox ? vnet::bastionSubnet.name : ''

