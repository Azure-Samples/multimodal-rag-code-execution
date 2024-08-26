param name string
param prefix string
param location string = resourceGroup().location
param fileShareName string
param storageAccountName string
param registryName string
param logWorkspaceName string
param appInsightsName string

param mountPath string = '/mnt/data'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logWorkspaceName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource environment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: '${prefix}-${name}-env'
  location: location
  properties: {
    daprAIInstrumentationKey:appInsights.properties.InstrumentationKey
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

resource containerApp 'Microsoft.Web/containerApps@2023-05-01' = {
  name: name
  location: location
  properties: {
    kubeEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Multiple'
      secrets: []
      registries: []
    }
    template: {
      containers: [
        {
          name: 'chat'
          image: '${registryName}.azurecr.io/research-copilot:latest'
          resources: {
            cpu: 2
            memory: '2Gb'
          }
        }
        {
          name: 'admin'
          image: '${registryName}.azurecr.io/research-copilot-main:latest'
          resources: {
            cpu: 2
            memory: '2Gb'
          }
        }
        {
          name: 'api'
          image: '${registryName}.azurecr.io/research-copilot-api:latest'
          resources: {
            cpu: 2
            memory: '2Gb'
          }
          volumeMounts: [
            {
              name: 'fileshare'
              mountPath: mountPath
            }
          ]
        }
      ]
      volumes: [
        {
          name: 'fileshare'
          azureFile: {
            sharename: fileShareName
            storageAccountName: storageAccountName
            storageAccountKey: listKeys(resourceId('Microsoft.Storage/storageAccounts', storageAccountName), '2019-06-01').keys[0].value
          }
        }
      ]
    }
  }
}

output environmentId string = environment.id
