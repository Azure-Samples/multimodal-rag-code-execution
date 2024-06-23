#!/bin/bash

# Parameters
appId="$1"
apiWebAppName="$2"
resourceGroup="$3"

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
az webapp config appsettings set --name $apiWebAppName --resource-group $resourceGroup --settings AML_PASSWORD=$newSecret

if [ $? -eq 0 ]; then
    echo "Successfully set AML_PASSWORD for the Azure Web App $apiWebAppName"
else
    echo "Failed to set AML_PASSWORD for the Azure Web App $apiWebAppName"
    exit 1
fi

# Step 3: Restart the web app
az webapp restart --name $apiWebAppName --resource-group $resourceGroup

echo "Web app $apiWebAppName restarted successfully"