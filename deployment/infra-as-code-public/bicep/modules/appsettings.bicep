param targetWebAppName string
param allSettings object

resource apiWebApp 'Microsoft.Web/sites@2022-09-01' existing = {
  name: targetWebAppName
}
resource apiAppSettings 'Microsoft.Web/sites/config@2022-09-01' = {
  name: 'appsettings'
  parent: apiWebApp
  properties: allSettings
}
