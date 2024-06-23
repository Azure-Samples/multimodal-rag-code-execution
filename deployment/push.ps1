# PowerShell version of a script to push Docker images to Azure Container Registry
# Helpful when you just want to add a new tag to an existing image and push it to ACR without all the complexity of a CI/CD pipeline

param (
    [string]$RG,
    [string]$ACR_NAME
)

# Generating a unique build tag using the current date and time
$BUILD_ID = Get-Date -Format "yyyyMMddHHmmss"
$TAG = "build-$BUILD_ID"

# If $ACR_NAME is not provived, query the resource group for the ACR name not containing 'ml'
if (-not $ACR_NAME) {
    $ACR_NAME = az acr list --resource-group $RG --query "[? !contains(name, 'ml')].name" -o tsv
}

write-host "Logging in to Azure Container Registry $ACR_NAME" -ForegroundColor Green
# Logging in to Azure Container Registry and getting a token
Write-Host "Attempting to log in to Azure Container Registry $ACR_NAME remotely..." -ForegroundColor Green
az acr login --name $ACR_NAME --expose-token

# Define paths to your Dockerfiles
$DOCKERFILE_PATH_UI = "docker/dockerfile_chainlit_app"
$DOCKERFILE_PATH_UI_MAIN = "docker/dockerfile_streamlit_app"
$DOCKERFILE_PATH_API = "docker/dockerfile_api"

# Define custom image names with the dynamic tag
$DOCKER_CUSTOM_IMAGE_NAME_UI = "$ACR_NAME.azurecr.io/research-copilot"
$DOCKER_CUSTOM_IMAGE_NAME_MAIN = "$ACR_NAME.azurecr.io/research-copilot-main"
$DOCKER_CUSTOM_IMAGE_NAME_API = "$ACR_NAME.azurecr.io/research-copilot-api"

# Get all the web app names from resource group
$CHAT_WEB_APP_NAME = az webapp list --resource-group $RG --query "[?contains(name, '-app-chat-')].name" -o tsv
$MAIN_WEB_APP_NAME = az webapp list --resource-group $RG --query "[?contains(name, '-app-main-')].name" -o tsv
$API_WEB_APP_NAME = az webapp list --resource-group $RG --query "[?contains(name, '-app-api-')].name" -o tsv

# Ask for confirmation before building

$confirmation = Read-Host -Prompt "Do you want to proceed with the build of chainlit app? (Y/N)"
if ($confirmation -eq "Y" -or $confirmation -eq "y") {
    Write-Host "Building the chainlit app Docker image using Azure Container Registry with tag $TAG..." -ForegroundColor Green
    az acr build  --registry $ACR_NAME -g $RG --image ${DOCKER_CUSTOM_IMAGE_NAME_UI}:$TAG --image ${DOCKER_CUSTOM_IMAGE_NAME_UI}:latest --file $DOCKERFILE_PATH_UI ui
    az webapp config container set --name $CHAT_WEB_APP_NAME --resource-group $RG --container-image-name ${DOCKER_CUSTOM_IMAGE_NAME_UI}:$TAG
} else {
    Write-Host "chainlit build cancelled by the user." -ForegroundColor Red
}

$confirmation = Read-Host -Prompt "Do you want to proceed with the build of streamlit? (Y/N)"
if ($confirmation -eq "Y" -or $confirmation -eq "y") {    
    Write-Host "Building the streamlit service Docker image using Azure Container Registry with tag $TAG..." -ForegroundColor Green
    az acr build --registry $ACR_NAME -g $RG --image ${DOCKER_CUSTOM_IMAGE_NAME_MAIN}:$TAG --image ${DOCKER_CUSTOM_IMAGE_NAME_MAIN}:latest --file $DOCKERFILE_PATH_UI_MAIN ui
    az webapp config container set --name $MAIN_WEB_APP_NAME --resource-group $RG --container-image-name ${DOCKER_CUSTOM_IMAGE_NAME_MAIN}:$TAG
} else {
    Write-Host "streamlit build cancelled by the user." -ForegroundColor Red
}

$confirmation = Read-Host -Prompt "Do you want to proceed with the build of API? (Y/N)"
if ($confirmation -eq "Y" -or $confirmation -eq "y") {    
    Write-Host "Building the API service Docker image using Azure Container Registry with tag $TAG..." -ForegroundColor Green
    az acr build --registry $ACR_NAME -g $RG --image ${DOCKER_CUSTOM_IMAGE_NAME_API}:$TAG --image ${DOCKER_CUSTOM_IMAGE_NAME_API}:latest --file $DOCKERFILE_PATH_API code
    az webapp config container set --name $API_WEB_APP_NAME --resource-group $RG --container-image-name ${DOCKER_CUSTOM_IMAGE_NAME_API}:$TAG
} else {
    Write-Host "API build cancelled by the user." -ForegroundColor Red
}
