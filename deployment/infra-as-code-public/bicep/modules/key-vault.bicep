@description('A prefix that will be prepended to resource names')
param namePrefix string = 'dev'

@description('The name of the container registry to be deployed')
param keyVaultName string = 'ml-kv'

@description('A unique identifier that will be appended to resource names')
param uniqueid string

@description('The location in which all resources should be deployed.')
param location string

var varkeyVaultName = '${namePrefix}${keyVaultName}${uniqueid}'


resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: varkeyVaultName
  location: location
  properties:{
    tenantId: subscription().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    accessPolicies: [

    ]
    networkAcls: {
      defaultAction: 'Allow'      
      bypass: 'AzureServices'
    }
  }
}


output keyVaultId string = keyVault.id
