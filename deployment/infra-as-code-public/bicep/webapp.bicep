/*
  Deploy a web app with a managed identity, diagnostic, and a private endpoint
*/
@description('The name of the storage account')
param mlWorkspaceName string
@description('The name of the storage account')
param storageAccount string

@description('The name of the container registry')
param containerRegistry string

@description('A prefix that will be prepended to resource names')
param namePrefix string = 'dev'

@description('This is the base name for each Azure resource name (6-12 chars)')
param uniqueid string

@description('The resource group location')
param location string = resourceGroup().location

@description('The name of the storage account')
param storageName string

@description('The name of the Log Analytics workspace for monitoring logs')
param logWorkspaceName string

// Variables

var appName = '${namePrefix}-app-chat-${uniqueid}'
var appName2 = '${namePrefix}-app-main-${uniqueid}'
var appNameApi = '${namePrefix}-app-api-${uniqueid}'

var appServicePlanName = 'asp-${appName}'
var appServiceManagedIdentityName = 'id-${appName}'
// var packageLocation = 'https://${storageName}.blob.${environment().suffixes.storage}/deploy/${publishFileName}'
var appInsightsName= 'appinsights-${appName}'


// ---- Existing resources ----

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing =  {
  name: storageName
}

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logWorkspaceName
}

resource azureMlWorkspace 'Microsoft.MachineLearningServices/workspaces@2021-04-01' existing = {
  name: mlWorkspaceName
}

// Existing container registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: containerRegistry
}

// Built-in Azure RBAC role that is applied to a Key storage to grant data reader permissions. 
resource blobDataReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  scope: subscription()
}

// ---- Web App resources ----

// Managed Identity for App Service
resource appServiceManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: appServiceManagedIdentityName
  location: location
}

// Grant the App Service managed identity storage data reader role permissions
resource blobDataReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(resourceGroup().id, appServiceManagedIdentity.name, blobDataReaderRole.id)
  properties: {
    roleDefinitionId: blobDataReaderRole.id
    principalType: 'ServicePrincipal'
    principalId: appServiceManagedIdentity.properties.principalId
  }
}

resource contributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor role ID
}

resource mlContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: azureMlWorkspace 
  name: guid(resourceGroup().id, appServiceManagedIdentity.name, contributorRole.id)
  properties: {
    roleDefinitionId: contributorRole.id
    principalType: 'ServicePrincipal'
    principalId: appServiceManagedIdentity.properties.principalId
  }
}

// Grant the App Service managed identity access to the container registry
// resource acrPullRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
//   scope: subscription()
//   name: '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull role ID
// }
// resource acrRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
//   name: guid(acr.id, appServiceManagedIdentity.name, 'AcrPull')
//   scope: acr
//   properties: {
//     roleDefinitionId: acrPullRole.id
//     principalId: appServiceManagedIdentity.properties.principalId
//   }
// }


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
  name: appName
  location: location
  kind: 'app,linux,container'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appServiceManagedIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id    
    httpsOnly: false
    keyVaultReferenceIdentity: appServiceManagedIdentity.id
    hostNamesDisabled: false
    siteConfig: {
      acrUseManagedIdentityCreds: false
      // acrUserManagedIdentityID: appServiceManagedIdentity.id      
      http20Enabled: true
      linuxFxVersion: 'DOCKER|${containerRegistry}.azurecr.io/research-copilot:latest'
      numberOfWorkers: 1
      alwaysOn: true
    }
    storageAccountRequired: false  
  }
  dependsOn: [    
    blobDataReaderRoleAssignment
  ]
}

resource webApp2 'Microsoft.Web/sites@2022-09-01' = {
  name: appName2
  location: location
  kind: 'app,linux,container'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appServiceManagedIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id    
    httpsOnly: false
    keyVaultReferenceIdentity: appServiceManagedIdentity.id
    hostNamesDisabled: false
    siteConfig: {
      acrUseManagedIdentityCreds: false
      // acrUserManagedIdentityID: appServiceManagedIdentity.id
      http20Enabled: true
      linuxFxVersion: 'DOCKER|${containerRegistry}.azurecr.io/research-copilot-main:latest'
      numberOfWorkers: 1
      alwaysOn: true
    }
    storageAccountRequired: false
  }
  dependsOn: [    
    blobDataReaderRoleAssignment
  ]
}

resource webAppApi 'Microsoft.Web/sites@2022-09-01' = {
  name: appNameApi
  location: location
  kind: 'app,linux,container'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appServiceManagedIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id    
    httpsOnly: false
    keyVaultReferenceIdentity: appServiceManagedIdentity.id
    hostNamesDisabled: false
    siteConfig: {
      acrUseManagedIdentityCreds: false
      // acrUserManagedIdentityID: appServiceManagedIdentity.id
      http20Enabled: true
      linuxFxVersion: 'DOCKER|${containerRegistry}.azurecr.io/research-copilot-api:latest'
      numberOfWorkers: 1
      alwaysOn: true
    }
    storageAccountRequired: false
  }
  dependsOn: [    
    blobDataReaderRoleAssignment
  ]
}


// App Settings
resource appsettings 'Microsoft.Web/sites/config@2022-09-01' = {
  name: 'appsettings'
  parent: webApp
  properties: {
    // WEBSITE_RUN_FROM_PACKAGE: packageLocation
    // WEBSITE_RUN_FROM_PACKAGE_BLOB_MI_RESOURCE_ID: appServiceManagedIdentity.id
    // AZURE_SQL_CONNECTIONSTRING: '@Microsoft.KeyVault(SecretUri=https://${keyVault.name}${environment().suffixes.keyvaultDns}/secrets/adWorksConnString)'
    APPINSIGHTS_INSTRUMENTATIONKEY: appInsights.properties.InstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.properties.ConnectionString
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
    API_BASE_URL: 'https://${appNameApi}.azurewebsites.net'
  }
}

// App Settings
resource appsettings2 'Microsoft.Web/sites/config@2022-09-01' = {
  name: 'appsettings'
  parent: webApp2
  properties: {
    // WEBSITE_RUN_FROM_PACKAGE: packageLocation
    // WEBSITE_RUN_FROM_PACKAGE_BLOB_MI_RESOURCE_ID: appServiceManagedIdentity.id
    // AZURE_SQL_CONNECTIONSTRING: '@Microsoft.KeyVault(SecretUri=https://${keyVault.name}${environment().suffixes.keyvaultDns}/secrets/adWorksConnString)'
    APPINSIGHTS_INSTRUMENTATIONKEY: appInsights.properties.InstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.properties.ConnectionString
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'    
    API_BASE_URL: 'https://${appNameApi}.azurewebsites.net'
  }
}
// App Settings
resource appsettingsApi 'Microsoft.Web/sites/config@2022-09-01' = {
  name: 'appsettings'
  parent: webAppApi
  properties: {
    // WEBSITE_RUN_FROM_PACKAGE: packageLocation
    // WEBSITE_RUN_FROM_PACKAGE_BLOB_MI_RESOURCE_ID: appServiceManagedIdentity.id
    // AZURE_SQL_CONNECTIONSTRING: '@Microsoft.KeyVault(SecretUri=https://${keyVault.name}${environment().suffixes.keyvaultDns}/secrets/adWorksConnString)'
    APPINSIGHTS_INSTRUMENTATIONKEY: appInsights.properties.InstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.properties.ConnectionString
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
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

// Application insights resource
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
  }
}

// Only API mounts the Azure Files share

var fileshare = {
  accountName: storageAccount
  mountPath: '/data'
  shareName: storageAccount
  type: 'AzureFiles'
  accessKey: listKeys(resourceId('Microsoft.Storage/storageAccounts', storageAccount), '2023-01-01').keys[0].value
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
  name: '${appName}.azurewebsites.net'
  properties: {
    hostNameType: 'Verified'
    siteName: appName
  }
}

resource webAppHostNameBinding2 'Microsoft.Web/sites/hostNameBindings@2023-01-01' = {
  parent: webApp2
  name: '${appName2}.azurewebsites.net'
  properties: {
    hostNameType: 'Verified'
    siteName: appName2
  }
}

resource webAppHostNameBindingApi 'Microsoft.Web/sites/hostNameBindings@2023-01-01' = {
  parent: webAppApi
  name: '${appNameApi}.azurewebsites.net'
  properties: {
    hostNameType: 'Verified'
    siteName: appNameApi
  }
}

// Output

@description('The name of the app service plan.')
output appServicePlanName string = appServicePlan.name
@description('The name of the web app.')
output appName string = webApp.name
@description('The name of the web app.')
output appName2 string = webApp2.name
@description('The name of the web app.')
output appNameApi string = webAppApi.name
