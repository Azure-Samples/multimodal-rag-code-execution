// Copyright (c) 2021 Microsoft
// 
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

@description('The name of the Application Insights Workspace')
param applicationInsightsName string = 'ai-aml-${uniqueString(resourceGroup().name)}'

@description('Tags to apply to the Application Insights workspace')
param tags object = {}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: applicationInsightsName
  location: resourceGroup().location
  kind: 'web'
  properties:{
    Application_Type: 'web'
  }
  tags: tags
}

output appInsightsId string = applicationInsights.id
