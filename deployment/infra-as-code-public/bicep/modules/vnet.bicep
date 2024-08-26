// Copyright (c) 2021 Microsoft
// 
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

@description('Specifies the location for all new resources.')
param location string = resourceGroup().location

@description('Tags for workspace, will also be populated if provisioning new dependent resources.')
param tags object = {}

@description('Name of the VNet')
param vnetName string = 'vnet'

@description('Address prefix of the virtual network')
param addressPrefixes array = [
  '10.0.0.0/16'
]

@description('Name of the subnet')
param subnetName string = 'aml-subnet'

@description('Subnet prefix of the virtual network - must be contained in addressPrefixes')
param subnetPrefix string = '10.0.0.0/24'

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2019-09-01' = {
  name: vnetName
  tags: tags
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    enableDdosProtection: false
    enableVmProtection: false
  }
}

// Subnet
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2019-09-01' = {
  name: '${vnet.name}/${subnetName}'
  properties: {
    addressPrefix: subnetPrefix
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
      }
      {
        service: 'Microsoft.KeyVault'
      }
      {
        service: 'Microsoft.ContainerRegistry'
      }
    ]
  }
}

output name string = vnet.name
output id string = vnet.id
output subnet object = {
    name: subnet.name
    id: subnet.id
}

output details object = {
  name: vnet.name
  id: vnet.id
  subnet: {
    name: subnet.name
    id: subnet.id
  }
}
