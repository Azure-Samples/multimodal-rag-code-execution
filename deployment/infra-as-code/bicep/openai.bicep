// Name of the current environment
param envName string
// Custom domain name for the OpenAI service
// param openAiCustomDomain string
// SKU name for the OpenAI service
param openAiSkuName string = 'S0'


param aoaiGpt4ModelName string= 'gpt-4'
param aoaiGpt4ModelVersion string = '1106-Preview'
param aoaiGpt4ModelDeploymentName string = 'gpt-4'
param aoaiGpt4ModelscaleType string = 'Standard'

param aoaiEmbedingsName string = 'text-embedding-ada-002'
param aoaiEmbedingsVersion string  = '2'
param aoaiEmbedingsDeploymentName string = 'text-embedding-ada-002'

param aoaiGpt4VisionName string = 'gpt-4v'
param aoaiGpt4VisionVersion string = 'vision-preview'
param aoaiGpt4VisionDeploymentName string = 'gpt-4'


// Array of deployments, currently just one deployment will be used
param deployments array = [
  {
    name: aoaiGpt4ModelName
    model: {
      format: 'OpenAI'
      name: aoaiGpt4ModelDeploymentName
      version: aoaiGpt4ModelVersion
      capacity: 10
      contentFilter: 'Default'
    }
    sku: {
      name: 'Standard'
      capacity: 30
  }

  }
  {
    name: aoaiEmbedingsName
    model: {
      format: 'OpenAI'
      name: aoaiEmbedingsDeploymentName
      version: aoaiEmbedingsVersion
      capacity: 10
      contentFilter: 'Default'
    }
    sku: {
      name: 'Standard'
      capacity: 120
  }
  }
  {
    name: aoaiGpt4VisionName
    model: {
      format: 'OpenAI'
      name: aoaiGpt4VisionDeploymentName
      version: aoaiGpt4VisionVersion
      capacity: 10
      contentFilter: 'Default'
    }
    sku: {
      name: 'Standard'
      capacity: 30
  }
  }
]
// Tags for the resource group
param tags object = {
  Creator: 'ServiceAccount'
  Service: 'OpenAI'
  Environment: envName
}

@description('A prefix that will be prepended to resource names')
param namePrefix string = 'dev'

@description('The name of the Aopenaut AI (AOAI) resource.')
param aoaiResourceName string = 'aoai'

@description('A unique identifier that will be appended to resource names')
param uniqueid string

@description('The location in which all resources should be deployed.')
param location string

@description('The name of the Virtual Network (VNet) where resources will be deployed')
param vnetName string
var varVnetName =toLower(vnetName)

@description('The name of the subnet for private endpoints')
param privateEndpointsSubnetName string = 'snet-privateEndpoints'
var varPrivateEndpointsSubnetName= 'snet-privateEndpoints'
// param privateEndpointsSubnetId string
 
// var varAoaiResourceName = '${namePrefix}${aoaiResourceName}${uniqueid}'
var aoaiPrivateEndpointName = 'pep-${aoaiResourceName}'

var varAoaiCustomDomain = aoaiResourceName

var aoaiDnsGroupName = '${aoaiPrivateEndpointName}/default'
var aoaiDnsZoneName = 'privatelink.openai'

// ---- Existing resources ----

// ---- Existing resources ----
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing =  {
  name: varVnetName

  resource privateEndpointsSubnet 'subnets' existing = {
    name: varPrivateEndpointsSubnetName
  }    
}

// Scope of the deployment, currently just the subscription is supported

// Create the OpenAI service by using a separate file
module openAi './modules/openai.resources.bicep' = {
  name: 'openai-${location}'
  params: {
    name: aoaiResourceName
    customDomainName: varAoaiCustomDomain
    location: location
    tags: tags
    sku: {
      name: openAiSkuName
    }
    deployments: deployments
  }
}



// Create the private endpoint for the OpenAI service

// resource pepopenai 'Microsoft.Network/privateEndpoints@2023-09-01' = {
//   name: 'pepopenai'
//   location: location
//   tags: {}
//   properties: {
   
//     privateLinkServiceConnections: [
//       {
//         name: aoaiPrivateEndpointName
//         properties: {
//           privateLinkServiceId: openAi.outputs.aoaiResourceId
//           groupIds: [
//             'account'
//           ]
//         }
//       }
//     ]
    
//     customNetworkInterfaceName: 'pepopenai-nic'
//     subnet: {
//       id: '/subscriptions/af509a4e-4374-4998-8d0d-15fc7b54f668/resourceGroups/test-research-copilot-rg/providers/Microsoft.Network/virtualNetworks/dev-vnet-xe4t44kuwpez6/subnets/snet-privateEndpoints'
//     }
//   }
// }


resource aoaiPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: aoaiPrivateEndpointName
  location: location
  properties: {
    subnet: {
      // id: vnet::privateEndpointsSubnet.id
      id:vnet::privateEndpointsSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: aoaiPrivateEndpointName
        properties: {
          privateLinkServiceId: openAi.outputs.aoaiResourceId
          groupIds: [
            'account'
          ]
        }
      }
    ]
  }
}

resource aoaiServerDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: aoaiServerDnsZone
  name: '${aoaiDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource aoaiServerDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: aoaiDnsZoneName
  location: 'global'
  properties: {}
}

resource acrServerDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-11-01' = {
  name: aoaiDnsGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: aoaiDnsZoneName
        properties: {
          privateDnsZoneId: aoaiServerDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    aoaiPrivateEndpoint
  ]
}

output aoaiResourceId string = openAi.outputs.aoaiResourceId
output aoaiResourceName string = openAi.outputs.aoaiResourceName

