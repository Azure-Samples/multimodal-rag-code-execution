@description('An existing Azure OpenAI resource')
param openAIName string

@description('An existing Azure OpenAI resource group')
param openAIRGName string

@description('An existing Azure Container Registry resource to pull images from')
param containerRegistryName string

@description('Service Principal Id')
param spId string

@description('Service Principal Secret')
@secure()
param spSecret string

@description('The location in which all resources should be deployed.')
param location string = resourceGroup().location

@description('The region for the Azure AI Search service')
param aiSearchRegion string = resourceGroup().location

@description('A prefix that will be prepended to resource names')
param namePrefix string = 'dev'

var uniqueid = uniqueString(resourceGroup().id)
var di_location = 'westeurope'

// ---- Log Analytics workspace ----
var logWorkspaceName = 'log-${uniqueid}'
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logWorkspaceName
  location: location  
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Deploy storage account with private endpoint and private DNS zone
module storageModule 'storage.bicep' = {
  name: 'storageDeploy'
  params: {
    location: location
    uniqueid: uniqueid        
  }
}

// Deploy a web app
module webappModule 'webapp.bicep' = {
  name: 'webappDeploy'
  params: {
    location: location
    uniqueid: uniqueid            
    storageName: storageModule.outputs.storageName            
    logWorkspaceName: logWorkspace.name
    containerRegistry: containerRegistryName
    storageAccount:storageModule.outputs.storageName  
    namePrefix:namePrefix
    mlWorkspaceName: machineLearning.outputs.workspaceName
   }
}


module azureVisionResource 'vision.bicep' =  {
  name: 'azureVisionResource'
  params: {
    uniqueid: uniqueid
    location: location       
    namePrefix:namePrefix         
  }
}

module cosmosDbModule 'cosmosdb.bicep' =  {
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

// Deployment script from modules
module script 'modules/script.bicep' = {
  name: 'script'
  params: {
    spId: spId
    spSecret: spSecret
    uniqueid: uniqueid
    machineLearningName: 'mlws' 
    storageName: storageModule.outputs.storageName
    chatAppName: webappModule.outputs.appName
    mainAppName: webappModule.outputs.appName2
    apiAppName: webappModule.outputs.appNameApi
  }
  dependsOn: [
    machineLearning, webappModule
  ]
}

resource openAI 'Microsoft.CognitiveServices/accounts@2022-03-01' existing = {
  name: openAIName
  scope: resourceGroup(openAIRGName)
}
module apiAppSettings 'modules/appsettings.bicep' = {
  name: 'appsettings'
  dependsOn: [script, webappModule, storageModule, cosmosDbModule, machineLearning, documentInteligence, azureVisionResource, ai_search]
  params: {
    targetWebAppName: webappModule.outputs.appNameApi
    allSettings: {
      APPLICATIONINSIGHTS_CONNECTION_STRING: webappModule.outputs.appInsightsConnectionString
      ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
      TEXT_CHUNK_SIZE: '512'
      TEXT_CHUNK_OVERLAP: '128'
      TENACITY_TIMEOUT: '200'
      TENACITY_STOP_AFTER_DELAY: '300'
      AML_CLUSTER_NAME: 'mm-doc-cpu-cluster'
      AML_VMSIZE: 'STANDARD_D2_V2'
      PYTHONUNBUFFERED: '1'
      AML_PASSWORD: script.outputs.password
      AML_TENANT_ID: script.outputs.tenantId
      AML_SERVICE_PRINCIPAL_ID: script.outputs.appId
      INITIAL_INDEX: 'rag-data'
      AML_SUBSCRIPTION_ID: subscription().subscriptionId
      AML_RESOURCE_GROUP: resourceGroup().name
      AML_WORKSPACE_NAME: machineLearning.outputs.workspaceName
      AZURE_FILE_SHARE_ACCOUNT: storageModule.outputs.storageName
      AZURE_FILE_SHARE_NAME: storageModule.outputs.storageName
      AZURE_FILE_SHARE_KEY: storageModule.outputs.storageKey
      PYTHONPATH: './code/:../code:../TaskWeaver:./code/utils:../code/utils:../../code:../../code/utils'
      COSMOS_URI: cosmosDbModule.outputs.cosmosDbUri
      COSMOS_KEY: cosmosDbModule.outputs.cosmosDbKey
      COSMOS_DB_NAME: cosmosDbModule.outputs.cosmosdbName
      COSMOS_CONTAINER_NAME: 'prompts'
      COSMOS_CATEGORYID: 'prompts'
      COSMOS_LOG_CONTAINER: 'logs'
      ROOT_PATH_INGESTION: '/data/data'
      PROMPTS_PATH: 'prompts'
      DI_ENDPOINT: documentInteligence.outputs.documentIntelligenceEndpoint
      DI_KEY: documentInteligence.outputs.documentIntelligenceKey
      DI_API_VERSION: '2024-02-29-preview'
      AZURE_OPENAI_RESOURCE: ''
      AZURE_OPENAI_KEY: ''
      AZURE_OPENAI_MODEL: 'gpt-4'
      AZURE_OPENAI_RESOURCE_1: ''
      AZURE_OPENAI_KEY_1: openAI.listKeys().key1
      AZURE_OPENAI_RESOURCE_2: ''
      AZURE_OPENAI_KEY_2: ''
      AZURE_OPENAI_RESOURCE_3: ''
      AZURE_OPENAI_KEY_3: ''
      AZURE_OPENAI_RESOURCE_4: ''
      AZURE_OPENAI_KEY_4: ''
      AZURE_OPENAI_EMBEDDING_MODEL: 'text-embedding-ada-002'
      AZURE_OPENAI_MODEL_VISION: 'gpt4v'
      AZURE_OPENAI_API_VERSION: '2024-02-15-preview'
      AZURE_OPENAI_TEMPERATURE: '0'
      AZURE_OPENAI_TOP_P: '1.0'
      AZURE_OPENAI_MAX_TOKENS: '1000'
      AZURE_OPENAI_STOP_SEQUENCE: ''
      AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE: ''
      AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE_KEY: ''
      AZURE_OPENAI_EMBEDDING_MODEL_API_VERSION: '2023-12-01-preview'
      COG_SERV_ENDPOINT: ai_search.outputs.aiSearchEndpoint
      COG_SERV_KEY: ai_search.outputs.aiSearchAdminKey
      COG_SERV_LOCATION: aiSearchRegion
      AZURE_VISION_ENDPOINT: azureVisionResource.outputs.accountsVisionEndpoint
      AZURE_VISION_KEY: azureVisionResource.outputs.accountsVisionKey
      AZURE_OPENAI_ASSISTANTSAPI_ENDPOINT: ''
      AZURE_OPENAI_ASSISTANTSAPI_KEY: ''
      OPENAI_API_KEY: ''
      COG_SEARCH_ENDPOINT: ai_search.outputs.aiSearchEndpoint
      COG_SEARCH_ADMIN_KEY: ai_search.outputs.aiSearchAdminKey
      COG_VEC_SEARCH_API_VERSION: '2023-11-01'
      COG_SEARCH_ENDPOINT_PROD: ai_search.outputs.aiSearchEndpoint
      COG_SEARCH_ADMIN_KEY_PROD: ai_search.outputs.aiSearchAdminKey
    }
  }
}
