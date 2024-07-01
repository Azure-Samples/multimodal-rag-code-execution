#!/bin/bash

# Parameters
appName="$1"
apiWebAppName="$2"
workspaceName="$3"
resourceGroup="$4"

# Check Principal exists
appId=$(az ad sp list --display-name "$appName" --query "[].appId" --output tsv)
if [ -z "$appId" ]; then
    # Create it manually
    spInfo=$(az ad sp create-for-rbac --name "$appName")
    appId=$(echo "$spInfo" | jq -r '.appId')
        
    echo "Azure AD Application created with ID: $appId"
else
    spInfo=$(az ad sp show --id "$appId")
    appId=$(echo "$spInfo" | jq -r '.appId')

    echo "Resuing existing Azure AD Application with ID: $appId"
fi

# Get current subscription ID and tenant
context=$(az account show)
subscriptionId=$(echo "$context" | jq -r '.id')
tenantId=$(echo $context | jq -r .tenantId)

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

# Step 2: Set the new secret as an app setting (AML_PASSWORD) for the Azure Web App
# Note: This command directly sets the new app setting without needing to manually handle existing settings
az webapp config appsettings set --name $apiWebAppName --resource-group $resourceGroup --settings AML_PASSWORD=$newSecret AML_SERVICE_PRINCIPAL_ID=$appId AML_TENANT_ID=$tenantId

if [ $? -eq 0 ]; then
    echo "Successfully set AML_SERVICE_PRINCIPAL_ID, AML_PASSWORD for the Azure Web App $apiWebAppName"
else
    echo "Failed to set AML_SERVICE_PRINCIPAL_ID, AML_PASSWORD for the Azure Web App $apiWebAppName"
    exit 1
fi

# Step 3: Restart the web app
az webapp restart --name $apiWebAppName --resource-group $resourceGroup

echo "Web app $apiWebAppName restarted successfully"