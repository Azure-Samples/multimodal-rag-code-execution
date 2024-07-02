// a Bicep deploment script for az cli
param uniqueid string
param machineLearningName string
param storageName string

param chatAppName string
param mainAppName string
param apiAppName string
param currentTime string = utcNow()

// A user-assigned identity for the script capable of assigning permissions
resource scriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: 'script-identity-${uniqueid}'
  location: resourceGroup().location
}
resource rgOwnerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
  scope: resourceGroup()
}
resource ownerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, scriptIdentity.id, rgOwnerRole.id)
  properties: {
    roleDefinitionId: rgOwnerRole.id
    principalType: 'ServicePrincipal'
    principalId: scriptIdentity.properties.principalId
  }
}

// Ensure the service principal exists and has the necessary permissions
provider microsoftGraph

var spName = 'sp-research-copilot-${uniqueid}'

// This can only work when running locally, Az Portal will NOT have enough permissions
// Retrieve the service principal object ID from the Application ID
// resource appReg 'Microsoft.Graph/applications@v1.0' = {
//   displayName: spName
//   uniqueName: spName
// }

// resource sp 'Microsoft.Graph/servicePrincipals@v1.0' = {
//   displayName: spName
//   appId: appReg.appId
// }

// // Existing Machine Learning workspace
// resource machineLearningWorkspace 'Microsoft.MachineLearningServices/workspaces@2021-04-01' existing = {
//   name: machineLearningName
// }

// // Contributor role definitions
// resource mlContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
//   name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
//   scope: machineLearningWorkspace
// }
// resource rgContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
//   name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
//   scope: resourceGroup()
// }

// // Contributor role on the Machine Learning workspace
// resource mlContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   scope: machineLearningWorkspace
//   name: guid(machineLearningWorkspace.id, mlContributorRoleDefinition.id, spName)
//   properties: {
//     roleDefinitionId: mlContributorRoleDefinition.id
//     principalType: 'ServicePrincipal'
//     principalId: sp.id
//   }
// }
// // Contributor role on the resource group
// resource rgContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   scope: resourceGroup()
//   name: guid(resourceGroup().id, rgContributorRoleDefinition.id, spName)
//   properties: {
//     roleDefinitionId: rgContributorRoleDefinition.id
//     principalType: 'ServicePrincipal'
//     principalId: sp.id
//   }
// }

// Existing storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: storageName
}
resource dataFolderScript 'Microsoft.Resources/deploymentScripts@2019-10-01-preview' = {
  name: 'create-data-folder'
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${scriptIdentity.id}': {}
    }
  }
  location: resourceGroup().location
  properties: {
    azPowerShellVersion: '7.0'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: currentTime // ensures script will run every time
    arguments: '-STORAGE "${storageName}" -CNN_STRING "${storageAccount.listKeys().keys[0].value}"'
    scriptContent: '''
        param(
          $STORAGE,
          $CNN_STRING
        )

        # Create storage context
        $storageContext = New-AzStorageContext -StorageAccountName $STORAGE -StorageAccountKey $CNN_STRING

        # Check if the folder exists on the share in STORAGE with az module
        $folderExists = (Get-AzStorageFile -ShareName $STORAGE -Path "data" -Context $storageContext | Where-Object {$_.GetType().Name -eq "AzureStorageFileDirectory"})

        # If the folder does not exist, create it
        if (-not $folderExists) {
          New-AzStorageDirectory -ShareName $STORAGE -Path "data" -Context $storageContext
        }
      '''
  }
}

resource webAppsFixScript 'Microsoft.Resources/deploymentScripts@2019-10-01-preview' = {
  name: 'fix-webapp-deployment'
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${scriptIdentity.id}': {}
    }
  }
  location: resourceGroup().location
  properties: {
    azCliVersion: '2.61.0'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: currentTime // ensures script will run every time
    arguments: '${chatAppName} ${mainAppName} ${apiAppName} ${resourceGroup().name}'
    scriptContent: '''
        az webapp deployment container config --enable-cd true --name $1 --resource-group $4
        az webapp deployment container config --enable-cd true --name $2 --resource-group $4
        az webapp deployment container config --enable-cd true --name $3 --resource-group $4
      '''
  }
}

// output appId string = appReg.appId
// output appId string = ''
output appName string = spName
#disable-next-line outputs-should-not-contain-secrets
// output password string = '' //spScript.properties.outputs.password
output tenantId string = subscription().tenantId // Assumption
