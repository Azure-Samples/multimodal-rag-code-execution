@description('A prefix that will be prepended to resource names')
param namePrefix string = 'dev'

@description('The name of the Vision resource')
param accountsVisionResTstName string = 'vision'

@description('A unique identifier that will be appended to resource names')
param uniqueid string

@description('The location in which all resources should be deployed.')
param location string

// existing resource name params 

@description('The name of the Virtual Network (VNet) where resources will be deployed')
param vnetName string

@description('The name of the subnet for private endpoints')
param privateEndpointsSubnetName string


var varaccountsVisionResTstName = '${namePrefix}${accountsVisionResTstName}${uniqueid}'
var visionPrivateEndpointName = 'pep-${varaccountsVisionResTstName}'

var acrDnsGroupName = '${visionPrivateEndpointName}/default'
var visionDnsZoneName = 'privatelink.cognitiveservices.azure.com' //'privatelink${environment().suffixes.acrLoginServer}'

resource vnet 'Microsoft.Network/virtualNetworks@2022-11-01' existing =  {
  name: vnetName

  resource privateEndpointsSubnet 'subnets' existing = {
    name: privateEndpointsSubnetName
  }  
}

resource cognitiveServicesAccount 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: varaccountsVisionResTstName
  location: location
  sku: {
    name: 'S1'
  }
  kind: 'ComputerVision'
  identity: {
    type: 'None'
  }
  properties: {
    customSubDomainName: varaccountsVisionResTstName
    restore: false
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    publicNetworkAccess: 'Disabled'
  }
}

resource visionPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-11-01' = {
  name: visionPrivateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet::privateEndpointsSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: visionPrivateEndpointName
        properties: {
          privateLinkServiceId: cognitiveServicesAccount.id
          groupIds: [
            'account'
          ]
        }
      }
    ]
  }
}

resource acrServerDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: acrServerDnsZone
  name: '${visionDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource acrServerDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: visionDnsZoneName
  location: 'global'
  properties: {}
}

resource acrServerDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-11-01' = {
  name: acrDnsGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: visionDnsZoneName
        properties: {
          privateDnsZoneId: acrServerDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    visionPrivateEndpoint
  ]
}

// output containerRegistryName string = containerRegistry_resource.name
output accountsVisionResTstName string = cognitiveServicesAccount.name
