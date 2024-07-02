# Define your resource group and web app name
param (
    [string]$resourceGroupName,
    [string]$webAppName
)

# Read .env file
$envVars = Get-Content .env | ForEach-Object {
    if (-not $_.StartsWith("#") -and $_.Trim() -ne "") {
        $key, $value = $_ -split '=', 2
        @{ $key = $value }
    }
}

# Set app settings
$fullValues = ""
foreach ($envVar in $envVars) {
    $key = $envVar.Keys
    $value = $envVar.Values
    if ($value.Trim() -ne "") {
        Write-Host "Setting $key=$value"
        az webapp config appsettings set --name $webAppName --resource-group $resourceGroupName --settings "$key=$value"
        $fullValues = "$fullValues $key=$value"
    }
}

# Write-Host "Setting app settings $fullValues"
# az webapp config appsettings set --name $webAppName --resource-group $resourceGroupName --settings "$fullValues"