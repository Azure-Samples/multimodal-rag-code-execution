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

# Function to deploy container app
function DeployContainerApp($dockerImageName, $dockerFile, $sourceFolder, $tag, $containerAppName) {

    $confirmation = Read-Host -Prompt "Do you want to proceed with the build of $dockerImageName ? (Y/N)"
    if ($confirmation -eq "Y" -or $confirmation -eq "y") {
        Write-Host "Building the $containerAppName Docker image using Azure Container Registry with tag $tag..." -ForegroundColor Green
        az acr build --registry $ACR_NAME `
            --resource-group $RG `
            --image ${dockerImageName}:$tag `
            --image "${dockerImageName}:latest" `
            --file $dockerFile $sourceFolder

        # Update the container app to pull the latest image and restart
        Write-Host "Updating the Azure Container App ($containerAppName) to pull the latest image..." -ForegroundColor Yellow
        az containerapp update --name $containerAppName --resource-group $RG --image ${dockerImageName}:$tag

        # If "api" also update the container app job
        if ($sourceFolder -eq "code") {
            # get the job name from the resource group
            $jobName = $containerAppName -replace "-api-", "-ingestion-job-"
            Write-Host "Updating the Azure Container App job ($jobName) to pull the latest image..." -ForegroundColor Yellow
            az containerapp job update --name $jobName --resource-group $RG --image ${dockerImageName}:$tag
        }

        Write-Host "$dockerImageName build completed and deployed to Azure Container App $containerAppName" -ForegroundColor Green
    } else {
        Write-Host "$dockerImageName build skipped by the user." -ForegroundColor Yellow
    }
}

# Get container app names from the Azure Container App
$containerAppNames = az containerapp list --resource-group $RG --query "[].name" -o tsv

# Assign container app names to variables
$CHAT_WEB_APP_NAME = $containerAppNames | Where-Object { $_ -like "*-chat-*" }
$API_WEB_APP_NAME = $containerAppNames | Where-Object { $_ -like "*-api-*" }
$MAIN_WEB_APP_NAME = $containerAppNames | Where-Object { $_ -like "*-main-*" }

# Define paths to your Dockerfiles
$DOCKERFILE_PATH_UI = "docker/dockerfile_chainlit_app"
$DOCKERFILE_PATH_UI_MAIN = "docker/dockerfile_streamlit_app"
$DOCKERFILE_PATH_API = "docker/dockerfile_api"

Write-Host "Container app names are: $CHAT_WEB_APP_NAME, $API_WEB_APP_NAME, $MAIN_WEB_APP_NAME"
# Deploy web apps using the function
DeployContainerApp "$ACR_NAME.azurecr.io/research-copilot-api" $DOCKERFILE_PATH_API "code" $TAG $API_WEB_APP_NAME
DeployContainerApp "$ACR_NAME.azurecr.io/research-copilot" $DOCKERFILE_PATH_UI "ui" $TAG $CHAT_WEB_APP_NAME
DeployContainerApp "$ACR_NAME.azurecr.io/research-copilot-main" $DOCKERFILE_PATH_UI_MAIN "ui" $TAG $MAIN_WEB_APP_NAME
