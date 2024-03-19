// Name of the Azure OpenAI service
param name string
// Custom domain name for the Azure OpenAI service
param customDomainName string
// Location of the Azure OpenAI service
param location string
// Tags for the Azure OpenAI service
param tags object
// Deployments for the Azure OpenAI service
param deployments array
// Kind of the Azure OpenAI service
param kind string = 'OpenAI'
// Public network access of the Azure OpenAI service
param publicNetworkAccess string = 'Enabled'
// SKU of the Azure OpenAI service
param sku object 


// Azure OpenAI service
resource account 'Microsoft.CognitiveServices/accounts@2022-03-01' = {
  name: name  
  location: location
  tags: tags
  kind: kind
  properties: {
    customSubDomainName: customDomainName
    publicNetworkAccess: publicNetworkAccess
  }
  sku: sku
}

// Deployments for the Azure OpenAI service
@batchSize(1)
// resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2022-10-01' = [for deployment in deployments: {
//   parent: account
//   name: deployment.name
//   properties: {
//     model: deployment.model
//     raiPolicyName: contains(deployment, 'raiPolicyName') ? deployment.raiPolicyName : null
//     scaleSettings: deployment.scaleSettings
//   }

resource aoaiDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' =  [for deployment in deployments: {
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

output aoaiResourceId string = account.id
output aoaiResourceName string = account.name
