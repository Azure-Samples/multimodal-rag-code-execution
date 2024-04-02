
@description('A prefix that will be prepended to resource names')
param namePrefix string = 'dev'

@description('The name of the container registry to be deployed')
param storageAccountName string = ''

@description('A unique identifier that will be appended to resource names')
param uniqueid string

@description('The location in which all resources should be deployed.')
param location string

var varStorageAccountName = '${namePrefix}${storageAccountName}${uniqueid}'


@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
])
@description('The SKU to use for the Storage Account')
param storageSkuName string = 'Standard_LRS'


resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  kind: 'StorageV2'
  location: location
  name: varStorageAccountName
  sku: {
    name: storageSkuName
  }
  properties: {
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    allowBlobPublicAccess: true
  }
}

output storageAccountId string = storageAccount.id
