# PowerShell version of a script to push Docker images to Azure Container Registry
# Helpful when you just want to add a new tag to an existing image and push it to ACR without all the complexity of a CI/CD pipeline

# define script parameters
param (
    [string]$ACR_NAME = "<your ACR name>",
    [string]$RG = "<your resource group name>",
    [string]$SUBSCRIPTION = "<your subscription id>"
)

# Generating a unique build tag using the current date and time
$BUILD_ID = Get-Date -Format "yyyyMMddHHmmss"
$TAG = "build-$BUILD_ID"

write-host "Logging in to Azure Container Registry $ACR_NAME" -ForegroundColor Green
# Logging in to Azure Container Registry and getting a token
Write-Host "Attempting to log in to Azure Container Registry $ACR_NAME remotely..." -ForegroundColor Green
az acr login --name $ACR_NAME --expose-token
# Write-Host "Token: $TOKEN"

# az account set --subscription=$SUBSCRIPTION
# Logging in to Docker with the ACR token
# docker login $loginserver --username "00000000-0000-0000-0000-000000000000" --password $TOKEN 

# Define paths to your Dockerfiles
$DOCKERFILE_PATH_UI = "docker/dockerfile_chainlit_app"
$DOCKERFILE_PATH_UI_MAIN = "docker/dockerfile_streamlit_app"
$DOCKERFILE_PATH_API = "docker/dockerfile_api"

# Define custom image names with the dynamic tag
$DOCKER_CUSTOM_IMAGE_NAME_UI = "$ACR_NAME.azurecr.io/research-copilot:$TAG"
$DOCKER_CUSTOM_IMAGE_NAME_MAIN = "$ACR_NAME.azurecr.io/research-copilot-main:$TAG"
$DOCKER_CUSTOM_IMAGE_NAME_API = "$ACR_NAME.azurecr.io/research-copilot-api:$TAG"

# Ask for confirmation before building

$confirmation = Read-Host -Prompt "Do you want to proceed with the build of chainlit app? (Y/N)"
if ($confirmation -eq "Y" -or $confirmation -eq "y") {
    Write-Host "Building the chainlit app Docker image using Azure Container Registry with tag $TAG..." -ForegroundColor Green
    az acr build  --registry $ACR_NAME -g $RG --image $DOCKER_CUSTOM_IMAGE_NAME_UI --file $DOCKERFILE_PATH_UI UI
    # Place the build commands here
} else {
    Write-Host "chainlit build cancelled by the user." -ForegroundColor Red
}

$confirmation = Read-Host -Prompt "Do you want to proceed with the build of streamlit? (Y/N)"
if ($confirmation -eq "Y" -or $confirmation -eq "y") {    
    Write-Host "Building the streamlit service Docker image using Azure Container Registry with tag $TAG..." -ForegroundColor Green
    az acr build --registry $ACR_NAME -g $RG --image $DOCKER_CUSTOM_IMAGE_NAME_MAIN --file $DOCKERFILE_PATH_UI_MAIN UI
    # Place the build commands here
} else {
    Write-Host "streamlit build cancelled by the user." -ForegroundColor Red
}

$confirmation = Read-Host -Prompt "Do you want to proceed with the build of API? (Y/N)"
if ($confirmation -eq "Y" -or $confirmation -eq "y") {    
    Write-Host "Building the API service Docker image using Azure Container Registry with tag $TAG..." -ForegroundColor Green
    az acr build --registry $ACR_NAME -g $RG --image $DOCKER_CUSTOM_IMAGE_NAME_API --file $DOCKERFILE_PATH_API code
    # Place the build commands here
} else {
    Write-Host "API build cancelled by the user." -ForegroundColor Red
}


