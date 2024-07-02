@description('A prefix that will be prepended to resource names')
param namePrefix string = 'dev'

@description('The name of the Azure Container Registry')
param documentIntelligence string = 'di'

@description('A unique identifier that will be appended to resource names')
param uniqueid string


// TODO Agustin
// Public preview version 2024-02-29-preview is currently only available in the following Azure regions:
// East US
// West US2
// West Europe

@description('The location in which all resources should be deployed.')
param location string = 'eastus'


// existing resource name params 
var vardocumentIntelligence = '${namePrefix}${documentIntelligence}${uniqueid}'

resource devresearchdocumentintelligence 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: vardocumentIntelligence
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'FormRecognizer'
  tags: {}
  properties: {    
    customSubDomainName: vardocumentIntelligence
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }    
    publicNetworkAccess: 'Enabled'        
  }
  identity: {
    type: 'None'
  }  
}

output documentIntelligenceName string = devresearchdocumentintelligence.name
output documentIntelligenceId string = devresearchdocumentintelligence.id
output documentIntelligenceEndpoint string = devresearchdocumentintelligence.properties.endpoint
#disable-next-line outputs-should-not-contain-secrets
output documentIntelligenceKey string = devresearchdocumentintelligence.listKeys().key1
