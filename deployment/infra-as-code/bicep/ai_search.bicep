@description('The name of the Azure AI Search service')
var aiSearchName  = 'aisearch'

@description('A prefix that will be prepended to resource names')
param namePrefix string = 'dev'

@description('The region for the Azure AI Search service')
param aiSearchRegion string = 'eastus'

@description('A unique identifier that will be appended to resource names')
param uniqueid string

@description('The location in which all resources should be deployed.')
param location string

// existing resource name params 

@description('The name of the Virtual Network (VNet) where resources will be deployed')
param vnetName string

@description('The name of the subnet for private endpoints')
param privateEndpointsSubnetName string

var varaiSearchName = '${namePrefix}${aiSearchName}${uniqueid}'
var searchPrivateEndpointName = 'pep-${varaiSearchName}'

var searchDnsGroupName = '${searchPrivateEndpointName}/default'
var searchDnsZoneName = 'privatelink.search.windows.net'

resource vnet 'Microsoft.Network/virtualNetworks@2022-11-01' existing =  {
  name: vnetName

  resource privateEndpointsSubnet 'subnets' existing = {
    name: privateEndpointsSubnetName
  }  
}

resource searchService 'Microsoft.Search/searchServices@2023-11-01' =  {
  name: varaiSearchName
  location: aiSearchRegion
  sku: {
    name: 'standard'
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: 'disabled'
    networkRuleSet: {
      ipRules: []
    }
    encryptionWithCmk: {
      enforcement: 'Unspecified'
    }
    disableLocalAuth: false
    authOptions: {
      apiKeyOnly: {}
    }
    semanticSearch: 'standard'
  }
}

resource searchPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-11-01' = {
  name: searchPrivateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet::privateEndpointsSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: searchPrivateEndpointName
        properties: {
          privateLinkServiceId: searchService.id
          groupIds: [
            'searchService'
          ]
        }
      }
    ]
  }
}

resource searchServerDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: searchServerDnsZone
  name: '${searchDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource searchServerDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: searchDnsZoneName
  location: 'global'
  properties: {}
}

resource searchServerDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-11-01' = {
  name: searchDnsGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: searchDnsZoneName
        properties: {
          privateDnsZoneId: searchServerDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    searchPrivateEndpoint
  ]
}

output aiSearchName string = searchService.name
