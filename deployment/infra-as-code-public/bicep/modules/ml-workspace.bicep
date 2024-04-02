// Copyright (c) 2021 Microsoft
// 
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT



@description('The name of the container registry to be deployed')
param workspaceName string = 'mlws'

@description('The location in which all resources should be deployed.')
param location string

var varWorkspaceName = workspaceName

param appInsightsId string
param storageId string
param keyVaultId string
param containerRegistryId string

resource machineLearningWorkspace 'Microsoft.MachineLearningServices/workspaces@2020-09-01-preview' = {
  name: varWorkspaceName
  location: location
  sku:{
    name: 'basic'
    tier: 'basic'
  }
  properties:{
    friendlyName: varWorkspaceName
    storageAccount: storageId
    keyVault: keyVaultId
    containerRegistry: containerRegistryId
    applicationInsights: appInsightsId
    hbiWorkspace: true
  }
  identity:{
    type: 'SystemAssigned'
  }
}


output id string = machineLearningWorkspace.id
output name string = machineLearningWorkspace.name
