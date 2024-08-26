
@description('A prefix that will be prepended to resource names')
param namePrefix string = 'dev'

@description('The name of the container registry to be deployed')
param containerRegistryName string = ''

@description('A unique identifier that will be appended to resource names')
param uniqueid string

@description('The location in which all resources should be deployed.')
param location string = resourceGroup().location

var varcontainerRegistry = '${namePrefix}${containerRegistryName}${uniqueid}'

resource containerRegistry_resource 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  location: location
  name: varcontainerRegistry
  properties: {
    adminUserEnabled: true
    anonymousPullEnabled: false
    dataEndpointEnabled: false
    encryption: {
      status: 'disabled'
    }
    metadataSearch: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
    policies: {
      azureADAuthenticationAsArmPolicy: {
        status: 'enabled'
      }
      exportPolicy: {
        status: 'enabled'
      }
      quarantinePolicy: {
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'disabled'
      }
      softDeletePolicy: {
        retentionDays: 7
        status: 'disabled'
      }
      trustPolicy: {
        status: 'disabled'
        type: 'Notary'
      }
    }
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
  }
  sku: {
    name: 'Premium'
  }
}


output acrId string = containerRegistry_resource.id
