/*
  Deploy storage account with private endpoint and private DNS zone
*/
@description('This is the base name for each Azure resource name (6-12 chars)')
param uniqueid string

@description('The resource group location')
param location string = resourceGroup().location

// variables
// var storageName = 'st${uniqueid}'
var storageName = 'st${uniqueid}'
// var storageSkuName = 'Premium_LRS'



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
