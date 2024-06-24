# PowerShell version of a script to push Docker images to Azure Container Registry
# Helpful when you just want to add a new tag to an existing image and push it to ACR without all the complexity of a CI/CD pipeline

param (
    [string]$RG,
    [string]$ACR_NAME
)

# Ensure current working directory is parent of "deployment" folder
$deploymentPath = (Get-Location).Path
if ($deploymentPath -contains "deployment") {
    Write-Host "Please run this script from the parent directory of the 'deployment' folder" -ForegroundColor Red
    exit
}

# Generating a unique build tag using the current date and time
$BUILD_ID = Get-Date -Format "yyyyMMddHHmmss"
$TAG = "build-$BUILD_ID"

# If $ACR_NAME is not provided, query the resource group for the ACR name not containing 'ml'
if (-not $ACR_NAME) {
    $ACR_NAME = az acr list --resource-group $RG --query "[? !contains(name, 'ml')].name" -o tsv
}

write-host "Using Azure Container Registry: $ACR_NAME"

# Define paths to your Dockerfiles
$DOCKERFILE_PATH_UI = "docker/dockerfile_chainlit_app"
$DOCKERFILE_PATH_UI_MAIN = "docker/dockerfile_streamlit_app"
$DOCKERFILE_PATH_API = "docker/dockerfile_api"

# Define custom image names with the dynamic tag
$DOCKER_CUSTOM_IMAGE_NAME_UI = "$ACR_NAME.azurecr.io/research-copilot"
$DOCKER_CUSTOM_IMAGE_NAME_MAIN = "$ACR_NAME.azurecr.io/research-copilot-main"
$DOCKER_CUSTOM_IMAGE_NAME_API = "$ACR_NAME.azurecr.io/research-copilot-api"

# Function to deploy web app
function DeployWebApp($webAppName, $dockerImageName, $dockerFile, $sourceFolder, $tag) {

    $confirmation = Read-Host -Prompt "Do you want to proceed with the build of $webAppName ? (Y/N)"
    if ($confirmation -eq "Y" -or $confirmation -eq "y") {
        $acrPassword = az acr credential show --name $ACR_NAME --resource-group $RG --query "passwords[0].value" -o tsv
        Write-Host "Building the $webAppName Docker image using Azure Container Registry with tag $tag..." -ForegroundColor Green
        az acr build --registry $ACR_NAME `
            --resource-group $RG `
            --image ${dockerImageName}:$tag `
            --file $dockerFile $sourceFolder

        Write-Host "Setting new Docker image for $webAppName ..." -ForegroundColor Green
        az webapp config container set --name $webAppName `
            --container-image-name "${dockerImageName}:$tag" `
            --resource-group $RG `
            --container-registry-url "https://$ACR_NAME.azurecr.io" `
            --container-registry-user $ACR_NAME `
            --container-registry-password $acrPassword

        Write-Host "$dockerImageName build completed and deployed to Azure Web App $webAppName" -ForegroundColor Green
    } else {
        Write-Host "$dockerImageName build skipped by the user." -ForegroundColor Yellow
    }
}

Write-Host "Fetching web app names from resource group $RG..."
# Get all the web app names from resource group
$webAppNames = az webapp list --resource-group $RG --query "[?contains(name, '-app-')].name" -o tsv
$CHAT_WEB_APP_NAME = $webAppNames | Where-Object { $_ -like '*-app-chat-*' }
$MAIN_WEB_APP_NAME = $webAppNames | Where-Object { $_ -like '*-app-main-*' }
$API_WEB_APP_NAME = $webAppNames | Where-Object { $_ -like '*-app-api-*' }

Write-Host "Web app names are: $CHAT_WEB_APP_NAME, $MAIN_WEB_APP_NAME, $API_WEB_APP_NAME"
# Deploy web apps using the function
DeployWebApp $CHAT_WEB_APP_NAME $DOCKER_CUSTOM_IMAGE_NAME_UI $DOCKERFILE_PATH_UI "ui" $TAG
DeployWebApp $MAIN_WEB_APP_NAME $DOCKER_CUSTOM_IMAGE_NAME_MAIN $DOCKERFILE_PATH_UI_MAIN "ui" $TAG
DeployWebApp $API_WEB_APP_NAME $DOCKER_CUSTOM_IMAGE_NAME_API $DOCKERFILE_PATH_API "code" $TAG
