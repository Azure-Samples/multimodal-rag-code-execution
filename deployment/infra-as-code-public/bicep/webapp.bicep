param uniqueId string
param prefix string
param uamiId string
param uamiClientId string
param openAiName string
param openAiApiKey string
param applicationInsightsInstrumentationKey string
param containerRegistryName string
@secure()
param containerRegistryPassword string
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

// Variables
var chatAppName = '${prefix}-app-chat-${uniqueId}'
var mainAppName = '${prefix}-app-main-${uniqueId}'
var apiAppName = '${prefix}-app-api-${uniqueId}'

var appServicePlanName = 'asp-${chatAppName}'


// ---- Existing resources ----
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}


//App service plan
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  properties: {
    elasticScaleEnabled: false
    hyperV: false
    isSpot: false
    isXenon: false
    maximumElasticWorkerCount: 1
    perSiteScaling: false
    reserved: true
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
  sku: {
    capacity: 1
    family: 'Pv3'
    name: 'P1v3'
    size: 'P1v3'
    tier: 'PremiumV3'
  }
}

// Web App
resource webApp 'Microsoft.Web/sites@2022-09-01' = {
  name: chatAppName
  location: location
  kind: 'app,linux,container'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id    
    httpsOnly: false
    keyVaultReferenceIdentity: uamiId
    hostNamesDisabled: false
    siteConfig: {
      acrUseManagedIdentityCreds: false
      // acrUserManagedIdentityID: appServiceManagedIdentity.id      
      http20Enabled: true
      linuxFxVersion: 'DOCKER|${containerRegistryName}.azurecr.io/research-copilot:latest'
      numberOfWorkers: 1
      alwaysOn: true
    }
    storageAccountRequired: false  
  }
}

resource webApp2 'Microsoft.Web/sites@2022-09-01' = {
  name: mainAppName
  location: location
  kind: 'app,linux,container'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id    
    httpsOnly: false
    keyVaultReferenceIdentity: uamiId
    hostNamesDisabled: false
    siteConfig: {
      acrUseManagedIdentityCreds: false
      // acrUserManagedIdentityID: appServiceManagedIdentity.id
      http20Enabled: true
      linuxFxVersion: 'DOCKER|${containerRegistryName}.azurecr.io/research-copilot-main:latest'
      numberOfWorkers: 1
      alwaysOn: true
    }
    storageAccountRequired: false
  }
}

resource webAppApi 'Microsoft.Web/sites@2022-09-01' = {
  name: apiAppName
  location: location
  kind: 'app,linux,container'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id    
    httpsOnly: false
    keyVaultReferenceIdentity: uamiId
    hostNamesDisabled: false
    siteConfig: {
      acrUseManagedIdentityCreds: false
      // acrUserManagedIdentityID: appServiceManagedIdentity.id
      http20Enabled: true
      linuxFxVersion: 'DOCKER|${containerRegistryName}.azurecr.io/research-copilot-api:latest'
      numberOfWorkers: 1
      alwaysOn: true
    }
    storageAccountRequired: false
  }
}


// App Settings
resource appsettings 'Microsoft.Web/sites/config@2022-09-01' = {
  name: 'appsettings'
  parent: webApp
  properties: {
    APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsightsInstrumentationKey
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
    DOCKER_ENABLE_CI: '1'
    DOCKER_REGISTRY_SERVER_USERNAME: containerRegistryName
    DOCKER_REGISTRY_SERVER_PASSWORD: containerRegistryPassword
    DOCKER_REGISTRY_SERVER_URL: 'https://${containerRegistryName}.azurecr.io'
    API_BASE_URL: 'https://${apiAppName}.azurewebsites.net'
  }
}

// App Settings
resource appsettings2 'Microsoft.Web/sites/config@2022-09-01' = {
  name: 'appsettings'
  parent: webApp2
  properties: {
    APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsightsInstrumentationKey
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'    
    DOCKER_ENABLE_CI: '1'
    DOCKER_REGISTRY_SERVER_USERNAME: containerRegistryName
    DOCKER_REGISTRY_SERVER_PASSWORD: containerRegistryPassword
    DOCKER_REGISTRY_SERVER_URL: 'https://${containerRegistryName}.azurecr.io'
    API_BASE_URL: 'https://${apiAppName}.azurewebsites.net'
  }
}
// App Settings
resource appsettingsApi 'Microsoft.Web/sites/config@2022-09-01' = {
  name: 'appsettings'
  parent: webAppApi
  properties: {
    APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsightsInstrumentationKey
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
    // must be set again since chances are existing might be reset
    DOCKER_REGISTRY_SERVER_USERNAME: containerRegistryName
    DOCKER_REGISTRY_SERVER_PASSWORD: containerRegistryPassword
    DOCKER_REGISTRY_SERVER_URL: 'https://${containerRegistryName}.azurecr.io'
    TEXT_CHUNK_SIZE: '800'
    TEXT_CHUNK_OVERLAP: '128'
    TENACITY_TIMEOUT: '200'
    TENACITY_STOP_AFTER_DELAY: '300'
    AML_CLUSTER_NAME: 'mm-doc-cpu-cluster'
    AML_VMSIZE: 'STANDARD_D2_V2'
    PYTHONUNBUFFERED: '1'
    AZURE_CLIENT_ID: uamiClientId // this is the managed identity, required by AML SDK
    INITIAL_INDEX: 'rag-data'
    AML_SUBSCRIPTION_ID: subscription().subscriptionId
    AML_RESOURCE_GROUP: resourceGroup().name
    AML_WORKSPACE_NAME: mlWorkspaceName
    AZURE_FILE_SHARE_ACCOUNT: storageName
    AZURE_FILE_SHARE_NAME: storageName
    AZURE_FILE_SHARE_KEY: storageKey
    PYTHONPATH: './code/:../code:../TaskWeaver:./code/utils:../code/utils:../../code:../../code/utils'
    COSMOS_URI: cosmosDbUri
    COSMOS_KEY: cosmosDbKey
    COSMOS_DB_NAME: cosmosdbName
    COSMOS_CONTAINER_NAME: 'prompts'
    COSMOS_CATEGORYID: 'prompts'
    COSMOS_LOG_CONTAINER: 'logs'
    ROOT_PATH_INGESTION: '/data/data'
    PROMPTS_PATH: 'prompts'
    DI_ENDPOINT: documentIntelligenceEndpoint
    DI_KEY: documentIntelligenceKey
    DI_API_VERSION: '2024-02-29-preview'
    AZURE_OPENAI_RESOURCE: openAiName
    AZURE_OPENAI_KEY: openAiApiKey
    AZURE_OPENAI_MODEL: 'gpt-4o'
    AZURE_OPENAI_RESOURCE_1: openAiName
    AZURE_OPENAI_KEY_1: openAiApiKey
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
    AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE: openAiName
    AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE_KEY: openAiApiKey
    AZURE_OPENAI_EMBEDDING_MODEL_API_VERSION: '2023-12-01-preview'
    COG_SERV_ENDPOINT: aiSearchEndpoint
    COG_SERV_KEY: aiSearchAdminKey
    COG_SERV_LOCATION: aiSearchRegion
    AZURE_VISION_ENDPOINT: accountsVisionEndpoint
    AZURE_VISION_KEY: accountsVisionKey
    AZURE_OPENAI_ASSISTANTSAPI_ENDPOINT: ''
    AZURE_OPENAI_ASSISTANTSAPI_KEY: ''
    OPENAI_API_KEY: ''
    COG_SEARCH_ENDPOINT: aiSearchEndpoint
    COG_SEARCH_ADMIN_KEY: aiSearchAdminKey
    COG_VEC_SEARCH_API_VERSION: '2023-11-01'
    COG_SEARCH_ENDPOINT_PROD: aiSearchEndpoint
    COG_SEARCH_ADMIN_KEY_PROD: aiSearchAdminKey
  }
}

// App service plan diagnostic settings
resource appServicePlanDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${appServicePlan.name}-diagnosticSettings'
  scope: appServicePlan
  properties: {
    workspaceId: logWorkspace.id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

//Web App diagnostic settings
resource webAppDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${webApp.name}-diagnosticSettings'
  scope: webApp
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        categoryGroup: null
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        categoryGroup: null
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        categoryGroup: null
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource webAppDiagSettings1 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${webApp2.name}-diagnosticSettings'
  scope: webApp2
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        categoryGroup: null
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        categoryGroup: null
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        categoryGroup: null
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource webAppDiagSettingsApi 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${webAppApi.name}-diagnosticSettings'
  scope: webAppApi
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        categoryGroup: null
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        categoryGroup: null
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        categoryGroup: null
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource webappLogs 'Microsoft.Web/sites/config@2022-09-01' = {
  name: 'logs'
  parent: webApp
  properties: {
    applicationLogs: {
      fileSystem: {
        level: 'Information' // Possible values include: 'Off', 'Verbose', 'Information', 'Warning', 'Error'
      }
    }
    httpLogs: {
      fileSystem: {
        retentionInMb: 35
        retentionInDays: 1
        enabled: true
      }
    }
  }
}
resource webapp2Logs 'Microsoft.Web/sites/config@2022-09-01' = {
  name: 'logs'
  parent: webApp2
  properties: {
    applicationLogs: {
      fileSystem: {
        level: 'Information' // Possible values include: 'Off', 'Verbose', 'Information', 'Warning', 'Error'
      }
    }
    httpLogs: {
      fileSystem: {
        retentionInMb: 35
        retentionInDays: 1
        enabled: true
      }
    }
  }
}

resource webappApiLogs 'Microsoft.Web/sites/config@2022-09-01' = {
  name: 'logs'
  parent: webAppApi
  properties: {
    applicationLogs: {
      fileSystem: {
        level: 'Information' // Possible values include: 'Off', 'Verbose', 'Information', 'Warning', 'Error'
      }
    }
    httpLogs: {
      fileSystem: {
        retentionInMb: 35
        retentionInDays: 1
        enabled: true
      }
    }
  }
}

// App service plan auto scale settings
resource appServicePlanAutoScaleSettings 'Microsoft.Insights/autoscalesettings@2022-10-01' = {
  name: '${appServicePlan.name}-autoscale'
  location: location
  properties: {
    enabled: true
    targetResourceUri: appServicePlan.id
    profiles: [
      {
        name: 'Scale out condition'
        capacity: {
          maximum: '5'
          default: '1'
          minimum: '1'
        }
        rules: [
          {
            scaleAction: {
              type: 'ChangeCount'
              direction: 'Increase'
              cooldown: 'PT5M'
              value: '1'
            }
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricNamespace: 'microsoft.web/serverfarms'
              operator: 'GreaterThan'
              timeAggregation: 'Average'
              threshold: 70
              metricResourceUri: appServicePlan.id
              timeWindow: 'PT10M'
              timeGrain: 'PT1M'
              statistic: 'Average'
            }
          }
        ]
      }
    ]
  }
  dependsOn: [
    webApp
    appServicePlanDiagSettings
  ]
}

// Only API mounts the Azure Files share

var fileshare = {
  accountName: storageName
  mountPath: '/data'
  shareName: storageName
  type: 'AzureFiles'
  accessKey: storageKey
}

resource webAppConfigApi 'Microsoft.Web/sites/config@2023-01-01' = {
  parent: webAppApi
  name: 'web'
  properties: {    
    azureStorageAccounts: {
      fileshare: fileshare
    }
  }
}

// Web App Hostname Binding

resource webAppHostNameBinding 'Microsoft.Web/sites/hostNameBindings@2023-01-01' = {
  parent: webApp
  name: '${chatAppName}.azurewebsites.net'
  properties: {
    hostNameType: 'Verified'
    siteName: chatAppName
  }
}

resource webAppHostNameBinding2 'Microsoft.Web/sites/hostNameBindings@2023-01-01' = {
  parent: webApp2
  name: '${mainAppName}.azurewebsites.net'
  properties: {
    hostNameType: 'Verified'
    siteName: mainAppName
  }
}

resource webAppHostNameBindingApi 'Microsoft.Web/sites/hostNameBindings@2023-01-01' = {
  parent: webAppApi
  name: '${apiAppName}.azurewebsites.net'
  properties: {
    hostNameType: 'Verified'
    siteName: apiAppName
  }
}


// Output
output chatUrl string = webApp.properties.defaultHostName
output mainUrl string = webApp2.properties.defaultHostName
