
@description('This is the base name for each Azure resource name (6-12 chars)')
param uniqueid string

param namePrefix string ='dev'

@description('The resource group location')
param location string = resourceGroup().location

// variables
// var storageName = 'st${uniqueid}'
var varcosmosdbName = '${namePrefix}-cosmosdb-research${uniqueid}'
// var storageSkuName = 'Premium_LRS'


@description('Generated from /subscriptions/61901f18-d50c-4d85-90d3-cb4670a440db/resourceGroups/public-research-copilot-rg/providers/Microsoft.DocumentDB/databaseAccounts/adiya-mvp-tt747483')
resource cosmosdb 'Microsoft.DocumentDB/databaseAccounts@2024-02-15-preview' = {
  name: varcosmosdbName
  location: location
  kind: 'GlobalDocumentDB'
  tags: {
    defaultExperience: 'Core (SQL)'
    'hidden-cosmos-mmspecial': ''
  }  
  properties: {
    publicNetworkAccess: 'Enabled'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false    
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
    // EnabledApiTypes: 'Sql'
    disableKeyBasedMetadataWriteAccess: false
    enableFreeTier: false
    enableAnalyticalStorage: false
    analyticalStorageConfiguration: {
      schemaType: 'WellDefined'
    }
    // instanceId: 'ca7f27b6-ec47-461d-bb99-5d24a08999da'
    databaseAccountOfferType: 'Standard'
    enableMaterializedViews: false
    defaultIdentity: 'FirstPartyIdentity'
    networkAclBypass: 'None'
    disableLocalAuth: false
    enablePartitionMerge: false
    enablePerRegionPerPartitionAutoscale: false
    enableBurstCapacity: false
    enablePriorityBasedExecution: false
    // defaultPriorityLevel: 'High'    
    minimalTlsVersion: 'Tls12'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxIntervalInSeconds: 5
      maxStalenessPrefix: 100
    }
    
    locations: [
      {
        // id: 'adiya-mvp-tt747483-swedencentral'
        locationName: 'Sweden Central'
        // documentEndpoint: 'https://adiya-mvp-tt747483-swedencentral.documents.azure.com:443/'
        // provisioningState: 'Succeeded'
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]    
    cors: []
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    ipRules: []
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 8
        backupStorageRedundancy: 'Geo'
      }
    }
    networkAclBypassResourceIds: []
    diagnosticLogSettings: {
      enableFullTextQuery: 'None'
    }
  }
  identity: {
    type: 'None'
  }
}

output cosmosdbName string = cosmosdb.name
output cosmosDbUri string = cosmosdb.properties.documentEndpoint
#disable-next-line outputs-should-not-contain-secrets
output cosmosDbKey string = cosmosdb.listKeys().primaryMasterKey
