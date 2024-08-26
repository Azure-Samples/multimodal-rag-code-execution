@description('An existing Azure OpenAI resource')
param openAIName string = ''

@description('An existing Azure OpenAI resource group')
param openAIRGName string = ''

@description('The location in which all resources should be deployed.')
param location string = resourceGroup().location

@description('The region for the Azure AI Search service')
@allowed(['francecentral', 'eastus', 'japaneast'])
param aiSearchRegion string = 'eastus'

@description('A prefix that will be prepended to resource names')
param namePrefix string = 'dev'

@description('Location for a new Azure OpenAI resource. Leave openAIName and openAIRGName empty to deploy a new resource.')
@allowed(['swedencentral', 'eastus', ''])
param newOpenAILocation string = ''

@description('True to avoid building images from the repo. In this case images must be published via push.ps1 script')
param skipImageBuild bool = false

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
    namePrefix: namePrefix
    uniqueid: uniqueid        
  }
}

module acr 'registry.bicep' = {
  name: 'acrDeploy'
  params: {
    location: location
    uniqueid: uniqueid
    namePrefix: namePrefix
  }
}

module buildImages 'modules/build-images.bicep' = if (!skipImageBuild) {
  name: 'buildImages'
  params: {
    acrName: acr.outputs.containerRegistryName
  }
  dependsOn: [
    acr
  ]
}

var acrNameToUse = acr.outputs.containerRegistryName
var acrPasswordToUse = acr.outputs.containerRegistryPassword

// Deploy a web app
module webappModule 'webapp.bicep' = {
  name: 'webappDeploy'
  params: {
    location: location
    uniqueid: uniqueid            
    storageName: storageModule.outputs.storageName            
    logWorkspaceName: logWorkspace.name
    containerRegistryName: acrNameToUse
    containerRegistryPassword: acrPasswordToUse
    storageAccount:storageModule.outputs.storageName  
    namePrefix:namePrefix
    mlWorkspaceName: machineLearning.outputs.workspaceName
   }
   dependsOn: [acr]
}

module openAIResource 'openai.bicep' = {
  name: 'openaiDeploy'
  params: {
    openAIName: openAIName
    openAIRGName: openAIRGName
    namePrefix: namePrefix
    location: !empty(newOpenAILocation) ? newOpenAILocation : 'swedencentral'
    envName: namePrefix
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
    uniqueid: uniqueid
    machineLearningName: machineLearning.outputs.workspaceName
    storageName: storageModule.outputs.storageName
    chatAppName: webappModule.outputs.appName
    mainAppName: webappModule.outputs.appName2
    apiAppName: webappModule.outputs.appNameApi
  }
  dependsOn: [
    machineLearning, webappModule, storageModule
  ]
}

var oaiName = openAIResource.outputs.aoaiResourceName
var oaiKey = openAIResource.outputs.aoaiResourceKey

module apiAppSettings 'modules/appsettings.bicep' = {
  name: 'appsettings'
  dependsOn: [script, webappModule, storageModule, cosmosDbModule, machineLearning, documentInteligence, azureVisionResource, ai_search]
  params: {
    targetWebAppName: webappModule.outputs.appNameApi
    allSettings: {
      APPLICATIONINSIGHTS_CONNECTION_STRING: webappModule.outputs.appInsightsConnectionString
      ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
      // must be set again since chances are existing might be reset
      DOCKER_REGISTRY_SERVER_USERNAME: acrNameToUse
      DOCKER_REGISTRY_SERVER_PASSWORD: acrPasswordToUse
      DOCKER_REGISTRY_SERVER_URL: 'https://${acrNameToUse}.azurecr.io'
      TEXT_CHUNK_SIZE: '800'
      TEXT_CHUNK_OVERLAP: '128'
      TENACITY_TIMEOUT: '200'
      TENACITY_STOP_AFTER_DELAY: '300'
      AML_CLUSTER_NAME: 'mm-doc-cpu-cluster'
      AML_VMSIZE: 'STANDARD_D2_V2'
      PYTHONUNBUFFERED: '1'
      AZURE_CLIENT_ID: webappModule.outputs.userIdentityClientId // this is the managed identity, required by AML SDK
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
      AZURE_OPENAI_RESOURCE: oaiName
      AZURE_OPENAI_KEY: oaiKey
      AZURE_OPENAI_MODEL: 'gpt-4o'
      AZURE_OPENAI_RESOURCE_1: oaiName
      AZURE_OPENAI_KEY_1: oaiKey
      AZURE_OPENAI_RESOURCE_2: ''
      AZURE_OPENAI_KEY_2: ''
      AZURE_OPENAI_RESOURCE_3: ''
      AZURE_OPENAI_KEY_3: ''
      AZURE_OPENAI_RESOURCE_4: ''
      AZURE_OPENAI_KEY_4: ''
      AZURE_OPENAI_EMBEDDING_MODEL: 'text-embedding-3-large'
      AZURE_OPENAI_MODEL_VISION: 'gpt-4o'
      AZURE_OPENAI_API_VERSION: '2024-05-01-preview'
      AZURE_OPENAI_TEMPERATURE: '0'
      AZURE_OPENAI_TOP_P: '1.0'
      AZURE_OPENAI_MAX_TOKENS: '1000'
      AZURE_OPENAI_STOP_SEQUENCE: ''
      AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE: oaiName
      AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE_KEY: oaiKey
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

output chatUrl string = webappModule.outputs.chatUrl
output mainUrl string = webappModule.outputs.mainUrl
