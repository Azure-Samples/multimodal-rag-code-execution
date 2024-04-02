@description('A prefix that will be prepended to resource names')
param namePrefix string = 'dev'

@description('The name of the Vision resource')
param accountsVisionResTstName string = 'vision'

@description('A unique identifier that will be appended to resource names')
param uniqueid string

@description('The location in which all resources should be deployed.')
param location string

var varaccountsVisionResTstName = '${namePrefix}${accountsVisionResTstName}${uniqueid}'






resource cognitiveServicesAccount 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: varaccountsVisionResTstName
  location: location
  sku: {
    name: 'S1'
  }
  kind: 'ComputerVision'
  identity: {
    type: 'None'
  }
  properties: {
    customSubDomainName: varaccountsVisionResTstName
    restore: false
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    publicNetworkAccess: 'Disabled'
  }
}

// output containerRegistryName string = containerRegistry_resource.name
output accountsVisionResTstName string = cognitiveServicesAccount.name
