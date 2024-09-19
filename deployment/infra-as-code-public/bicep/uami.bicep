param uniqueId string
param prefix string
param location string = resourceGroup().location
param storageName string
param mlWorkspaceName string
param acrName string

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing =  {
  name: storageName
}

resource azureMlWorkspace 'Microsoft.MachineLearningServices/workspaces@2021-04-01' existing = {
  name: mlWorkspaceName
}

resource acr 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' existing = {
  name: acrName
}

// Built-in Azure RBAC role that is applied to a Key storage to grant data reader permissions. 
resource blobDataReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  scope: subscription()
}


// Managed Identity for App Service
resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${prefix}-uami-${uniqueId}'
  location: location
}

// Grant the App Service managed identity storage data reader role permissions
resource blobDataReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(resourceGroup().id, uami.name, blobDataReaderRole.id)
  properties: {
    roleDefinitionId: blobDataReaderRole.id
    principalType: 'ServicePrincipal'
    principalId: uami.properties.principalId
  }
}

resource mlContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: azureMlWorkspace 
  name: guid(azureMlWorkspace.id, uami.name, 'mlContributor')
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor role ID
    principalType: 'ServicePrincipal'
    principalId: uami.properties.principalId
  }
}

resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(acr.id, uami.name, 'acrpull')
  scope: acr
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // Role definition ID for AcrPull
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource rgContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup() 
  name: guid(resourceGroup().id, uami.name, 'contributor')
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor role ID
    principalType: 'ServicePrincipal'
    principalId: uami.properties.principalId
  }
}

output uamiId string = uami.id
output uamiClientId string = uami.properties.clientId
