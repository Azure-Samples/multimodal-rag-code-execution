var DeployThis = true //just used for development reasons locally here so that I can test individual modules without deploying everything
// we get the current pincilal id so that we can assign the keyvault administrator role to the current user

@description('The region for the Azure AI Search service')
param aiSearchRegion string ='eastus'

@description('The location in which all resources should be deployed.')
param location string = resourceGroup().location

var di_location = 'westeurope'

@description('A prefix that will be prepended to resource names')
param namePrefix string = 'dev'

@description('The address prefix for the Application Gateway subnet')

var uniqueid = uniqueString(resourceGroup().id)

var logWorkspaceName = 'log-${uniqueid}'


// ---- Log Analytics workspace ----
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = if (DeployThis) {
  name: logWorkspaceName
  location: location  
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Deploy vnet with subnets and NSGs
// Deploy storage account with private endpoint and private DNS zone
module storageModule 'storage.bicep' = if (DeployThis) {
  name: 'storageDeploy'
  params: {
    location: location
    uniqueid: uniqueid        
  }
}

// Deploy a web app
module webappModule 'webapp.bicep' = if (DeployThis) {
  name: 'webappDeploy'
  params: {
    location: location
    uniqueid: uniqueid            
    storageName: storageModule.outputs.storageName            
    logWorkspaceName: logWorkspace.name
    containerRegistry: registry.outputs.containerRegistryName
    storageAccount:storageModule.outputs.storageName  
    namePrefix:namePrefix
    mlWorkspaceName: machineLearning.outputs.workspaceName
   }
}


module registry 'registry.bicep' = if (DeployThis) {
  name: 'containerRegistryModule'
  params: {
    namePrefix:namePrefix
    containerRegistry: 'acr'
    uniqueid:  uniqueid
    location: location
  }
}


module accountsVisionResTstName 'vision.bicep' =  {
  name: 'accountsVisionResTstName'
  params: {
    uniqueid: uniqueid
    location: location       
    namePrefix:namePrefix         
  }
}

module cosmosDbModule 'cosmosdb.bicep' = if (DeployThis) {
  name: 'cosmosdbDeploy'
  params: {
    location: location
    uniqueid: uniqueid
    namePrefix:namePrefix
  }
}

module ai_search 'ai_search.bicep' = {
  name: 'ai_search'
  params: {
    uniqueid: uniqueid
    aiSearchRegion: aiSearchRegion
    // location: location
    namePrefix:namePrefix                
  }
}

module documentInteligence 'documentintelligence.bicep' =  {
  name: 'document-Intelligence'
  params: {
    namePrefix:namePrefix
    documentIntelligence: 'doc-int'
    uniqueid:  uniqueid
    location: di_location
  }
}

module machineLearning 'machine_learning.bicep' =  {
  name: 'machine-learing-worksapce'
  params: {
    namePrefix:namePrefix
    machineLearningName: 'mlws' 
    uniqueid:  uniqueid
    location: location
    logWorkspaceName: logWorkspace.name
  }
}


output webAppNameStreamlit string = webappModule.outputs.appName2
output webAppNameChainlit string = webappModule.outputs.appName
output webAppNameApi string = webappModule.outputs.appNameApi
output appServiceName string = webappModule.outputs.appServicePlanName
output containerRegistry string = registry.outputs.containerRegistryName
output uniqueId string = uniqueid
output storageAccount string = storageModule.outputs.storageName
output aiSearch string =  ai_search.outputs.aiSearchName 
output accountsVisionResTstName string = accountsVisionResTstName.outputs.accountsVisionResTstName
output cosmosDbName string = cosmosDbModule.outputs.cosmosdbName
output documentIntelligenceName string = documentInteligence.outputs.documentIntelligenceName
output documentIntelligenceId string = documentInteligence.outputs.documentIntelligenceId
output machineLearningName string = machineLearning.outputs.workspaceName
output machineLearningId string = machineLearning.outputs.workspaceId
