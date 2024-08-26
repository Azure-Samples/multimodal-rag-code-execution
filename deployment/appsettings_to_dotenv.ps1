# Define the resource group and web app name
param(
    [string] $resourceGroup,
    [string] $envFile = ".env"
)


$webAppName = az webapp list --resource-group $resourceGroup --query "[?contains(name, '-app-api-')].name" -o tsv
Write-Information "Web App Name: $webAppName"

Write-Information "Getting app settings for $webAppName in $resourceGroup"
# Get the app settings
$appSettings = az webapp config appsettings list --name $webAppName --resource-group $resourceGroup | ConvertFrom-Json

Write-Information "Creating $envFile file"
# Create a .env file and write the settings to it
Out-File -FilePath $envFile -InputObject "# Auto-generated .env file"
foreach ($setting in $appSettings) {
    Out-File -FilePath $envFile -Append -InputObject "$($setting.name)=$($setting.value)"
}