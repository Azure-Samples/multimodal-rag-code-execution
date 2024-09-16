param uniqueId string
param prefix string
param uamiId string
param uamiClientId string
param openAiName string
param openAiApiKey string
param applicationInsightsInstrumentationKey string
param containerRegistry string = '${prefix}acr${uniqueId}'
param location string = resourceGroup().location
param logAnalyticsWorkspaceName string
param mlWorkspaceName string
param storageName string
param storageKey string
param cosmosDbUri string
param cosmosDbKey string
param cosmosdbName string
param documentIntelligenceEndpoint string
param documentIntelligenceKey string
param aiSearchEndpoint string
param aiSearchAdminKey string
param aiSearchRegion string
param accountsVisionEndpoint string
param accountsVisionKey string
param skipImagePulling bool = false
var chatContainerImage = !skipImagePulling ? '${containerRegistry}.azurecr.io/research-copilot:latest' : 'mcr.microsoft.com/mcr/hello-world'
var mainContainerImage = !skipImagePulling ? '${containerRegistry}.azurecr.io/research-copilot-main:latest' : 'mcr.microsoft.com/mcr/hello-world'
var apiContainerImage = !skipImagePulling ? '${containerRegistry}.azurecr.io/research-copilot-api:latest' : 'mcr.microsoft.com/mcr/hello-world'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

// Environment variables for API container apps and ingestion job
var allSettings = [
  {
    name: 'APPSETTING_WEBSITE_SITE_NAME'
    value: 'foo' // This is required to trick Azure ML SDK v1 to read the right environment variables to use MSI
  }
  {
    name: 'AZURE_CLIENT_ID'
    value: uamiClientId // https://learn.microsoft.com/en-us/answers/questions/1225865/unable-to-get-a-user-assigned-managed-identity-wor
  }
  {
    name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
    value: applicationInsightsInstrumentationKey
  }
  {
    name: 'AZURE_OPENAI_API_VERSION'
    value: '2024-02-15-preview'
  }
  {
    name: 'TEXT_CHUNK_SIZE'
    value: '800'
  }
  {
    name: 'TEXT_CHUNK_OVERLAP'
    value: '128'
  }
  {
    name: 'TENACITY_TIMEOUT'
    value: '200'
  }
  {
    name: 'TENACITY_STOP_AFTER_DELAY'
    value: '300'
  }
  {
    name: 'AML_CLUSTER_NAME'
    value: 'mm-doc-cpu-cluster'
  }
  {
    name: 'AML_VMSIZE'
    value: 'STANDARD_D2_V2'
  }
  {
    name: 'PYTHONUNBUFFERED'
    value: '1'
  }
  {
    name: 'INITIAL_INDEX'
    value: 'rag-data'
  }
  {
    name: 'AML_SUBSCRIPTION_ID'
    value: subscription().subscriptionId
  }
  {
    name: 'AML_RESOURCE_GROUP'
    value: resourceGroup().name
  }
  {
    name: 'AML_WORKSPACE_NAME'
    value: mlWorkspaceName
  }
  {
    name: 'AZURE_FILE_SHARE_ACCOUNT'
    value: storageName
  }
  {
    name: 'AZURE_FILE_SHARE_NAME'
    value: storageName
  }
  {
    name: 'AZURE_FILE_SHARE_KEY'
    value: storageKey
  }
  {
    name: 'PYTHONPATH'
    value: './code/:../code:../TaskWeaver:./code/utils:../code/utils:../../code:../../code/utils'
  }
  {
    name: 'COSMOS_URI'
    value: cosmosDbUri
  }
  {
    name: 'COSMOS_KEY'
    value: cosmosDbKey
  }
  {
    name: 'COSMOS_DB_NAME'
    value: cosmosdbName
  }
  {
    name: 'COSMOS_CONTAINER_NAME'
    value: 'prompts'
  }
  {
    name: 'COSMOS_CATEGORYID'
    value: 'prompts'
  }
  {
    name: 'COSMOS_LOG_CONTAINER'
    value: 'logs'
  }
  {
    name: 'ROOT_PATH_INGESTION'
    value: '/data/data'
  }
  {
    name: 'PROMPTS_PATH'
    value: 'prompts'
  }
  {
    name: 'DI_ENDPOINT'
    value: documentIntelligenceEndpoint
  }
  {
    name: 'DI_KEY'
    value: documentIntelligenceKey
  }
  {
    name: 'DI_API_VERSION'
    value: '2024-02-29-preview'
  }
  {
    name: 'AZURE_OPENAI_RESOURCE'
    value: openAiName
  }
  {
    name: 'AZURE_OPENAI_KEY'
    value: openAiApiKey
  }
  {
    name: 'AZURE_OPENAI_MODEL'
    value: 'gpt-4o'
  }
  {
    name: 'AZURE_OPENAI_RESOURCE_1'
    value: openAiName
  }
  {
    name: 'AZURE_OPENAI_KEY_1'
    value: openAiApiKey
  }
  {
    name: 'AZURE_OPENAI_RESOURCE_2'
    value: ''
  }
  {
    name: 'AZURE_OPENAI_KEY_2'
    value: ''
  }
  {
    name: 'AZURE_OPENAI_RESOURCE_3'
    value: ''
  }
  {
    name: 'AZURE_OPENAI_KEY_3'
    value: ''
  }
  {
    name: 'AZURE_OPENAI_RESOURCE_4'
    value: ''
  }
  {
    name: 'AZURE_OPENAI_KEY_4'
    value: ''
  }
  {
    name: 'AZURE_OPENAI_EMBEDDING_MODEL'
    value: 'text-embedding-3-large'
  }
  {
    name: 'AZURE_OPENAI_MODEL_VISION'
    value: 'gpt-4o'
  }
  {
    name: 'AZURE_OPENAI_API_VERSION'
    value: '2024-05-01-preview'
  }
  {
    name: 'AZURE_OPENAI_TEMPERATURE'
    value: '0'
  }
  {
    name: 'AZURE_OPENAI_TOP_P'
    value: '1.0'
  }
  {
    name: 'AZURE_OPENAI_MAX_TOKENS'
    value: '1000'
  }
  {
    name: 'AZURE_OPENAI_STOP_SEQUENCE'
    value: ''
  }
  {
    name: 'AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE'
    value: openAiName
  }
  {
    name: 'AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE_KEY'
    value: openAiApiKey
  }
  {
    name: 'AZURE_OPENAI_EMBEDDING_MODEL_API_VERSION'
    value: '2023-12-01-preview'
  }
  {
    name: 'COG_SERV_ENDPOINT'
    value: aiSearchEndpoint
  }
  {
    name: 'COG_SERV_KEY'
    value: aiSearchAdminKey
  }
  {
    name: 'COG_SERV_LOCATION'
    value: aiSearchRegion
  }
  {
    name: 'AZURE_VISION_ENDPOINT'
    value: accountsVisionEndpoint
  }
  {
    name: 'AZURE_VISION_KEY'
    value: accountsVisionKey
  }
  {
    name: 'AZURE_OPENAI_ASSISTANTSAPI_ENDPOINT'
    value: ''
  }
  {
    name: 'AZURE_OPENAI_ASSISTANTSAPI_KEY'
    value: ''
  }
  {
    name: 'OPENAI_API_KEY'
    value: ''
  }
  {
    name: 'COG_SEARCH_ENDPOINT'
    value: aiSearchEndpoint
  }
  {
    name: 'COG_SEARCH_ADMIN_KEY'
    value: aiSearchAdminKey
  }
  {
    name: 'COG_VEC_SEARCH_API_VERSION'
    value: '2023-11-01'
  }
  {
    name: 'COG_SEARCH_ENDPOINT_PROD'
    value: aiSearchEndpoint
  }
  {
    name: 'COG_SEARCH_ADMIN_KEY_PROD'
    value: aiSearchAdminKey
  }
  {
    name: 'INGESTION_JOB_NAME'
    value: '${prefix}-ingestion-job-${uniqueId}'
  }
]

// see https://azureossd.github.io/2023/01/03/Using-Managed-Identity-and-Bicep-to-pull-images-with-Azure-Container-Apps/
resource containerAppEnv 'Microsoft.App/managedEnvironments@2023-11-02-preview' = {
  name: '${prefix}-containerAppEnv-${uniqueId}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}


resource dataShare 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  parent: containerAppEnv
  name: 'data'
  properties: {
    azureFile: {
      accountName: storageName 
      shareName: storageName 
      accountKey: storageKey
      accessMode: 'ReadWrite'
    }
  }
}

resource apiContainerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: '${prefix}-api-${uniqueId}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 80
        transport: 'auto'
      }
      registries: [
        {
          server: '${containerRegistry}.azurecr.io'
          identity: uamiId
        }
      ]
    }
    template: {
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      volumes: [
        {
          name: 'data'
          storageName: dataShare.name
          storageType: 'AzureFile'
        }
      ]
      containers: [
        {
          name: 'api'
          image: apiContainerImage
          resources: {
            cpu: 2
            memory: '4Gi'
          }
          volumeMounts: [
            {
              volumeName: 'data'
              mountPath: '/data'
            }
          ]
          env: allSettings
        }
      ]
    }
  }
}

resource processingJob 'Microsoft.App/jobs@2023-11-02-preview' = {
  name: '${prefix}-ingestion-job-${uniqueId}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    environmentId: containerAppEnv.id
    configuration: {
      replicaTimeout: 60 * 60 // 1 hour
      triggerType: 'Manual'
      registries: [
        {
          server: '${containerRegistry}.azurecr.io'
          identity: uamiId
        }
      ]
    }
    template: {
      volumes: [
        {
          name: 'data'
          storageName: dataShare.name
          storageType: 'AzureFile'
        }
      ]
      containers: [
        {
          name: 'ingestion'
          image: apiContainerImage
          command: [
            'python'
          ]
          args: [
            'ingest_doc.py'
            '"--ingestion_params_dict"'
            '{}' // Will be replaced by the actual parameters
          ]
          resources: {
            cpu: 2
            memory: '4Gi'
          }
          volumeMounts: [
            {
              volumeName: 'data'
              mountPath: '/data'
            }
          ]
          env: allSettings
        }
      ]
    }
  }

}

resource chatContainerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: '${prefix}-chat-${uniqueId}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
      }
      registries: [
        {
          server: '${containerRegistry}.azurecr.io'
          identity: uamiId
        }
      ]
    }
    template: {
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      containers: [
        {
          name: 'chat'
          image: chatContainerImage
          resources: {
            cpu: 1
            memory: '2Gi'
          }
          env: [
            {
              name: 'API_BASE_URL'
              value: 'http://${apiContainerApp.name}'
            }
          ]
        }
      ]
    }
  }
}

resource mainContainerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: '${prefix}-main-${uniqueId}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
      }
      registries: [
        {
          server: '${containerRegistry}.azurecr.io'
          identity: uamiId
        }
      ]
    }
    template: {
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      containers: [
        {
          name: 'ui'
          image: mainContainerImage
          resources: {
            cpu: 1
            memory: '2Gi'
          }
          env: [
            {
              name: 'API_BASE_URL'
              value: 'http://${apiContainerApp.name}'
            }
          ]
        }
      ]
    }
  }
}

output mainContainerAppUrl string = mainContainerApp.properties.latestRevisionFqdn
output chatContainerAppUrl string = chatContainerApp.properties.latestRevisionFqdn
