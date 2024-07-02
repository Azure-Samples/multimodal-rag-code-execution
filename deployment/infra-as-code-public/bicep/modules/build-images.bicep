param acrName string // Azure Container Registry Name
param gitRepoUrl string = 'https://github.com/Azure-Samples/multimodal-rag-code-execution' // Git Repository URL
param gitRepoBranch string = 'main' // Git Repository Branch
param imageTag string = 'latest' // Docker Image Tag

resource scriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: 'script-identity-build'
  location: resourceGroup().location
}

// Assign the identity to the deployment script Contributor over the resource group and the ACR
resource rgContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  scope: resourceGroup()
}
resource rgContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, rgContributorRoleDefinition.id, scriptIdentity.id)
  properties: {
    roleDefinitionId: rgContributorRoleDefinition.id
    principalType: 'ServicePrincipal'
    principalId: scriptIdentity.properties.principalId
  }
}

resource buildChat 'Microsoft.Resources/deploymentScripts@2019-10-01-preview' = {
  name: 'buildChat'
  location: resourceGroup().location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${scriptIdentity.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.61.0'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: imageTag
    environmentVariables: [
      {
        name: 'ACR_NAME'
        value: acrName
      }
      {
        name: 'GIT_REPO_URL'
        value: gitRepoUrl
      }
      {
        name: 'GIT_REPO_BRANCH'
        value: gitRepoBranch
      }
      {
        name: 'IMAGE_TAG'
        value: imageTag
      }
    ]
    scriptContent: '''
      #!/bin/bash
      
      set -e

      apk add --no-cache git
      
      # Clone the Git repository
      repoDir="$HOME/repo"
      git clone $GIT_REPO_URL $repoDir
      cd $repoDir
      git checkout $GIT_REPO_BRANCH
      
      # Build and push the Docker image to ACR
      az acr build --registry $ACR_NAME --image "research-copilot:${IMAGE_TAG}" --file "docker/dockerfile_chainlit_app" ui >/dev/null
    '''
  }
}
resource buildMain 'Microsoft.Resources/deploymentScripts@2019-10-01-preview' = {
  name: 'buildMain'
  location: resourceGroup().location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${scriptIdentity.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.61.0'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: imageTag
    environmentVariables: [
      {
        name: 'ACR_NAME'
        value: acrName
      }
      {
        name: 'GIT_REPO_URL'
        value: gitRepoUrl
      }
      {
        name: 'GIT_REPO_BRANCH'
        value: gitRepoBranch
      }
      {
        name: 'IMAGE_TAG'
        value: imageTag
      }
    ]
    scriptContent: '''
      #!/bin/bash
      
      set -e

      apk add --no-cache git
      
      # Clone the Git repository
      repoDir="$HOME/repo"
      git clone $GIT_REPO_URL $repoDir
      cd $repoDir
      git checkout $GIT_REPO_BRANCH
      
      # Build and push the Docker image to ACR
      az acr build --registry $ACR_NAME --image "research-copilot-main:${IMAGE_TAG}" --file "docker/dockerfile_streamlit_app" ui >/dev/null
    '''
  }
}
resource buildApi 'Microsoft.Resources/deploymentScripts@2019-10-01-preview' = {
  name: 'buildApi'
  location: resourceGroup().location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${scriptIdentity.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.61.0'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: imageTag
    environmentVariables: [
      {
        name: 'ACR_NAME'
        value: acrName
      }
      {
        name: 'GIT_REPO_URL'
        value: gitRepoUrl
      }
      {
        name: 'GIT_REPO_BRANCH'
        value: gitRepoBranch
      }
      {
        name: 'IMAGE_TAG'
        value: imageTag
      }
    ]
    scriptContent: '''
      #!/bin/bash
      
      set -e

      apk add --no-cache git
      
      # Clone the Git repository
      repoDir="$HOME/repo"
      git clone $GIT_REPO_URL $repoDir
      cd $repoDir
      git checkout $GIT_REPO_BRANCH
      
      # Build and push the Docker image to ACR
      az acr build --registry $ACR_NAME --image "research-copilot-api:${IMAGE_TAG}" --file "docker/dockerfile_api" code >/dev/null
    '''
  }
}
