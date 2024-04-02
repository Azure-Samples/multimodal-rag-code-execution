@description('The group objects name for the private endpoint')
param groups array = [
  {
    name: 'blob'
    uri: 'privatelink.blob.${environment().suffixes.storage}'
  }
]

@description('The Virtual Network object')
param vnet object

@description('The base Azure resource to enable Private Link on')
param baseResource object

@description('The tags to apply to the Azure Resources')
param tags object

resource dnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for group in groups: {
  name: group.uri
  location: 'global'
  tags: tags
}]

resource zoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (group, i) in groups: {
  name: '${dnsZones[i].name}/${vnet.name}_link'
  location: 'global'
  tags: tags
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}]

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-06-01' = [for group in groups: {
  name: '${baseResource.name}-${group.name}-pe'
  location: resourceGroup().location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: '${baseResource.name}-${group.name}-psc'
        properties: {
          privateLinkServiceId: baseResource.id
          groupIds: [
            group.name
          ]
        }
      }
    ]
    subnet: {
      id: vnet.subnet.id
    }
  }
}]

resource privateEndpointDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = [for (group, i) in groups: {
  name: '${privateEndpoint[i].name}/${group.name}-PrivateDnsZoneGroup'
  dependsOn: [
    privateEndpoint
    dnsZones
  ]
  properties:{
    privateDnsZoneConfigs: [
      {
        name: group.uri
        properties:{
          privateDnsZoneId: dnsZones[i].id
        }
      }
    ]
  }
}]
