@description('A prefix that will be prepended to resource names')
param namePrefix string = 'dev'

@description('The name of the Azure Container Registry')
param containerRegistry string = 'acr'

@description('A unique identifier that will be appended to resource names')
param uniqueid string

@description('The location in which all resources should be deployed.')
param location string

// existing resource name params 

@description('The name of the Virtual Network (VNet) where resources will be deployed')
param vnetName string

@description('The name of the subnet for private endpoints')
param privateEndpointsSubnetName string

var varcontainerRegistry = '${namePrefix}${containerRegistry}${uniqueid}'
var acrPrivateEndpointName = 'pep-${varcontainerRegistry}'

var acrDnsGroupName = '${acrPrivateEndpointName}/default'
var acrDnsZoneName = 'privatelink${environment().suffixes.acrLoginServer}'

resource vnet 'Microsoft.Network/virtualNetworks@2022-11-01' existing =  {
  name: vnetName

  resource privateEndpointsSubnet 'subnets' existing = {
    name: privateEndpointsSubnetName
  }  
}

resource containerRegistry_resource 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  location: location
  name: varcontainerRegistry
  properties: {
    adminUserEnabled: true
    anonymousPullEnabled: false
    dataEndpointEnabled: false
    encryption: {
      status: 'disabled'
    }
    metadataSearch: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
    policies: {
      azureADAuthenticationAsArmPolicy: {
        status: 'enabled'
      }
      exportPolicy: {
        status: 'enabled'
      }
      quarantinePolicy: {
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'disabled'
      }
      softDeletePolicy: {
        retentionDays: 7
        status: 'disabled'
      }
      trustPolicy: {
        status: 'disabled'
        type: 'Notary'
      }
    }
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
  }
  sku: {
    name: 'Premium'
    // tier: 'Standard'
  }
}

resource acrPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-11-01' = {
  name: acrPrivateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet::privateEndpointsSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: acrPrivateEndpointName
        properties: {
          privateLinkServiceId: containerRegistry_resource.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
}

resource acrServerDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: acrServerDnsZone
  name: '${acrDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource acrServerDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: acrDnsZoneName
  location: 'global'
  properties: {}
}

resource acrServerDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-11-01' = {
  name: acrDnsGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: acrDnsZoneName
        properties: {
          privateDnsZoneId: acrServerDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    acrPrivateEndpoint
  ]
}

output containerRegistryName string = containerRegistry_resource.name
