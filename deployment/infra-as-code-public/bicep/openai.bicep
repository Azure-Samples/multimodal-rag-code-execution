// Name of the current environment
param envName string
// Custom domain name for the OpenAI service
// param openAiCustomDomain string
// SKU name for the OpenAI service
param openAiSkuName string = 'S0'


param aoaiGpt4ModelName string= 'gpt-4o'
param aoaiGpt4ModelVersion string = '2024-05-01-preview'
param aoaiGpt4ModelDeploymentName string = 'gpt-4o'

param aoaiEmbedingsName string = 'text-embedding-3-large'
param aoaiEmbedingsVersion string  = '1'
param aoaiEmbedingsDeploymentName string = 'text-embedding-3-large'

param aoaiGpt4VisionName string = 'gpt-4o'
param aoaiGpt4VisionVersion string = '2024-05-01-preview'
param aoaiGpt4VisionDeploymentName string = 'gpt-4o'


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
  // {
  //   name: aoaiGpt4VisionName
  //   model: {
  //     format: 'OpenAI'
  //     name: aoaiGpt4VisionDeploymentName
  //     version: aoaiGpt4VisionVersion
  //     capacity: 10
  //     contentFilter: 'Default'
  //   }
  //   sku: {
  //     name: 'Standard'
  //     capacity: 30
  // }
  // }
]
// Tags for the resource group
param tags object = {
  Creator: 'ServiceAccount'
  Service: 'OpenAI'
  Environment: envName
}

@description('The name of the Aopenaut AI (AOAI) resource.')
param aoaiResourceName string = 'aoai'



@description('The location in which all resources should be deployed.')
param location string


var varAoaiCustomDomain = aoaiResourceName




// Create the OpenAI service by using a separate file
module openAi './modules/openai.resources.bicep' = {
  name: 'openai-${location}'
  params: {
    name: aoaiResourceName
    customDomainName: varAoaiCustomDomain
    location: location
    tags: tags
    sku: {
      name: openAiSkuName
    }
    deployments: deployments
  }
}



output aoaiResourceId string = openAi.outputs.aoaiResourceId
output aoaiResourceName string = openAi.outputs.aoaiResourceName
output aoaiResourceKey string = openAi.outputs.aoaiResourceKey
