
#!/bin/bash
#gh auth login
# chmod +x deploy.sh
# source ./install_dependencies.sh
# install_dependencies

export MSYS_NO_PATHCONV=1
# export BUILD_DOCKER_LOCALLY="false"
# ANSI escape code to set the text color 
GREEN='\033[0;32m'
RED='\033[0;31m'
# ANSI escape code to reset the text color
RESET='\033[0m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'

SUBSCRIPTION=""
RG_WEBAPP_NAME=""

while [[ -z "$SUBSCRIPTION" ]] || ! az account list --query "[].id" -o tsv | grep -q "$SUBSCRIPTION"; do
    read -p "Subscription $SUBSCRIPTION is empty or not valid in this context. Please enter a valid subscription ID: " SUBSCRIPTION
done

$ az login --tenant 16b3c013-d300-468d-ac64-7eda0820b6d3

echo -e "${GREEN}Subscription is correct...${RESET}"

clear
echo -e "${GREEN}
  ________        ___.            .__       __________ .__                    __        __________         .__    __       
 /  _____/   ____ \_ |__  _____   |  |      \______   \|  |  _____     ____  |  | __    \______   \  ____  |  | _/  |_     
/   \  ___  /  _ \ | __ \ \__  \  |  |       |    |  _/|  |  \__  \  _/ ___\ |  |/ /     |    |  _/_/ __ \ |  | \   __\    
\    \_\  \(  <_> )| \_\ \ / __ \_|  |__     |    |   \|  |__ / __ \_\  \___ |    <      |    |   \\  ___/ |  |__|  |      
 \______  / \____/ |___  /(____  /|____/     |______  /|____/(____  / \___  >|__|_ \     |______  / \___  >|____/|__|      
        \/             \/      \/                   \/            \/      \/      \/            \/      \/                 
                                                                                                                           
                                                       .__                                .__ .__            __            
_______   ____    ______  ____  _____  _______   ____  |  |__        ____   ____  ______  |__||  |    ____ _/  |_          
\_  __ \_/ __ \  /  ___/_/ __ \ \__  \ \_  __ \_/ ___\ |  |  \     _/ ___\ /  _ \ \____ \ |  ||  |   /  _ \\   __\         
 |  | \/\  ___/  \___ \ \  ___/  / __ \_|  | \/\  \___ |   Y  \    \  \___(  <_> )|  |_> >|  ||  |__(  <_> )|  |           
 |__|    \___  >/____  > \___  >(____  /|__|    \___  >|___|  /     \___  >\____/ |   __/ |__||____/ \____/ |__|           
             \/      \/      \/      \/             \/      \/          \/        |__|                                     

 /\_/\\
( o.o )
 > ^ <

${RESET}"


# set it to false if you do not want the deployment to get confirmations and it will run without asking for confirmation
#script pre-requisistes: 

# Check if Chocolatey is installed
# Check if Chocolatey is installed
echo "Checking script pre-requisites..."
echo "**********************************"
# Check if Chocolatey is installed
echo "Checking if Chocolatey is installed..."
if ! command -v choco &> /dev/null
then
    echo "Chocolatey is not installed. might not be required if this is azure cloud shell."
    
else
    echo "Chocolatey is installed."
fi

# Using the command command
if command -v docker > /dev/null 2>&1; then
    echo -e "${GREEN}Docker CLI is installed.${RESET}"
else
    echo -e "${RED}Docker CLI is not installed. You can deploy only the infrastucture without the container deployment.${RESET}"    
    
    read -p "Press enter to continue..." -r
fi

if [[ $AZURE_HTTP_USER_AGENT == *"cloud-shell"* ]]; then
    echo -e "${YELLOW} This script is running in Azure Cloud Shell. Docker is not required running. You can continue with the deployment. ${RESET}"
    export running_on_azure_cloud_shell="true"
else
    echo -e "${YELLOW}This script is not running in Azure Cloud Shell. You need Docker running.${RESET}"
    export running_on_azure_cloud_shell="false"
    while ! docker info > /dev/null 2>&1; do
        echo -e "${RED}Docker is not running...${RESET}"
        read -p "Start it and then press enter to continue..." -r
    done
fi


echo -e "${GREEN} Docker is running. We can continue with the deployment.${RESET}"

# Check if jq is installed
echo -e "${YELLOW}Checking if jq is installed...${RESET}"
if ! command -v jq &> /dev/null
then
    echo -e "${RED}jq is not installed, installing...${RESET}"
    choco install jq -y
else
    echo -e "${GREEN}jq is installed.${RESET}"
fi

# Check if Azure CLI is installed
echo "Checking if Azure CLI is installed..."
if ! command -v az &> /dev/null
then
    echo -e "${RED}Azure CLI is not installed. Please install Azure CLI and run this script again.${$RESET}"
    exit 1
else
    echo -e "${GREEN}Azure CLI is installed.${RESET}"
fi



echo -e "${RED}*********************************IMPORTANT!***************************************${RESET}"
echo -e "${RED}*  This script requires that the user accepts the use of cognitve services.      *${RESET}"	
echo -e "${RED}*  Unfortunately this needs to be done manually.                                 *${RESET}"
echo -e "${RED}*  If you never created a cognitive service...                                   *${RESET}"
echo -e "${RED}*  Go to portal and create any cognitive service and accept the usage condition. *${RESET}"
echo -e "${RED}*********************************IMPORTANT!***************************************${RESET}"

generate_azure_compatible_name() {
    # Generate a random 6-character string that starts with a letter
    head /dev/urandom | tr -dc a-z0-9 | head -c 6 ; echo ''
}

prevent_path_conversion() {
  local str="$1"
  str="${str//\//\/\//}"
  str="${str//\\/\\\\}"
  echo "$str"
}


remove_path_from_string() {
  local str="$1"
  echo "${str//C:\/Program Files\/Git\//}"
}

DEPLOY_INFRA="true" #this is used later in the script, this value now has no effect, it will be reasigned later in the script

enableDdosProtection='false'
aiSearchRegion='eastus'
azure_unique_name=$(generate_azure_compatible_name)

SKIP_LOGIN_TO_AZURE="true"
USE_DEFAULT_NAMES="true"
CONFIRMATION="false" 
ROOT_PATH_INGESTION="/data"
PROMPTS_PATH="prompts" #path to save the prompts in the shared file share in the web app.
INGESTED_DATA_NAME="Ingested_data" #path to save the ingested data in the shared file share in the web app.


IMAGES_PUSHED="false" #this is used later in the script, this value now has no effect, it will be reasigned later in the script
DEPLOY_OPEN_AI="true" #false will not deploy the open ai resource
DEPLOY_AI_SEARCH="false" #false will not deploy the ai search resource
BUILD_DOCKER_LOCALLY="true" #just in case we want to build the docker locally if acr gives problems, or faster builds.

DEFAULT_LOCATION="swedencentral" #default location for the deployment
DEFAULT_PREFIX="dev" #default prefix for the deployment
DEFAULT_ACR="acr" 
DEFAULT_APP_SERVICE_NAME="appservice"
DEFAULT_WEB_APP_NAME="webapp"
DEFAULT_WEB_APP_NAME_MAIN="webappmain"
DEFAULT_OPEN_AI_RESOURCE="research-openai"
DEFAULT_AI_SEARCH_RESOURCE="aisearch"
DEFAULT_STORAGE_ACCOUNT_NAME="storage"
OPEN_AI_RESOURCE="research-openai"


WEB_APP_NAME_MAIN="rescopilot"
ACR_NAME="" #this will be reasigned later in the script

function parse_output_variables() {
    export MSYS_NO_PATHCONV=1
    output_variables=$(az deployment group show --resource-group $RG_WEBAPP_NAME --name main --query properties.outputs)

    # Parse the output variables and load them into bash variables
    export WEB_APP_NAME=$(echo $output_variables | jq -r '.webAppName.value')
    export WEB_APP_NAME_MAIN=$(echo $output_variables | jq -r '.webAppNameMain.value')
    export STORAGE_ACCOUNT_NAME=$(echo $output_variables | jq -r '.storageAccount.value')
    export APP_SERVICE_NAME=$(echo $output_variables | jq -r '.appServiceName.value')
    export ACR_NAME=$(echo $output_variables | jq -r '.containerRegistry.value')
    export ACCOUNTS_VISION_RES_TST_NAME=$(echo $output_variables | jq -r '.accountsVisionResTstName.value')    
    export UNIQUE_ID=$(echo $output_variables | jq -r '.uniqueId.value')        
    export COSMOS_DB=$(echo $output_variables | jq -r '.cosmosDbName.value')        

    echo "WEB_APP_NAME: $WEB_APP_NAME"
    echo "WEB_APP_NAME MAIN: $WEB_APP_NAME_MAIN"
    echo "STORAGE_ACCOUNT_NAME: $STORAGE_ACCOUNT_NAME"
    echo "APP_SERVICE_NAME: $APP_SERVICE_NAME"
    echo "ACR_NAME: $ACR_NAME"
    echo "ACCOUNTS_VISION_RES_TST_NAME: $ACCOUNTS_VISION_RES_TST_NAME"    
    echo "UNIQUE_ID: $UNIQUE_ID"    
    echo "COSMOS_DB: $COSMOS_DB"    
    #read -p "Press enter to continue..." -r
}

confirm() {
    message=$1
    color=${2:-$GREEN}

    while true; do
        # echo "*********confirmation value: $CONFIRMATION"	
        echo -e "${color}You are about to ${message}${RESET}"        
        if [[ "$CONFIRMATION" == "true" ]]; then
            read -r -p "Are you sure? [y/N] " response
            case "$response" in
                [yY][eE][sS]|[yY]) 
                    return 0
                ;;
                [nN][oO]|[nN])
                    return 1
                ;;
                *)
                    echo "Invalid input..."
                ;;
            esac
        else
            return 0
        fi
    done
}

#infrastucture as code section:


az provider register --namespace Microsoft.Search #making sure that the search service is registered


# Log in to Azure
if [[ "$SKIP_LOGIN_TO_AZURE" != "true" ]]; then
    echo "Loging in to Azure..."
    az login
fi

# Ask the user for the subscription ID
if [ -z "$SUBSCRIPTION" ]; then
    read -p -r "Enter the subscription ID: " SUBSCRIPTION
fi

# Set the context to the specified subscription
echo -e "${YELLOW}****we will now make sure that the context is set to the right subscription ${RESET}"
if [[ "$CONFIRMATION" == "true" ]]; then
    read -p -r "Press enter to continue..."
fi

az account set --subscription "$SUBSCRIPTION"
echo -e "${GREEN}****SUBCRIPTION SET TO: $SUBSCRIPTION ${RESET}"

# Ask the user for the resource group name

# Use the default name if the user didn't provide a name
if [ -z "$RESOURCE_GROUP_NAME" ]; then
    if [ "$USE_DEFAULT_NAMES" != "true" ]; then
        read -p -r "Enter the resource group name (default: $RG_WEBAPP_NAME): " RESOURCE_GROUP_NAME
    else
        echo "Using the default resource group name: $RG_WEBAPP_NAME"
        RESOURCE_GROUP_NAME=$RG_WEBAPP_NAME
        
    fi
fi

echo "Check if the resource group name already exists in the subscription..."
# Check if the resource group name already exists in the subscription
az group show --name $RESOURCE_GROUP_NAME &>/dev/null

if [ $? -eq 0 ]; then    
    echo -e "${RED}Resource group $RESOURCE_GROUP_NAME already exists. ${RESET}"
    RESOURCE_COUNT=$(az resource list --resource-group $RESOURCE_GROUP_NAME --query "length([?id != ''])")

    if [ $RESOURCE_COUNT -eq 0 ]
    then
        echo "Resource group $RESOURCE_GROUP_NAME is empty. You can deploy infrastucture"
        DEPLOY_INFRA="true"
    else
        echo ""
        DEPLOY_INFRA="false"
        echo -e "${YELLOW}Resource group $RESOURCE_GROUP_NAME is not empty. Infrastructure will not be deployed.. ${RESET}"
        echo -e "${YELLOW}if you want to deploy the infra, remove this RG or set a new RG name when asked. ${RESET}"
        if [[ "$CONFIRMATION" == "true" ]]; then
            read -p -r "Press enter to continue with the container deployment..."
        else
            echo -e "${GREEN}Continuing to the container build and push... ${RESET}"
        fi    
    fi
    
  
else    
    echo -e "${GREEN}Resource group $RESOURCE_GROUP_NAME does not exist. ${RESET}"    
    if confirm "create the resource group $RESOURCE_GROUP_NAME"; then
        # Create the resource group
        az group create --name $RESOURCE_GROUP_NAME --location $DEFAULT_LOCATION
    else
        echo "Exiting the script..."
        exit 1
    fi
fi

DEPLOY_INFRA="true" #this is used later in the script, this value now has no effect, it will be reasigned later in the script
az config set defaults.group=$RESOURCE_GROUP_NAME
if [[ "$DEPLOY_INFRA" == "true" ]]; then
    echo -e "${YELLOW}Infrastucture will be deployed now...${RESET}"
    if [ "$USE_DEFAULT_NAMES" != "true" ]; then
        read -p -r "Enter the location of the deployment: (default: $DEFAULT_LOCATION): " LOCATION
    fi

    # Use the default location if the user didn't provide a name
    if [ -z "$LOCATION" ]; then
        echo "Using the default location: $DEFAULT_LOCATION"    
        LOCATION=$DEFAULT_LOCATION
    fi

    if [ "$USE_DEFAULT_NAMES" != "true" ]; then
        read -p -r "Enter A prefix for the deployment names: (default: $DEFAULT_PREFIX): " PREFIX
    fi

    # Use the default location if the user didn't provide a name
    if [ -z "$PREFIX" ]; then
        echo "Using the default prefix: $DEFAULT_PREFIX"    
        PREFIX=$DEFAULT_PREFIX
    fi


    if [ "$USE_DEFAULT_NAMES" != "true" ]; then
        read -p -r "Enter the acr name : (default: $DEFAULT_ACR): " ACR_NAME
    fi

    # Use the default location if the user didn't provide a name
    if [ -z "$ACR_NAME" ]; then
        echo "Using the default acr name: $DEFAULT_ACR"    
        ACR_NAME=$DEFAULT_ACR
    fi

    if [ "$USE_DEFAULT_NAMES" != "true" ]; then
        read -p -r "Enter the name of the OpeanAI resource: (default: $DEFAULT_OPEN_AI_RESOURCE): " OPEN_AI_RESOURCE
    fi

    # Use the default location if the user didn't provide a name
    if [ -z "$OPEN_AI_RESOURCE" ]; then
        echo "Using the default OpenAI resource name: $DEFAULT_OPEN_AI_RESOURCE"    
        OPEN_AI_RESOURCE=$DEFAULT_OPEN_AI_RESOURCE
    fi

    # Use the default location if the user didn't provide a name
    if [ "$USE_DEFAULT_NAMES" != "true" ]; then
        read -p -r "Enter the App service name : (default: $DEFAULT_APP_SERVICE_NAME): " APP_SERVICE_NAME
    fi

    # Use the default location if the user didn't provide a name
    if [ -z "$APP_SERVICE_NAME" ]; then
        echo "Using the default app service name: $DEFAULT_APP_SERVICE_NAME"    
        APP_SERVICE_NAME=$DEFAULT_APP_SERVICE_NAME
    fi

    # Use the default location if the user didn't provide a name
    if [ "$USE_DEFAULT_NAMES" != "true" ]; then
        read -p -r "Enter the web App Name name : (default: $DEFAULT_WEB_APP_NAME): " WEB_APP_NAME
    fi

  #
    if [ -z "$WEB_APP_NAME" ]; then
        echo "Using the default web app name: $DEFAULT_WEB_APP_NAME"    
        WEB_APP_NAME=$DEFAULT_WEB_APP_NAME
    fi

    if [ -z "$WEB_APP_NAME_MAIN" ]; then
        echo "Using the default web app name: $DEFAULT_WEB_APP_NAME_MAIN"    
        WEB_APP_NAME_MAIN=$DEFAULT_WEB_APP_NAME_MAIN
    fi

    # Use the default location if the user didn't provide a name
    if [ "$USE_DEFAULT_NAMES" != "true" ]; then
        read -p -r "Enter the ai search name: (default: $DEFAULT_AI_SEARCH_RESOURCE): " AI_SEARCH_RESOURCE
    fi

    # Use the default location if the user didn't provide a name
    if [ -z "$AI_SEARCH_RESOURCE" ]; then
        echo "Using the default ai search name: $DEFAULT_AI_SEARCH_RESOURCE"    
        AI_SEARCH_RESOURCE=$DEFAULT_AI_SEARCH_RESOURCE
    fi

    if [ "$USE_DEFAULT_NAMES" != "true" ]; then
        read -p -r "Enter the storage account name : (default: $DEFAULT_STORAGE_ACCOUNT_NAME): " STORAGE_ACCOUNT_NAME
    fi

    # Use the default location if the user didn't provide a name
    if [ -z "$STORAGE_ACCOUNT_NAME" ]; then
        echo "Using the default storagea account name: $DEFAULT_STORAGE_ACCOUNT_NAME"    
        STORAGE_ACCOUNT_NAME=$DEFAULT_STORAGE_ACCOUNT_NAME
    fi

    echo -e "${GREEN}Attempting to deploy the infrastucture... ${RESET}"

    # TEMPLATE_FILE_PATH="./infra/research_copilot_template.json"            

    deploy="true" #this is used to check if the user wants to deploy the infra resources while coding just for dev reasons.
    

    if [[ "$deploy" == "true" ]]; then
        TEMPLATE_FILE_PATH="./infra-as-code-public/bicep/main.bicep"
        MSYS_NO_PATHCONV=1 az deployment group create \
        --template-file $TEMPLATE_FILE_PATH \
        --resource-group $RG_WEBAPP_NAME \
        --parameters namePrefix=$DEFAULT_PREFIX \
                     aiSearchRegion=$aiSearchRegion \
        --mode Incremental || echo -e "${RED}An error occurred, but the script will continue, check the deployment log in azure portal for more details.${RESET}"

        # Check the exit status of the deployment
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Deployment was successful/RG already existed. Continuing with the script...${RESET}"    
            # ... continue with the script ...
        else    
            echo -e "${RED}Deployment failed. Exiting the script.${RED}"    
            exit 1
        fi
    fi
    # Get the output variables from the main deployment , this contains the names of the resources that were created
    parse_output_variables        
    #open ai deployments
    #supported locations for vision as of Feb 2024
    SUPPORTED_LOCATIONS=("swedencentral" "australiaeast" "westus" "switzerlandnorth")
    SUPPORTED_LOCATIONS=("swedencentral") #only this 3 to start with switzerlandnorth DOES NOT HAVE TURBO
    #extracted from: https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/models#model-summary-table-and-region-availability
    # Sweden Central
    # West US
    # Japan East
    # Switzerland North
    # Australia East
   
    if [ -z "$UNIQUE_ID" ]; then
        UNIQUE_ID="k6rxhsic3me36"
    fi

    if [ -z "$PREFIX" ]; then
       #to make sure prefix is set.
       echo "Using the default prefix: $DEFAULT_PREFIX"    
       PREFIX=$DEFAULT_PREFIX
    fi

    location_counter=1
    echo -e "${YELLOW}Deploying the openAI resources in the following supported locations (February 2024) ${SUPPORTED_LOCATIONS[@]} ${RESET}"
    for location in "${SUPPORTED_LOCATIONS[@]}"
        do

            # Create the openAI resource for the current location            
            deployment_name="openai" #the template already adds the location to the name
            aoai_resource_name="${PREFIX}${deployment_name}${location}${UNIQUE_ID}"
            openAiSkuName="S0"
            bicepDeploymentName=$aoai_resource_name

            echo -e "${YELLOW} Creating the openAI resource $aoai_resource_name in location $location...${RESET}"
            TEMPLATE_FILE_PATH="./infra-as-code-public/bicep/openai.bicep"
            
             MSYS_NO_PATHCONV=1 az deployment group create \
                --resource-group $RG_WEBAPP_NAME \
                --name $bicepDeploymentName \
                --template-file $TEMPLATE_FILE_PATH \
                --parameters \
                    envName=$DEFAULT_PREFIX \
                    location="$location" \
                    aoaiResourceName=$aoai_resource_name \
                    openAiSkuName="$openAiSkuName" \
                --mode Incremental || echo -e "${RED}An error occurred, but the script will continue, check the deployment log in azure portal for more details.${RESET}"
            # Check the exit status of the deployment        
            output_variables=$(MSYS_NO_PATHCONV=1 az deployment group show --resource-group $RG_WEBAPP_NAME --name $bicepDeploymentName --query properties.outputs)

            aoaiResourceId=$(echo $output_variables | jq -r '.aoaiResourceId.value')
            # az cognitiveservices account network-rule add \
            #     --resource-group $RG_WEBAPP_NAME \
            #     --name $aoai_resource_name \
            #     --ip-address subnet
            
            echo -e "${GREEN}OpenAI resource $aoai_resource_name created successfully.${RESET}"               
            #we take the resource id of the accoutn to use it later to create the private endpoint, and more
            # echo -e "${YELLOW} getting the resource id for the openAI resource $aoai_resource_name... ${RESET}"
            # resourceId=$(MSYS_NO_PATHCONV=1 az cognitiveservices account show --resource-group "$RG_WEBAPP_NAME" --name $aoai_resource_name --query id --output tsv)
            echo -e "${YELLOW} The opean ai resource id is: $aoaiResourceId ${RESET}"

            aoai_temp_key=$(az cognitiveservices account keys list --name $aoai_resource_name --resource-group $RG_WEBAPP_NAME --query key1 --output tsv)        

            if [ $location_counter = 1 ]; then        
                #first open ai service
                AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE=$aoai_resource_name
                AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE_KEY=$aoai_temp_key
                AZURE_OPENAI_EMBEDDING_MODEL_API_VERSION="2023-12-01-preview"    

                AZURE_OPENAI_RESOURCE=$aoai_resource_name
                AZURE_OPENAI_KEY=$aoai_temp_key

                AZURE_OPENAI_RESOURCE_1=$aoai_resource_name
                AZURE_OPENAI_KEY_1=$aoai_temp_key

                AZURE_OPENAI_MODEL=gpt-4
                AZURE_OPENAI_EMBEDDING_MODEL=text-embedding-ada-002
                AZURE_OPENAI_MODEL_VISION=gpt4v

                AZURE_OPENAI_API_VERSION="2024-02-15-preview"
                AZURE_OPENAI_VISION_API_VERSION="2023-12-01-preview"
                AZURE_OPENAI_TEMPERATURE=0
                AZURE_OPENAI_TOP_P=1.0
                AZURE_OPENAI_MAX_TOKENS=1000
                AZURE_OPENAI_STOP_SEQUENCE=                
            else
                #this are the 2nd to 4th locations:
                case $location_counter in
                    2)
                        AZURE_OPENAI_RESOURCE_2=$aoai_resource_name
                        AZURE_OPENAI_KEY_2=$aoai_temp_key                
                        ;;
                    3)
                        AZURE_OPENAI_RESOURCE_3=$aoai_resource_name
                        AZURE_OPENAI_KEY_3=$aoai_temp_key                
                        ;;
                    4)
                        AZURE_OPENAI_RESOURCE_4=$aoai_resource_name
                        AZURE_OPENAI_KEY_4=$aoai_temp_key                
                        ;;            
                esac                
                #assign the first location to the evnironment variables of the web app        
            fi                 
            #we disable public access for the open ai resources accounts and leave only the private endpoint connection enabled. 
            #MSYS_NO_PATHCONV=1 az resource update --ids $aoaiResourceId --set properties.networkAcls="{'defaultAction':'Deny'}"  properties.publicNetworkAccess="Disabled"               
            #we increament the location so that we get the next location in the next iteration         
            location_counter=$((location_counter+1))
        done
fi
parse_output_variables


echo -e "${YELLOW} Enable Azure trusted services in the acr${RESET}"    
az acr update --name $ACR_NAME --allow-trusted-services true

#TODO: getting the right configuration from the deployed parameters:
AZURE_VISION_ENDPOINT="https://$ACCOUNTS_VISION_RES_TST_NAME.cognitiveservices.azure.com/"
AZURE_VISION_KEY=$(az cognitiveservices account keys list --name $ACCOUNTS_VISION_RES_TST_NAME --resource-group $RG_WEBAPP_NAME --query key1 --output tsv)

# Print the bash variables

echo "webAppName: $WEB_APP_NAME"
echo "webAppName main (Streamlit) : $WEB_APP_NAME_MAIN"
echo "storageAccount: $STORAGE_ACCOUNT_NAME"
echo "appServiceName: $APP_SERVICE_NAME"
echo "containerRegistry: $ACR_NAME"
echo "AI_SEARCH_RESOURCE: $AI_SEARCH_RESOURCE"
echo "openAIResource: $openAIResource"
echo "ACCOUNTS_VISION_RES_TST_NAME: $ACCOUNTS_VISION_RES_TST_NAME"
echo "AZURE_VISION_ENDPOINT: $AZURE_VISION_ENDPOINT"


#check if the file share exists, if not create it with the directories needed for the ingestion
DIRECTORY_NAME="Ingested_data"
SUB_DIRECTORY_NAME="Ingested_data/multimodal-rag-code-execution"
CONNECTION_STRING=$(az storage account show-connection-string --name $STORAGE_ACCOUNT_NAME --query connectionString --output tsv)
# Check if the directory exists
directory_exists=$(az storage directory exists --name $DIRECTORY_NAME --share-name $STORAGE_ACCOUNT_NAME --account-name $STORAGE_ACCOUNT_NAME --connection-string $CONNECTION_STRING --output tsv --query exists)

if [ "$directory_exists" == "true" ]; then
    echo -e "${YELLOW}Directory $DIRECTORY_NAME already exists in file share $STORAGE_ACCOUNT_NAME. ${RESET}"
else
    echo -e "${YELLOW}Directory $DIRECTORY_NAME does not exist in file share $STORAGE_ACCOUNT_NAME. Creating...${RESET}"
    # Create a directory in the file share
    az storage directory create  --name $DIRECTORY_NAME --share-name $STORAGE_ACCOUNT_NAME --account-name $STORAGE_ACCOUNT_NAME --connection-string $CONNECTION_STRING
    echo -e "${GREEN}Directory $DIRECTORY_NAME created successfully.${RESET}"
    az storage directory create  --name $SUB_DIRECTORY_NAME --share-name $STORAGE_ACCOUNT_NAME --account-name $STORAGE_ACCOUNT_NAME --connection-string $CONNECTION_STRING
    echo -e "${GREEN}Directory $SUB_DIRECTORY_NAME created successfully.${RESET}"
fi


#we make sure that the main ingestion folders exist in the file share:
DOCKER_CUSTOM_IMAGE_NAME_UI="$ACR_NAME.azurecr.io/research-copilot:latest"
DOCKER_CUSTOM_IMAGE_NAME_MAIN="$ACR_NAME.azurecr.io/research-copilot-main:latest"

DOCKERFILE_PATH_UI="docker/Dockerfile_chainlit_app"
# DOCKERFILE_PATH_UI_MAIN="docker/Dockerfile_streamlit_app"
DOCKERFILE_PATH_UI_MAIN="docker/Dockerfile"

DOCKER_REGISTRY_URL="https://$ACR_NAME.azurecr.io"
DOCKER_REGISTRY_NAME="$ACR_NAME.azurecr.io"
WEBAPP_NAME_UI=$WEB_APP_NAME

# Get the ACR credentials
acr_credentials=$(az acr credential show --name $ACR_NAME -g $RG_WEBAPP_NAME)

# Parse the credentials and load them into bash variables
DOCKER_USER_ID=$(echo $acr_credentials | jq -r '.username')
DOCKER_USER_PASSWORD=$(echo $acr_credentials | jq -r '.passwords[0].value')

echo "Docker User ID: $DOCKER_USER_ID"
echo "Docker User Password: $DOCKER_USER_PASSWORD"




echo "Script Execution Flow:"
echo "--------------------------"
echo "| 1. Docker Login        |"
echo "|          |             |"
echo "|          V             |"
echo "| 2. Build the UI        |"
echo "|          |             |"
echo "|          V             |"
echo "| 3. Push UI             |"
echo "|          |             |"
echo "|          V             |"
echo "| 4. Update Web App UI   |"
echo "|          |             |"
echo "|          V             |"
echo "| 5. Update API settings |"
echo "|          |             |"
echo "|          V             |"
echo "| 6. Create file share   |"
echo "--------------------------"
echo -e "${YELLOW}****Make sure you have the docker started...otherwise docker build will fail! ${RESET}"

if [[ "$CONFIRMATION" == "true" ]]; then
        read -p -r "Press enter to continue..."
fi


# Function to find and change to a directory
change_directory() {
    target=$1
    directory=$PWD

    # Loop until the directory is found or we reach the root directory
    while [[ "$directory" != "" && "$(basename "$directory")" != "$target" ]]; do
        directory=$(dirname "$directory")
    done

    # Check if the directory was found
    if [[ "$(basename "$directory")" == "$target" ]]; then
        # Change to the directory
        cd "$directory"
        echo -e "${GREEN}Changed the current directory to $directory.${RESET}"
    else
        echo "The $target directory was not found."
        exit 1
    fi
}

# Check if the current directory is multimodal-rag-code-execution
if [[ "$(basename "$PWD")" != "multimodal-rag-code-execution" ]]; then
    echo -e "${YELLOW}Warning: You are not in the multimodal-rag-code-execution directory. This is required as the Docker build expects you there.${RESET}"
    confirm "change the current directory to multimodal-rag-code-execution"
    if [ $? -eq 0 ]; then
        # Change the current directory to ccp-backend
        change_directory "multimodal-rag-code-execution"
        if [[ "$CONFIRMATION" == "true" ]]; then
            read -p -r "Press enter to continue..."
        fi
    else
        echo "Please navigate to the multimodal-rag-code-execution directory and run the script again."
        exit 1
    fi
fi

# Login to the Docker registry

echo -e "${YELLOW}Make sure you have the docker started...${RESET}"


if [[ "$running_on_azure_cloud_shell" = "false" ]]; then
    echo -e "${GREEN}Attempting to log in to Docker registry usiing docker locally $DOCKER_REGISTRY_NAME...${RESET}"
    docker login $DOCKER_REGISTRY_NAME --username $DOCKER_USER_ID --password $DOCKER_USER_PASSWORD
else
    #running on azure cloud shell
    echo -e "${GREEN}Attempting to log in az acr remotely $DOCKER_REGISTRY_NAME...${RESET}"
    # az acr login --name $ACR_NAME --username $DOCKER_USER_ID --password $DOCKER_USER_PASSWORD --expose-token    
    TOKEN=$(az acr login --name $ACR_NAME --expose-token --output tsv --query accessToken)    
    # docker login $DOCKER_REGISTRY_NAME --username "00000000-0000-0000-0000-000000000000" --password-stdin <<< $TOKEN
    docker login $DOCKER_REGISTRY_NAME --username "00000000-0000-0000-0000-000000000000" --password $TOKEN
fi
#read -p "Press enter to continue..." -r
#building and pushing the UI
# build the UI

if confirm "build the docker?"; then
    if [[ "$running_on_azure_cloud_shell" = "false" ]]; then
        # build the docker locally
        echo -e "${GREEN}Building the chainlit app docke r locally...${RESET}"
        docker build -t $DOCKER_CUSTOM_IMAGE_NAME_UI -f $DOCKERFILE_PATH_UI .
        echo -e "${GREEN}Building the streamlit app docker locally...${RESET}"
        docker build -t $DOCKER_CUSTOM_IMAGE_NAME_MAIN -f $DOCKERFILE_PATH_UI_MAIN .

    else
        # build the docker using Azure Container Registry
        echo -e "${GREEN}Building the chainlit app docker using Azure Container Registry...${RESET}"
        az acr build --registry $ACR_NAME --image $DOCKER_CUSTOM_IMAGE_NAME_UI --file $DOCKERFILE_PATH_UI .        
        echo -e "${GREEN}Building the streamlit app docker using Azure Container Registry...${RESET}"
        az acr build --registry $ACR_NAME --image $DOCKER_CUSTOM_IMAGE_NAME_MAIN --file $DOCKERFILE_PATH_UI_MAIN .        
    fi        
fi
image_exists=$(az acr repository show --name $ACR_NAME --image $DOCKER_CUSTOM_IMAGE_NAME_UI --output tsv --query name --verbose)

if [ "$image_exists" == "$DOCKER_CUSTOM_IMAGE_NAME_UI" ]; then
    echo -e "${GREEN}Image $DOCKER_CUSTOM_IMAGE_NAME_UI exists in registry $ACR_NAME. ${RESET}"
else
    echo "the command image_exists az acr repository returned: $image_exists"
    echo -e "${RED}Image $DOCKER_CUSTOM_IMAGE_NAME_UI does not exist in registry $ACR_NAME. Exiting the script ${RESET}"
    #exit 1
fi

image_exists=$(az acr repository show --name $ACR_NAME --image $DOCKER_CUSTOM_IMAGE_NAME_MAIN --output tsv --query name --verbose)

if [ "$image_exists" == "$DOCKER_CUSTOM_IMAGE_NAME_MAIN" ]; then
    echo e "${GREEN}Image $DOCKER_CUSTOM_IMAGE_NAME_MAIN exists in registry $ACR_NAME.${RESET}"
else
    echo "the command image_exists az acr repository returned: $image_exists"
    echo -e "${RED}Image $DOCKER_CUSTOM_IMAGE_NAME_MAIN does not exist in registry $ACR_NAME. Exiting the script${RESET}"
    #exit 1
fi

if [[ "$running_on_azure_cloud_shell" = "false" ]]; then
    if confirm "push to acr?"; then    
        echo -e "${GREEN}Pushing the chainlit app docker to Azure Container Registry...${RESET}"
        docker push $DOCKER_CUSTOM_IMAGE_NAME_UI
        echo -e "${GREEN}Pushing the streamlit app docker to Azure Container Registry...${RESET}"
        docker push $DOCKER_CUSTOM_IMAGE_NAME_MAIN
        IMAGES_PUSHED="true"
    fi
else
    IMAGES_PUSHED="true"
fi
# Check if IMAGES_PUSHED is true
if [ "$IMAGES_PUSHED" = "true" ]; then
    echo -e "${GREEN}Images have been pushed. Please check the Azure portal at $ACR_PORTAL_LOCATION to confirm.${RESET}"
    if [[ "$CONFIRMATION" == "true" ]]; then
        read -p -r "Press enter to continue..."
    fi
fi

echo -e "${YELLOW}****The next steps will deploy to the selected subscription ${RESET}"
#echo -e "${YELLOW}****You will need to request  JIT access in order to perform changes in their Azure enironment${RESET}"
#echo -e "${YELLOW}****Please, log in to the Customer's Azure tenant ${RESET}"

if [[ "$CONFIRMATION" == "true" ]]; then
    read -p -r "Press enter to continue..."
fi
#az login

# Update the UI
WEBAPP_UPDATED="False"
if confirm "update the UI on $WEBAPP_NAME_UI and with the new Image?" "$RED"; then
    # Load the settings from the JSON file
    
    #output=$(az webapp config container set --name $WEBAPP_NAME_UI --resource-group $RG_WEBAPP_NAME --docker-custom-image-name $DOCKER_CUSTOM_IMAGE_NAME_UI --docker-registry-server-url $DOCKER_REGISTRY_URL --docker-registry-server-user $DOCKER_USER_ID --docker-registry-server-password $DOCKER_USER_PASSWORD 2>&1)
    output=$(az webapp config container set --name $WEBAPP_NAME_UI --resource-group $RG_WEBAPP_NAME --docker-custom-image-name $DOCKER_CUSTOM_IMAGE_NAME_UI --docker-registry-server-url $DOCKER_REGISTRY_URL --docker-registry-server-user $DOCKER_USER_ID --docker-registry-server-password $DOCKER_USER_PASSWORD 2>&1)  
    echo -e "${GREEN}****Container updated into the web app. Give it some time to load it!${RESET}"	    
    WEBAPP_UPDATED="true"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error updating the UI: $output${RESET}"
        WEBAPP_UPDATED="False"
    fi   
fi

WEBAPP_UPDATED="False"
if confirm "update the UI on $WEBAPP_NAME_UI_MAIN and with the new Image?" "$RED"; then
    # Load the settings from the JSON file
    
    #output=$(az webapp config container set --name $WEBAPP_NAME_UI --resource-group $RG_WEBAPP_NAME --docker-custom-image-name $DOCKER_CUSTOM_IMAGE_NAME_UI --docker-registry-server-url $DOCKER_REGISTRY_URL --docker-registry-server-user $DOCKER_USER_ID --docker-registry-server-password $DOCKER_USER_PASSWORD 2>&1)
    output=$(az webapp config container set --name $WEBAPP_NAME_UI_MAIN --resource-group $RG_WEBAPP_NAME_MAIN --docker-custom-image-name $DOCKER_CUSTOM_IMAGE_NAME_MAIN --docker-registry-server-url $DOCKER_REGISTRY_URL --docker-registry-server-user $DOCKER_USER_ID --docker-registry-server-password $DOCKER_USER_PASSWORD 2>&1)  
    echo -e "${GREEN}****Container updated into the web app. Give it some time to load it!${RESET}"	    
    WEBAPP_UPDATED="true"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error updating the UI: $output${RESET}"
        WEBAPP_UPDATED="False"
    fi   
fi
# Get the URL of the web app
webapp_url=$(az webapp show --name $WEBAPP_NAME_UI --resource-group $RG_WEBAPP_NAME --query defaultHostName -o tsv)
CHAINLIT_APP=$webapp_url
#COSMOS DB
COSMOS_DB_NAME="$COSMOS_DB"
COSMOS_URI="https://$COSMOS_DB_NAME.documents.azure.com:443/"
# Get the primary master key and assign it to a variable
COSMOS_KEY==$(az cosmosdb keys list --name $COSMOS_DB_NAME --resource-group $RG_WEBAPP_NAME --query primaryMasterKey --output tsv)
COSMOS_CONTAINER_NAME="prompts"
COSMOS_CATEGORYID="prompts"

#SCM_BASIC_AUTHENTICATION_ENABLED
read -r -d '' app_settings << EOM
{    
    "CHAINLIT_APP": "$webapp_url",
    "COSMOS_URI": "$COSMOS_URI",
    "COSMOS_KEY": "$COSMOS_KEY",
    "COSMOS_DB_NAME": "$COSMOS_DB_NAME",
    "COSMOS_CONTAINER_NAME": "$COSMOS_CONTAINER_NAME",
    "COSMOS_CATEGORYID": "$COSMOS_CATEGORYID",    
    "ROOT_PATH_INGESTION": "$ROOT_PATH_INGESTION",
    "PROMPTS_PATH": "$PROMPTS_PATH",
    "HOST": "0.0.0.0",
    "LISTEN_PORT": 8000,
    "DI_ENDPOINT": "$DI_ENDPOINT",
    "DI_KEY": "$DI_KEY",
    "AZURE_OPENAI_RESOURCE": "$AZURE_OPENAI_RESOURCE",
    "AZURE_OPENAI_KEY": "$AZURE_OPENAI_KEY",
    "AZURE_OPENAI_MODEL": "$AZURE_OPENAI_MODEL",
    "AZURE_OPENAI_RESOURCE_1": "$AZURE_OPENAI_RESOURCE_1",
    "AZURE_OPENAI_KEY_1": "$AZURE_OPENAI_KEY_1",
    "AZURE_OPENAI_RESOURCE_2": "$AZURE_OPENAI_RESOURCE_2",
    "AZURE_OPENAI_KEY_2": "$AZURE_OPENAI_KEY_2",
    "AZURE_OPENAI_RESOURCE_3": "$AZURE_OPENAI_RESOURCE_3",
    "AZURE_OPENAI_KEY_3": "$AZURE_OPENAI_KEY_3",
    "AZURE_OPENAI_RESOURCE_4": "$AZURE_OPENAI_RESOURCE_4",
    "AZURE_OPENAI_KEY_4": "$AZURE_OPENAI_KEY_4",
    "AZURE_OPENAI_EMBEDDING_MODEL": "$AZURE_OPENAI_EMBEDDING_MODEL",
    "AZURE_OPENAI_MODEL_VISION": "$AZURE_OPENAI_MODEL_VISION",
    "AZURE_OPENAI_API_VERSION": "$AZURE_OPENAI_API_VERSION",
    "AZURE_OPENAI_TEMPERATURE": "$AZURE_OPENAI_TEMPERATURE",
    "AZURE_OPENAI_TOP_P": "$AZURE_OPENAI_TOP_P",
    "AZURE_OPENAI_MAX_TOKENS": "$AZURE_OPENAI_MAX_TOKENS",
    "AZURE_OPENAI_STOP_SEQUENCE": "$AZURE_OPENAI_STOP_SEQUENCE",
    "AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE": "$AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE",
    "AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE_KEY": "$AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE_KEY",
    "AZURE_OPENAI_EMBEDDING_MODEL_API_VERSION": "$AZURE_OPENAI_EMBEDDING_MODEL_API_VERSION",
    "COG_SERV_ENDPOINT": "$COG_SERV_ENDPOINT",
    "COG_SERV_KEY": "$COG_SERV_KEY",
    "COG_SERV_LOCATION": "$COG_SERV_LOCATION",
    "AZURE_VISION_ENDPOINT": "$AZURE_VISION_ENDPOINT",
    "AZURE_VISION_KEY": "$AZURE_VISION_KEY",
    "AZURE_OPENAI_ASSISTANTSAPI_ENDPOINT": "$AZURE_OPENAI_ASSISTANTSAPI_ENDPOINT",
    "AZURE_OPENAI_ASSISTANTSAPI_KEY": "$AZURE_OPENAI_ASSISTANTSAPI_KEY",
    "OPENAI_API_KEY": "$OPENAI_API_KEY",
    "COG_SEARCH_ENDPOINT": "$COG_SEARCH_ENDPOINT",
    "COG_SEARCH_ADMIN_KEY": "$COG_SEARCH_ADMIN_KEY",
    "COG_VEC_SEARCH_API_VERSION": "$COG_VEC_SEARCH_API_VERSION",
    "COG_SEARCH_ENDPOINT_PROD": "$COG_SEARCH_ENDPOINT_PROD",
    "COG_SEARCH_ADMIN_KEY_PROD": "$COG_SEARCH_ADMIN_KEY_PROD",
    "BLOB_CONN_STR": "$BLOB_CONN_STR"
}
EOM

if confirm "update the web app settings in $WEBAPP_NAME_UI? (y/n)" "$RED"; then
    # settings=$(jq -r 'map("\(.name)=\(.value)") | join(" ")' $app_settings)
    #settings=$(echo -e "$app_settings" | jq -r 'to_entries|map("\(.key)=\(.value)")[]')
    settings=$(jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|join(" ")' <<< "$app_settings")
    MSYS_NO_PATHCONV=1 az webapp config appsettings set --name $WEBAPP_NAME_UI --resource-group $RG_WEBAPP_NAME --settings $settings
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error updating the UI: $output${RESET}"
    fi
fi

if confirm "update the web app settings in $WEB_APP_NAME_MAIN? (y/n)" "$RED"; then
    # settings=$(jq -r 'map("\(.name)=\(.value)") | join(" ")' $app_settings)
    #settings=$(echo -e "$app_settings" | jq -r 'to_entries|map("\(.key)=\(.value)")[]')
    settings=$(jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|join(" ")' <<< "$app_settings")
    MSYS_NO_PATHCONV=1 az webapp config appsettings set --name $WEB_APP_NAME_MAIN --resource-group $RG_WEBAPP_NAME --settings $settings
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error updating the UI: $output${RESET}"
    fi
fi

# create the storage mount path if it does not exist in the web app
ACCOUNT_NAME=$STORAGE_ACCOUNT_NAME
SHARE_NAME=$STORAGE_ACCOUNT_NAME
STORAGE_ACCESS_KEY= $(az storage account keys list --account-name $ACCOUNT_NAME --resource-group $RG_WEBAPP_NAME --query '[0].value' --output tsv)
#STORAGE_ACCESS_KEY='XHx8VlKJqEvnZUlT9lnVWmJ66voMmy0jvqA5/1paUASBbKooQUWowtdznpRWOHHzs4NF59o4fR14+AStLpUyEA=='
CUSTOM_ID='fileshare'
# Get the current path mappings
path_mappings=$(az webapp config storage-account list --name $WEBAPP_NAME_UI --resource-group $RG_WEBAPP_NAME --query "[?name=='$CUSTOM_ID']")

# Check if the 'fileshare' path mapping exists
if [[ $path_mappings == "[]" ]]; then
    echo -e "${YELLOW}The fileshare path mapping does not exist in the web app $WEBAPP_NAME_UI.${RESET}"
    # If it doesn't exist, create it
    if confirm "Create the fileshare  $SHARE_NAME in $WEBAPP_NAME_UI? (y/n)" "$RED"; then
        # az webapp config storage-account add --name $WEBAPP_NAME_UI --resource-group $RG_WEBAPP_NAME --custom-id fileshare --storage-type AzureFiles --share-name $SHARE_NAME --account-name $ACCOUNT_NAME --mount-path /data --access-key $STORAGE_ACCESS_KEY
        MSYS_NO_PATHCONV=1 az webapp config storage-account add -g $RG_WEBAPP_NAME \
        -n $WEBAPP_NAME_UI \
        --custom-id $CUSTOM_ID \
        --storage-type AzureFiles \
        --account-name $ACCOUNT_NAME \
        --share-name $SHARE_NAME \
        --access-key $STORAGE_ACCESS_KEY \
        --mount-path /data                
        # az webapp config storage-account add --resource-group MyResourceGroup --name MyUniqueApp --custom-id CustomId --storage-type AzureFiles --account-name MyStorageAccount --share-name MyShare --access-key MyAccessKey --mount-path /path/to/mount
        if [ $? -ne 0 ]; then
            echo "Error creating the path mapping" >&2
            # exit 1
        fi
    fi
else    
    echo -e "${GREEN}The fileshare path mapping exists in the web app $WEBAPP_NAME_UI.${RESET}"
fi


if [ "$WEBAPP_UPDATED" = "true" ]; then
    echo -e "${RED}!!!!!!!!IMPORTANT: THE IMAGE(s) are LARGE, IT TAKES AROUND 5-7 MINUTES TO LOAD IN THE WEB APP.${RESET}"       
    echo -e "${RED}!in the Deployment Center log (or Log stream) you should see info like below.${RESET}"
    echo -e "${YELLOW}2024-03-08T08:01:10.567Z INFO - b3f695e2d3d6 Extracting 1060MB / 3111MB${RESET}"
    echo -e "${YELLOW}2024-03-08T08:01:10.678Z INFO - b3f695e2d3d6 Extracting 1065MB / 3111MB${RESET}"
    echo -e "${YELLOW}2024-03-08T08:01:10.800Z INFO - b3f695e2d3d6 Extracting 1069MB / 3111MB${RESET}"
    echo -e "${YELLOW}2024-03-08T08:01:10.909Z INFO - b3f695e2d3d6 Extracting 1073MB / 3111MB${RESET}"
    echo -e "${YELLOW}2024-03-08T08:01:11.015Z INFO - b3f695e2d3d6 Extracting 1077MB / 3111MB${RESET}"
    echo -e "${YELLOW}2024-03-08T08:01:11.115Z INFO - b3f695e2d3d6 Extracting 1082MB / 3111MB${RESET}"
    echo -e "${YELLOW}2024-03-08T07:30:55.946811934Z Current Path:  /home/appuser/app/code${RESET}"
    echo -e "${YELLOW}2024-03-08T07:30:55.946823935Z Execution Path:${RESET}"
    echo -e "${YELLOW}2024-03-08T07:30:55.946828235Z Test Project Path:${RESET}"
    echo -e "${YELLOW}2024-03-08T07:30:55.946831835Z Default Vector Directory:  ../doc_ingestion_cases/${RESET}"
    echo -e "${YELLOW}2024-03-08T07:30:55.946835935Z Taskweaver Path:  ../TaskWeaver/${RESET}"
fi


echo -e "${YELLOW}****Restarting the webup, just in case!${YELLOW}"    
#az webapp restart --name $WEBAPP_NAME_UI --resource-group $RG_WEBAPP_NAME 

# Initialize webapp_status with a non-"Running" value
webapp_status="restart_pending"

# Keep checking the status of the web app until it's "Running"
while [ "$webapp_status" != "Running" ]; do
    # Check the status of the web app
    webapp_status=$(az webapp show --name $WEBAPP_NAME_UI --resource-group $RG_WEBAPP_NAME --query state -o tsv)
    echo -e "${YELLOW}****Checking the status of the web app ...${YELLOW}"
    # Wait for a bit before checking again
    sleep 5
done

echo -e "${GREEN}Web app restarted successfully.${RESET}"

echo -e "${GREEN}Process Finished! happy testing!.${RESET}"

# Print the URL as a clickable link
echo -e "${BLUE}Web app URL: http://$webapp_url${RESET}"
