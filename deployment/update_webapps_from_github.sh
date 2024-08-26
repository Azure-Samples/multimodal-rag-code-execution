#!/bin/bash

# Input parameter: Resource Group name
RG=$1

# Ensure the resource group name is provided
if [ -z "$RG" ]; then
    echo "Resource Group name is required as an argument."
    exit 1
fi

# Get the Azure Container Registry name, excluding any with 'ml' in the name
ACR_NAME=$(az acr list --resource-group $RG --query "[? !contains(name, 'ml')].name" -o tsv)

if [ -z "$ACR_NAME" ]; then
    echo "No suitable Azure Container Registry found in the Resource Group $RG."
    exit 1
fi

echo "Using Azure Container Registry: $ACR_NAME"

# Clone the repository containing Dockerfiles
git clone https://github.com/Azure-Samples/multimodal-rag-code-execution repo
cd repo

# Define paths to your Dockerfiles
DOCKERFILE_PATH_UI="docker/dockerfile_chainlit_app"
DOCKERFILE_PATH_UI_MAIN="docker/dockerfile_streamlit_app"
DOCKERFILE_PATH_API="docker/dockerfile_api"

# Define custom image names with the dynamic tag
BUILD_ID=$(date +%Y%m%d%H%M%S)
TAG="build-$BUILD_ID"
DOCKER_CUSTOM_IMAGE_NAME_UI="$ACR_NAME.azurecr.io/research-copilot"
DOCKER_CUSTOM_IMAGE_NAME_MAIN="$ACR_NAME.azurecr.io/research-copilot-main"
DOCKER_CUSTOM_IMAGE_NAME_API="$ACR_NAME.azurecr.io/research-copilot-api"

# Function to queue Docker image build
queue_build() {
    local dockerImageName=$1
    local dockerFile=$2
    local sourceFolder=$3
    local tag=$4

    echo "Queueing build for $dockerImageName Docker image using Azure Container Registry with tag $tag..."
    az acr build --registry $ACR_NAME \
        --resource-group $RG \
        --image ${dockerImageName}:$tag \
        --file $dockerFile $sourceFolder
}

# Queue builds for UI, Main, and API images
queue_build $DOCKER_CUSTOM_IMAGE_NAME_UI $DOCKERFILE_PATH_UI "ui" $TAG
queue_build $DOCKER_CUSTOM_IMAGE_NAME_MAIN $DOCKERFILE_PATH_UI_MAIN "ui" $TAG
queue_build $DOCKER_CUSTOM_IMAGE_NAME_API $DOCKERFILE_PATH_API "code" $TAG

# Function to update web app container configuration
update_webapp_config() {
    local webAppName=$1
    local dockerImageName=$2
    local tag=$3

    echo "Setting new Docker image for $webAppName..."
    az webapp config container set --name $webAppName \
        --resource-group $RG \
        --docker-custom-image-name "${dockerImageName}:$tag" \
        --docker-registry-server-url "https://$ACR_NAME.azurecr.io"
}

# Fetch web app names from resource group
echo "Fetching web app names from resource group $RG..."
webAppNames=$(az webapp list --resource-group $RG --query "[?contains(name, '-app-')].name" -o tsv)

for webAppName in $webAppNames; do
    if [[ $webAppName == *"-app-chat-"* ]]; then
        update_webapp_config $webAppName $DOCKER_CUSTOM_IMAGE_NAME_UI $TAG
    elif [[ $webAppName == *"-app-main-"* ]]; then
        update_webapp_config $webAppName $DOCKER_CUSTOM_IMAGE_NAME_MAIN $TAG
    elif [[ $webAppName == *"-app-api-"* ]]; then
        update_webapp_config $webAppName $DOCKER_CUSTOM_IMAGE_NAME_API $TAG
    fi
done

echo "Script execution completed."