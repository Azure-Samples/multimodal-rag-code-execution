# Define the resource group and web app name
param(
    [string] $resourceGroup,
    [string] $webAppName,
    [string] $envFile = ".env"
)

# Get the app settings
$appSettings = az webapp config appsettings list --name $webAppName --resource-group $resourceGroup | ConvertFrom-Json

# Create a .env file and write the settings to it
Out-File -FilePath $envFile -InputObject "# Auto-generated .env file"
foreach ($setting in $appSettings) {
    Out-File -FilePath $envFile -Append -InputObject "$($setting.name)=$($setting.value)"
}