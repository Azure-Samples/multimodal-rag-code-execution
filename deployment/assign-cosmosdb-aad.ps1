# Variables - replace these with your actual resource names and Azure AD details
param(
    [string] $cosmosDbAccountName,
    [string] $resourceGroupName

)
# Get the current Azure user's object ID
$currentUserObjectId=$(az ad signed-in-user show --query id -o tsv)
$currentUserObjectId="e0937fbb-212a-4609-83dd-ed8ae789e8d5"


# Role definition ID for Cosmos DB Built-in Data Owner (fixed value)
$cosmosDbDataOwnerRoleId="00000000-0000-0000-0000-000000000002"

# Assign the role to the current user for the Cosmos DB account
az cosmosdb sql role assignment create --account-name $cosmosDbAccountName --resource-group $resourceGroupName --scope "/" --principal-id $currentUserObjectId --role-definition-id $cosmosDbDataOwnerRoleId

Write-Information "Assigned Cosmos DB Data Owner role to the current user for $cosmosDbAccountName"