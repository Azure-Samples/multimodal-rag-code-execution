
@description('This is the base name for each Azure resource name (6-12 chars)')
param uniqueid string
param userAssignedIdentityPrincipalId string

param namePrefix string ='dev'

@description('The resource group location')
param location string = resourceGroup().location

// variables
// var storageName = 'st${uniqueid}'
var varcosmosdbName = '${namePrefix}-cosmosdb-research${uniqueid}'
// var storageSkuName = 'Premium_LRS'



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
    disableLocalAuth: true
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
        locationName: 'Sweden Central'
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


// Assign the User Assigned Identity Contributor role to the Cosmos DB account
resource cosmosDbAccountRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(cosmosdb.id, userAssignedIdentityPrincipalId, 'cosmosDbContributor')
  scope: cosmosdb
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Role definition ID for Contributor
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

var cosmosDataContributor = '00000000-0000-0000-0000-000000000002'
resource sqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-04-15' = {
  name: guid(cosmosDataContributor, userAssignedIdentityPrincipalId, cosmosdb.id)
  parent: cosmosdb
}

output cosmosdbName string = cosmosdb.name
output cosmosDbUri string = cosmosdb.properties.documentEndpoint
#disable-next-line outputs-should-not-contain-secrets
output cosmosDbKey string = cosmosdb.listKeys().primaryMasterKey
