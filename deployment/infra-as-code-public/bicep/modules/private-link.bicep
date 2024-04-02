@description('The URI for the private link')
param privateLinkUri array

@description('The group name for the private endpoint')
param groupName string

@description('The Virtual Network object')
param vnet object

@description('The base Azure resource to enable Private Link on')
param baseResource object

@description('The tags to apply to the Azure Resources')
param tags object

resource dnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for uri in privateLinkUri: {
  name: uri
  location: 'global'
  tags: tags
}]

resource zoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (uri, i) in privateLinkUri: {
  name: '${dnsZones[i].name}/${vnet.name}_link'
  location: 'global'
  tags: tags
  properties:{
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}]

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-06-01' = {
  name: '${baseResource.name}-pe'
  location: resourceGroup().location
  tags: tags
  properties:{
    privateLinkServiceConnections: [
      {
        name: '${baseResource.name}-psc'
        properties:{
          privateLinkServiceId: baseResource.id
          groupIds: [
            groupName
          ]
        }
      }
    ]
    subnet: {
      id: vnet.subnet.id
    }
  }
}

resource privateEndpointDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: '${privateEndpoint.name}/${groupName}-PrivateDnsZoneGroup'
  dependsOn: [
    privateEndpoint
    dnsZones
  ]
  properties:{
    privateDnsZoneConfigs: [for (uri, i) in privateLinkUri: {
        name: uri
        properties:{
          privateDnsZoneId: dnsZones[i].id
        }
      }]
  }
}
