/*
  Deploy storage account with private endpoint and private DNS zone
*/
@description('This is the base name for each Azure resource name (6-12 chars)')
param uniqueid string

@description('The resource group location')
param location string = resourceGroup().location

// existing resource name params 
@description('The name of the Virtual Network (VNet) where resources will be deployed')
param vnetName string

@description('The name of the subnet for private endpoints')
param privateEndpointsSubnetName string

// variables
// var storageName = 'st${uniqueid}'
var storageName = 'st${uniqueid}'
// var storageSkuName = 'Premium_LRS'
var storageDnsGroupName = '${storagePrivateEndpointName}/default'
var storagePrivateEndpointName = 'pep-${storageName}'
var blobStorageDnsZoneName = 'privatelink.blob.${environment().suffixes.storage}'

// ---- Existing resources ----
// resource vnet 'Microsoft.Network/avirtualNetworks@2023-04-01' existing =  {
  resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing =  {
  name: vnetName

  resource privateEndpointsSubnet 'subnets' existing = {
    name: privateEndpointsSubnetName
  }  
}

// ---- Storage resources ----
resource storageAccountResource 'Microsoft.Storage/storageAccounts@2023-01-01' = { 
  name: storageName
  location: location
  kind: 'FileStorage'
  properties: {
    allowBlobPublicAccess: true
    allowCrossTenantReplication: false
    allowSharedKeyAccess: true
    defaultToOAuthAuthentication: false
    dnsEndpointType: 'Standard'
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: false
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
    largeFileSharesState: 'Enabled'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'Enabled'
    supportsHttpsTrafficOnly: true
  }
  sku: {
    name: 'Premium_LRS'
  }
}
resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: storagePrivateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet::privateEndpointsSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: storagePrivateEndpointName
        properties: {
          groupIds: [
            'file'
          ]
          privateLinkServiceId: storageAccountResource.id
        }
      }
    ]
  }
}

resource storageDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: blobStorageDnsZoneName
  location: 'global'
  properties: {}
}

resource storageDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: storageDnsZone
  name: '${blobStorageDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource storageDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-11-01' = {
  name: storageDnsGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: blobStorageDnsZoneName
        properties: {
          privateDnsZoneId: storageDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    storagePrivateEndpoint
  ]
}


resource storageAccountFileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: storageAccountResource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
    protocolSettings: {
      smb: {
        multichannel: {
          enabled: false
        }
      }
    }
    shareDeleteRetentionPolicy: {
      days: 14
      enabled: true
    }
  }
  // sku: {
  //   name: 'Premium_LRS'
  //   tier: 'Premium'
  // }
}

resource storageAccountFileServiceShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${storageName}/default/${storageName}'
  dependsOn: [
    storageAccountResource
    storageAccountFileService
  ]
  properties: {
    accessTier: 'Premium'
    enabledProtocols: 'SMB'
    shareQuota: 1024
  }
}

@description('The name of the storage account.')
output storageName string = storageAccountResource.name
