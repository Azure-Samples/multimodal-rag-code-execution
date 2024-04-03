/*
  Deploy a web app with a managed identity, diagnostic, and a private endpoint
*/
// param appName string
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

// variables
var fileshare = {
  accountName: storageAccount
  mountPath: '/data'
  shareName: storageAccount
  type: 'AzureFiles'
  accessKey: listKeys(resourceId('Microsoft.Storage/storageAccounts', storageAccount), '2023-01-01').keys[0].value
}

var appName = '${namePrefix}-app-chat-${uniqueid}'
var appName2 = '${namePrefix}-app-main-${uniqueid}'

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
      functionAppScaleLimit: 0
      
      http20Enabled: true
      linuxFxVersion: 'DOCKER|${containerRegistry}.azurecr.io/research-copilot:latest'
      minimumElasticInstanceCount: 0
      numberOfWorkers: 1
      cors: {
        allowedOrigins: [
          '*'
        ]
        supportCredentials: false
      }
      publicNetworkAccess: 'Disabled'
      alwaysOn: true
    }
    storageAccountRequired: false
    vnetContentShareEnabled: false
    vnetImagePullEnabled: false        
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
      functionAppScaleLimit: 0
      
      http20Enabled: true
      linuxFxVersion: 'DOCKER|${containerRegistry}.azurecr.io/research-copilot-main:latest'
      minimumElasticInstanceCount: 0
      numberOfWorkers: 1
      cors: {
        allowedOrigins: [
          '*'
        ]
        supportCredentials: false
      }
      publicNetworkAccess: 'Disabled'
      alwaysOn: true
    }
    storageAccountRequired: false
    vnetContentShareEnabled: false
    vnetImagePullEnabled: false    
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




// create application insights resource
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
  }
}


resource ftpPublishingPolicy 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-01-01' = {
  parent: webApp
  name: 'ftp'
  // location: location
  properties: {
    allow: false
  }
}


resource ftpPublishingPolicy2 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-01-01' = {
  parent: webApp2
  name: 'ftp'
  // location: location
  properties: {
    allow: false
  }
}

resource scmPublishingPolicy 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-01-01' = {
  parent: webApp
  name: 'scm'
  // location: location
  properties: {
    allow: true
  }
}


resource scmPublishingPolicy2 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-01-01' = {
  parent: webApp2
  name: 'scm'
  // location: location
  properties: {
    allow: true
  }
}


resource webAppConfig 'Microsoft.Web/sites/config@2023-01-01' = {
  parent: webApp
  name: 'web'
  // location: location
  properties: {
    acrUseManagedIdentityCreds: false
    alwaysOn: true
    autoHealEnabled: false
    azureStorageAccounts: {
      fileshare: fileshare
    }
    cors: {
      allowedOrigins: [
        '*'
      ]
      supportCredentials: false
    }
    defaultDocuments: [
      'Default.htm','Default.html','Default.asp','index.htm','index.html','iisstart.htm','default.aspx','index.php','hostingstart.html']
    detailedErrorLoggingEnabled: false
    elasticWebAppScaleLimit: 0
    experiments: {
      rampUpRules: []
    }
    ftpsState: 'FtpsOnly'
    functionsRuntimeScaleMonitoringEnabled: false
    http20Enabled: false
    httpLoggingEnabled: true
    ipSecurityRestrictions: [
      {
        action: 'Allow'
        description: 'Allow all access'
        ipAddress: 'Any'
        name: 'Allow all'
        priority: 2147483647
      }
    ]
    linuxFxVersion: 'DOCKER|${containerRegistry}.azurecr.io/research-copilot:latest'    
    loadBalancing: 'LeastRequests'
    localMySqlEnabled: false
    logsDirectorySizeLimit: 35
    managedPipelineMode: 'Integrated'
    minTlsVersion: '1.2'
    minimumElasticInstanceCount: 0
    netFrameworkVersion: 'v4.0'
    numberOfWorkers: 1
    preWarmedInstanceCount: 0
    publicNetworkAccess: 'Enabled'
    publishingUsername: '$ped-powerpoint-addin'
    remoteDebuggingEnabled: false
    remoteDebuggingVersion: 'VS2019'
    requestTracingEnabled: false
    scmIpSecurityRestrictions: [
      {
        action: 'Allow'
        description: 'Allow all access'
        ipAddress: 'Any'
        name: 'Allow all'
        priority: 2147483647
      }
    ]
    scmIpSecurityRestrictionsUseMain: false
    scmMinTlsVersion: '1.2'
    scmType: 'None'
    use32BitWorkerProcess: true
    virtualApplications: [
      {
        physicalPath: 'site\\wwwroot'
        preloadEnabled: true
        virtualPath: '/'
      }
    ]
    vnetPrivatePortsCount: 0
    // vnetRouteAllEnabled: true
    webSocketsEnabled: false
  }
}

resource webAppConfig2 'Microsoft.Web/sites/config@2023-01-01' = {
  parent: webApp2
  name: 'web'
  // location: location
  properties: {
    acrUseManagedIdentityCreds: false
    alwaysOn: true
    autoHealEnabled: false
    azureStorageAccounts: {
      fileshare: fileshare
    }
    cors: {
      allowedOrigins: [
        '*'
      ]
      supportCredentials: false
    }
    defaultDocuments: [
      'Default.htm','Default.html','Default.asp','index.htm','index.html','iisstart.htm','default.aspx','index.php','hostingstart.html']
    detailedErrorLoggingEnabled: false
    elasticWebAppScaleLimit: 0
    experiments: {
      rampUpRules: []
    }
    ftpsState: 'FtpsOnly'
    functionsRuntimeScaleMonitoringEnabled: false
    http20Enabled: false
    httpLoggingEnabled: true
    ipSecurityRestrictions: [
      {
        action: 'Allow'
        description: 'Allow all access'
        ipAddress: 'Any'
        name: 'Allow all'
        priority: 2147483647
      }
    ]
    linuxFxVersion: 'DOCKER|${containerRegistry}.azurecr.io/research-copilot:latest'
    loadBalancing: 'LeastRequests'
    localMySqlEnabled: false
    logsDirectorySizeLimit: 35
    managedPipelineMode: 'Integrated'
    minTlsVersion: '1.2'
    minimumElasticInstanceCount: 0
    netFrameworkVersion: 'v4.0'
    numberOfWorkers: 1
    preWarmedInstanceCount: 0
    publicNetworkAccess: 'Enabled'
    publishingUsername: '$ped-powerpoint-addin'
    remoteDebuggingEnabled: false
    remoteDebuggingVersion: 'VS2019'
    requestTracingEnabled: false
    scmIpSecurityRestrictions: [
      {
        action: 'Allow'
        description: 'Allow all access'
        ipAddress: 'Any'
        name: 'Allow all'
        priority: 2147483647
      }
    ]
    scmIpSecurityRestrictionsUseMain: false
    scmMinTlsVersion: '1.2'
    scmType: 'None'
    use32BitWorkerProcess: true
    virtualApplications: [
      {
        physicalPath: 'site\\wwwroot'
        preloadEnabled: true
        virtualPath: '/'
      }
    ]
    vnetPrivatePortsCount: 0
    // vnetRouteAllEnabled: true
    webSocketsEnabled: false
  }
}


resource webAppHostNameBinding 'Microsoft.Web/sites/hostNameBindings@2023-01-01' = {
  parent: webApp
  name: '${appName}.azurewebsites.net'
  // location: location
  properties: {
    hostNameType: 'Verified'
    siteName: appName
  }
}


resource webAppHostNameBinding2 'Microsoft.Web/sites/hostNameBindings@2023-01-01' = {
  parent: webApp2
  name: '${appName2}.azurewebsites.net'
  // location: location
  properties: {
    hostNameType: 'Verified'
    siteName: appName2
  }
}



@description('The name of the app service plan.')
output appServicePlanName string = appServicePlan.name

@description('The name of the web app.')
output appName string = webApp.name
@description('The name of the web app.')
output appName2 string = webApp2.name



