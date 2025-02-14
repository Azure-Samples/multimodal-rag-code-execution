// a Bicep deploment script for az cli
param uniqueid string
param storageName string

param currentTime string = utcNow()

// A user-assigned identity for the script capable of assigning permissions
resource scriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: 'script-identity-${uniqueid}'
  location: resourceGroup().location
}

// Existing storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: storageName
}

resource scriptRoleAssignment1 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, scriptIdentity.id, 'storageaccountcontributor')
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab')
    principalType: 'ServicePrincipal'
    principalId: scriptIdentity.properties.principalId
  }
}
resource scriptRoleAssignment2 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, scriptIdentity.id, 'fileshareswrite')
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb')
    principalType: 'ServicePrincipal'
    principalId: scriptIdentity.properties.principalId
  }
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

