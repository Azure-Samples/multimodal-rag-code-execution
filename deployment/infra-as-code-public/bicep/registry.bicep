@description('A prefix that will be prepended to resource names')
param namePrefix string = 'dev'

@description('The name of the Azure Container Registry')
param containerRegistry string = 'acr'

@description('A unique identifier that will be appended to resource names')
param uniqueid string

@description('The location in which all resources should be deployed.')
param location string

// existing resource name params 
var varcontainerRegistry = '${namePrefix}${containerRegistry}${uniqueid}'

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
    // tier: 'Standard'
  }
}


output containerRegistryName string = containerRegistry_resource.name
#disable-next-line outputs-should-not-contain-secrets
output containerRegistryPassword string = containerRegistry_resource.listCredentials().passwords[0].value
