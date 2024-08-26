@description('A prefix that will be prepended to resource names')
param namePrefix string = 'dev'

@description('The name of the Azure Container Registry')
param machineLearningName string = 'di'

@description('A unique identifier that will be appended to resource names')
param uniqueid string

@description('The location in which all resources should be deployed.')
param location string

// existing resource name params 
var varMachineLearning = '${namePrefix}${machineLearningName}${uniqueid}'

param logWorkspaceName string = ''

var varMLAppInsightsName = '${namePrefix}-ml-app-ins-${uniqueid}'

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logWorkspaceName
}


// Container Registry
module acr 'modules/container-registry.bicep' ={
  name: 'ml-acr-deployment'
  params: {
    containerRegistryName: 'acrml'
    // vnet: vnet.outputs.details
    location: location
    uniqueid: uniqueid
  }
}



resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: varMLAppInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
  }
}

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
    appInsightsId: appInsights.id
    containerRegistryId: acr.outputs.acrId
    keyVaultId: keyvault.outputs.keyVaultId        
    location: location    
  }
}

output workspaceName string = workspace.outputs.name
output workspaceId string = workspace.outputs.id
