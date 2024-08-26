#!/bin/bash

# Parameters
spName="$1"
resourceGroup="$2"

# Check Principal exists
appId=$(az ad sp list --display-name "$spName" --query "[].appId" --output tsv)
if [ -z "$appId" ]; then
    # Create it manually
    spInfo=$(az ad sp create-for-rbac --name "$spName")
    appId=$(echo "$spInfo" | jq -r '.appId')
        
    echo "Azure AD Application created with ID: $appId"
else
    spInfo=$(az ad sp show --id "$appId")
    appId=$(echo "$spInfo" | jq -r '.appId')

    echo "Reusing existing Azure AD Application with ID: $appId"
fi

# Get current subscription ID and tenant
context=$(az account show)
subscriptionId=$(echo "$context" | jq -r '.id')
tenantId=$(echo $context | jq -r .tenantId)

# Get the workspace name
workspaceName=$(az deployment group show --resource-group $resourceGroup --name "ml-workspace-deployment" --query properties.outputs.name.value -o tsv)

# Assign Contributor role to the resource group
az role assignment create --assignee "$appId" --role "Contributor" --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup"
# Assign Contributor role to the machine learning workspace
az role assignment create --assignee "$appId" --role "Contributor" --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.MachineLearningServices/workspaces/$workspaceName"

# Step 1: Create a new secret for the Azure AD application
newSecret=$(az ad app credential reset --id $appId --append --query password -o tsv)

# Check if the secret creation was successful
if [ -z "$newSecret" ]; then
    echo "Failed to create a new secret for Azure AD Application with ID $appId"
    exit 1
else
    echo "Successfully created a new secret for Azure AD Application with ID $appId"
fi

echo "Copy the following values to be set in .env file:\n"
echo "AML_PASSWORD=$newSecret\nAML_SERVICE_PRINCIPAL_ID=$appId\nAML_TENANT_ID=$tenantId"