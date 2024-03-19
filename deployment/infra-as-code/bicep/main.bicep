var DeployThis = true //just used for development reasons locally here so that I can test individual modules without deploying everything
// we get the current pincilal id so that we can assign the keyvault administrator role to the current user
param userPrincipalId string =''

@description('Base name of the virtual jumbox server')
param vmName string = 'jumpbox'

@description ('Deploy a jumpbox VM to the network, by default it will be installed')
param deployJumpBox bool = true

@description ('Deploy a DDOS to the network, by default it will NOT be installed')
param enableDdosProtection bool = false

@description('The name of the username to lof to the jumbox')
param vmAdminUsername string = 'azureuser'

@description('The password for accesing the jumpbox server')
@secure()
param vmUserPassword string

@description('The region for the Azure AI Search service')
param aiSearchRegion string ='eastus'

@description('The location in which all resources should be deployed.')
param location string = resourceGroup().location

@description('A prefix that will be prepended to resource names')
param namePrefix string = 'dev'

@description('The address prefix for the Virtual Network')
param vnetAddressPrefix string ='10.0.0.0/16'

@description('The address prefix for the Application Gateway subnet')
param appGatewaySubnetPrefix string ='10.0.1.0/24'

@description('The address prefix for the App Services subnet')
param appServicesSubnetPrefix string ='10.0.0.0/24'

@description('The address prefix for the Private Endpoints subnet')
param privateEndpointsSubnetPrefix string ='10.0.2.0/27'

@description('The address prefix for the Agents subnet')
param agentsSubnetPrefix string ='10.0.2.32/27'

@description('The address prefix for the Azure Bastion subnet')
param bastionSubnetPrefix string = '10.0.3.0/26'

@description('Domain name to use for App Gateway')
param customDomainName string = 'contoso.com'

@description('The certificate data for app gateway TLS termination. The value is base64 encoded')
@secure()
param appGatewayListenerCertificate string
var uniqueid = uniqueString(resourceGroup().id)

// @description('Controls whether to deploy resources across availability zones')
// param deployAvailabilityZones bool = false

// ---- Availability Zones ----
var availabilityZones = [ '1', '2', '3' ]
var logWorkspaceName = 'log-${uniqueid}'


// ---- Log Analytics workspace ----
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = if (DeployThis) {
  name: logWorkspaceName
  location: location  
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

module vmModule 'virtualmachine.bicep' = if (deployJumpBox) {
  name: 'vmDeploy'
  params: {
    location: location
    uniqueid: uniqueid
    namePrefix: namePrefix
    vnetName: networkModule.outputs.vnetNName
    bastionSubnet: networkModule.outputs.bastionSubnetName
    vmSubnet: networkModule.outputs.agentsSubnetName
    keyVaultName: secretsModule.outputs.keyVaultName
    adminUserName: vmAdminUsername
    adminUserPassword: vmUserPassword    
    vmName: vmName     
  }
}

// Deploy vnet with subnets and NSGs
module networkModule 'network.bicep' = {
  name: 'networkDeploy'
  params: {
    location: location
    uniqueid: uniqueid    
    namePrefix:namePrefix
    vnetAddressPrefix:vnetAddressPrefix
    appGatewaySubnetPrefix:appGatewaySubnetPrefix
    appServicesSubnetPrefix:appServicesSubnetPrefix
    privateEndpointsSubnetPrefix:privateEndpointsSubnetPrefix
    agentsSubnetPrefix:agentsSubnetPrefix    
    enableDdosProtection: enableDdosProtection
    bastionSubnetPrefix: bastionSubnetPrefix
  }
}

// Deploy storage account with private endpoint and private DNS zone
module storageModule 'storage.bicep' = if (DeployThis) {
  name: 'storageDeploy'
  params: {
    location: location
    uniqueid: uniqueid
    vnetName: networkModule.outputs.vnetNName
    privateEndpointsSubnetName: networkModule.outputs.privateEndpointsSubnetName    
  }
}


// Deploy a Key Vault with a private endpoint and DNS zone
module secretsModule 'secrets.bicep' = {
  name: 'secretsDeploy'
  params: {
    location: location
    uniqueid: uniqueid
    vnetName: networkModule.outputs.vnetNName
    privateEndpointsSubnetName: networkModule.outputs.privateEndpointsSubnetName
    appGatewayListenerCertificate: appGatewayListenerCertificate      
    vmAdminUsername: vmAdminUsername
    vmUserPassword: vmUserPassword    
  }
}

// Deploy a web app
module webappModule 'webapp.bicep' = if (DeployThis) {
  name: 'webappDeploy'
  params: {
    location: location
    uniqueid: uniqueid        
    keyVaultName: secretsModule.outputs.keyVaultName
    storageName: storageModule.outputs.storageName
    vnetName: networkModule.outputs.vnetNName
    appServicesSubnetName: networkModule.outputs.appServicesSubnetName
    privateEndpointsSubnetName: networkModule.outputs.privateEndpointsSubnetName
    logWorkspaceName: logWorkspace.name
    containerRegistry: registry.outputs.containerRegistryName
    storageAccount:storageModule.outputs.storageName  
    namePrefix:namePrefix
   }
}

//Deploy an Azure Application Gateway with WAF v2 and a custom domain name.
module gatewayModule 'gateway.bicep' = if (DeployThis) {
  name: 'gatewayDeploy'
  params: {
    location: location
    uniqueid: uniqueid
    namePrefix:namePrefix    
    availabilityZones: availabilityZones
    customDomainName: customDomainName
    appName: webappModule.outputs.appName
    vnetName: networkModule.outputs.vnetNName
    appGatewaySubnetName: networkModule.outputs.appGatewaySubnetName
    keyVaultName: secretsModule.outputs.keyVaultName
    gatewayCertSecretUri: secretsModule.outputs.gatewayCertSecretUri
    logWorkspaceName: logWorkspace.name
   }
}

module registry 'registry.bicep' = if (DeployThis) {
  name: 'containerRegistryModule'
  params: {
    namePrefix:namePrefix
    containerRegistry: 'acr'
    uniqueid:  uniqueid
    location: location
    vnetName: networkModule.outputs.vnetNName
    privateEndpointsSubnetName: networkModule.outputs.privateEndpointsSubnetName    
  }
}


module accountsVisionResTstName 'vision.bicep' = if (DeployThis) {
  name: 'accountsVisionResTstName'
  params: {
    uniqueid: uniqueid
    location: location       
    namePrefix:namePrefix 
    vnetName: networkModule.outputs.vnetNName
    privateEndpointsSubnetName: networkModule.outputs.privateEndpointsSubnetName
  }
}

module ai_search 'ai_search.bicep' = if (DeployThis) {
  name: 'ai_search'
  params: {
    uniqueid: uniqueid
    aiSearchRegion: aiSearchRegion
    location: location
    namePrefix:namePrefix        
    vnetName: networkModule.outputs.vnetNName
    privateEndpointsSubnetName: networkModule.outputs.privateEndpointsSubnetName
  }
}

//keyvault administrator role:
resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '00482a5a-887f-4fb3-b363-3b7fe8e74483' 
  scope: subscription()
}
// to add the current user to the keyvault administrator role
module currentUserRoleAssignmentModule './modules/keyvaultRoleAssignment.bicep' = {
  name: 'currentUserRoleAssignmentModule'
  params: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: userPrincipalId
    keyVaultName: secretsModule.outputs.keyVaultName
    principalType: 'User'
  }
}


output webAppName string = webappModule.outputs.appName
output appServiceName string = webappModule.outputs.appServicePlanName
output containerRegistry string = registry.outputs.containerRegistryName
output uniqueId string = uniqueid
output storageAccount string = storageModule.outputs.storageName
output aiSearch string =  ai_search.outputs.aiSearchName 
output accountsVisionResTstName string = accountsVisionResTstName.outputs.accountsVisionResTstName
output keyvaultname string = secretsModule.outputs.keyVaultName
output vmAdminUserName string = vmModule.outputs.vmAdminUserName
output vmName string = vmModule.outputs.vmName
output vnetName string = networkModule.outputs.vnetNName
output privateEndpointsSubnetName string = networkModule.outputs.privateEndpointsSubnetName
output privateEndpointsSubnetId string = networkModule.outputs.privateEndpointsSubnetId
output vmUserPassword string = vmModule.outputs.vmUserPassword
