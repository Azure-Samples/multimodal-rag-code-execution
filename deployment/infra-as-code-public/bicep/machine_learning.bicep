@description('A prefix that will be prepended to resource names')
param namePrefix string = 'dev'

@description('The name of the Azure Container Registry')
param machineLearningName string = 'di'

@description('The Application Insights resource ID')
param appInsightsId string

@description('The Azure Container Registry resource ID')
param acrId string

@description('A unique identifier that will be appended to resource names')
param uniqueid string

@description('The location in which all resources should be deployed.')
param location string

// existing resource name params 
var varMachineLearning = '${namePrefix}${machineLearningName}${uniqueid}'

// Storage
module storage 'modules/storage.bicep' = {
  name: 'storage-deployment'
  params:{
    location: location
    uniqueid: uniqueid
    storageAccountName: 'stml'        
  }
}

// Key Vault
module keyvault 'modules/key-vault.bicep' = {
  name: 'keyvault-deployment'
  params:{
    keyVaultName: 'ml-kv'        
    location: location
    uniqueid: uniqueid
  }
}

// ML Workspace
module workspace 'modules/ml-workspace.bicep' = {
  name: 'ml-workspace-deployment'
  params:{
    workspaceName: varMachineLearning
    storageId: storage.outputs.storageAccountId
    appInsightsId: appInsightsId
    containerRegistryId: acrId
    keyVaultId: keyvault.outputs.keyVaultId        
    location: location    
  }
}

output workspaceName string = workspace.outputs.name
output workspaceId string = workspace.outputs.id
