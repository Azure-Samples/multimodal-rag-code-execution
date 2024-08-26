// Name of the current environment
param envName string
// Custom domain name for the OpenAI service
// param openAiCustomDomain string
// SKU name for the OpenAI service
param openAiSkuName string = 'S0'

param namePrefix string

@description('The location in which all resources should be deployed.')
param location string

@description('An existing Azure OpenAI resource')
param openAIName string

@description('An existing Azure OpenAI resource group')
param openAIRGName string


param aoaiGpt4ModelName string= 'gpt-4o'
param aoaiGpt4ModelVersion string = '2024-05-13'
param aoaiGpt4ModelDeploymentName string = 'gpt-4o'

param aoaiEmbedingsName string = 'text-embedding-3-large'
param aoaiEmbedingsVersion string  = '1'
param aoaiEmbedingsDeploymentName string = 'text-embedding-3-large'

// Array of deployments, currently just one deployment will be used
param deployments array = [
  {
    name: aoaiGpt4ModelName
    model: {
      format: 'OpenAI'
      name: aoaiGpt4ModelDeploymentName
      version: aoaiGpt4ModelVersion
      capacity: 10
      contentFilter: 'Default'
    }
    sku: {
      name: 'Standard'
      capacity: 30
  }
  }
    {
      name: aoaiEmbedingsName
      model: {
        format: 'OpenAI'
        name: aoaiEmbedingsDeploymentName
        version: aoaiEmbedingsVersion
        capacity: 10
        contentFilter: 'Default'
      }
      sku: {
        name: 'Standard'
        capacity: 120
    }
  }
]

// Tags for the resource group
var tags = {
  Creator: 'ServiceAccount'
  Service: 'OpenAI'
  Environment: envName
}

var aoaiResourceName = empty(openAIName) ? '${namePrefix}-aoai-${uniqueString(resourceGroup().id)}' : openAIName
var varAoaiCustomDomain = aoaiResourceName

// Azure OpenAI service
resource account 'Microsoft.CognitiveServices/accounts@2022-03-01' = if (empty(openAIName)) {
  name: varAoaiCustomDomain  
  location: location
  tags: tags
  kind: 'OpenAI'
  properties: {
    customSubDomainName: varAoaiCustomDomain
    publicNetworkAccess: 'Enabled'
  }
  sku: {
    name: openAiSkuName
  }
}

@batchSize(1)
resource aoaiDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' = [for deployment in deployments: if (empty(openAIName)) {
    name: deployment.name
    parent: account
    sku: {
      name: 'Standard'
      capacity: 10
    }
    properties: {
      model: {
        format: 'OpenAI'
        name: deployment.model.name
        version: deployment.model.version
      }
      versionUpgradeOption: 'OnceCurrentVersionExpired'
      currentCapacity: deployment.model.capacity
      raiPolicyName: 'Microsoft.Default'
    }
  }
]

resource openAI 'Microsoft.CognitiveServices/accounts@2022-03-01' existing = if (!empty(openAIName) && !empty(openAIRGName)) {
  name: aoaiResourceName
  scope: resourceGroup(openAIRGName)
}

// Get the OpenAI resource name and key depending on whether the resource was created or already existed
var oaiName = !empty(openAIName) ? openAI.name : account.name
var oaiKey = !empty(openAIName) ? openAI.listKeys().key1 : account.listKeys().key1

output aoaiResourceName string = oaiName
#disable-next-line outputs-should-not-contain-secrets
output aoaiResourceKey string = oaiKey
