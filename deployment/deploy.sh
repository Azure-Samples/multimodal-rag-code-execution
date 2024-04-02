#!/bin/bash
#gh auth login
# chmod +x deploy.sh

export MMSYS_NO_PATHCONV=1
# export BUILD_DOCKER_LOCALLY="false"
# ANSI escape code to set the text color 
GREEN='\033[0;32m'
RED='\033[0;31m'
# ANSI escape code to reset the text color
RESET='\033[0m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'

# Load the environment variables from the .env file
source ./.env

SUBSCRIPTION=''


while [[ -z "$SUBSCRIPTION" ]] || ! az account list --query "[].id" -o tsv | grep -q "$SUBSCRIPTION"; do
    read -p "Subscription $SUBSCRIPTION is empty or not valid in this context. Please enter a valid subscription ID: " SUBSCRIPTION
done


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

  /~\\
 C oo
 _( ^)
/   ~\\

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
    echo "Docker CLI is installed."
else
    echo "Docker CLI is not installed. You can deploy only the infrastucture without the container deployment."    
    export deploy_application="false"
    read -p "Press enter to continue..." -r
fi

if [[ $AZURE_HTTP_USER_AGENT == *"cloud-shell"* ]]; then
    echo "This script is running in Azure Cloud Shell. Docker is not required running. You can continue with the deployment."
    export running_on_azure_cloud_shell="true"
else
    echo "This script is not running in Azure Cloud Shell. You need Docker running."
    export running_on_azure_cloud_shell="false"
    while ! docker info > /dev/null 2>&1; do
        echo "Docker is not running."
        read -p "Start it and then press enter to continue..." -r
    done
fi



echo "Docker is running. We can continue with the deployment."

# Check if jq is installed
echo "Checking if jq is installed..."
if ! command -v jq &> /dev/null
then
    echo "jq is not installed, installing..."
    choco install jq -y
else
    echo "jq is installed."
fi

# Check if Azure CLI is installed
echo "Checking if Azure CLI is installed..."
if ! command -v az &> /dev/null
then
    echo "Azure CLI is not installed. Please install Azure CLI and run this script again."
    exit 1
else
    echo "Azure CLI is installed."
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

# generate_password() {
#   # Generate a random password that includes at least one uppercase letter, one lowercase letter, one digit, and one special character
#   PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9@#$%^*()-+=' | fold -w 12 | head -n 1)

#   # Ensure the password meets the complexity requirements
#   while ! [[ ${PASSWORD} =~ [A-Z] ]] || ! [[ ${PASSWORD} =~ [a-z] ]] || ! [[ ${PASSWORD} =~ [0-9] ]] || ! [[ ${PASSWORD} =~ [@#$%^*\(\)-+=] ]]; do
#     PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9@#$%^*()-+=' | fold -w 12 | head -n 1)
#   done

#   echo ${PASSWORD}
# }



generate_password() {
  # Generate the first character (a letter)
  FIRST_CHAR=$(cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 1 | head -n 1)

  # Generate the rest of the password
  REST_OF_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9@#$%^*()-+=' | fold -w 11 | head -n 1)

  # Combine the first character and the rest of the password
  PASSWORD="${FIRST_CHAR}${REST_OF_PASSWORD}"

  # Ensure the password meets the complexity requirements
  while ! [[ ${PASSWORD} =~ [A-Z] ]] || ! [[ ${PASSWORD} =~ [a-z] ]] || ! [[ ${PASSWORD} =~ [0-9] ]] || ! [[ ${PASSWORD} =~ [@#$%^*\(\)-+=] ]]; do
    FIRST_CHAR=$(cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 1 | head -n 1)
    REST_OF_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9@#$%^*()-+=' | fold -w 11 | head -n 1)
    PASSWORD="${FIRST_CHAR}${REST_OF_PASSWORD}"
  done

  echo ${PASSWORD}
}

DEPLOY_INFRA="true" #this is used later in the script, this value now has no effect, it will be reasigned later in the script

enableDdosProtection='false'
# The IP address prefix for the virtual network (VNet)
vnetAddressPrefix='10.0.0.0/16'

# The IP address prefix for the subnet that the Application Gateway will be deployed to
appGatewaySubnetPrefix='10.0.1.0/24'

# The IP address prefix for the subnet that the App Services will be deployed to
appServicesSubnetPrefix='10.0.0.0/24'

# The IP address prefix for the subnet that the private endpoints will be deployed to
privateEndpointsSubnetPrefix='10.0.2.0/27'

# The IP address prefix for the subnet that the agents will be deployed to
agentsSubnetPrefix='10.0.2.32/27'

appGatewayListenerCertificate=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

aiSearchRegion='eastus'
deployJumpBox='true'

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
DEFAULT_OPEN_AI_RESOURCE="research-openai"
DEFAULT_AI_SEARCH_RESOURCE="aisearch"
DEFAULT_STORAGE_ACCOUNT_NAME="storage"
OPEN_AI_RESOURCE="research-openai"
RG_WEBAPP_NAME="new-research-copilot-rg"

ACR_NAME="" #this will be reasigned later in the script

function parse_output_variables() {
    output_variables=$(MMSYS_NO_PATHCONV=1 az deployment group show --resource-group $RG_WEBAPP_NAME --name main --query properties.outputs)

    # Parse the output variables and load them into bash variables
    export WEB_APP_NAME=$(echo $output_variables | jq -r '.webAppName.value')
    export STORAGE_ACCOUNT_NAME=$(echo $output_variables | jq -r '.storageAccount.value')
    export APP_SERVICE_NAME=$(echo $output_variables | jq -r '.appServiceName.value')
    export ACR_NAME=$(echo $output_variables | jq -r '.containerRegistry.value')
    export ACCOUNTS_VISION_RES_TST_NAME=$(echo $output_variables | jq -r '.accountsVisionResTstName.value')
    export JUMP_BOX_PASSWORD=$(echo $output_variables | jq -r '.vmUserPassword.value')
    export JUMP_BOX_USER_NAME=$(echo $output_variables | jq -r '.vmAdminUserName.value')
    export KEYVAULT_NAME=$(echo $output_variables | jq -r '.keyvaultname.value')
    export JUMPBOX_VM_NAME=$(echo $output_variables | jq -r '.vmName.value')
    export VNET_NAME=$(echo $output_variables | jq -r '.vnetName.value')
    export PRIVATE_ENDPOINTS_SUBNET=$(echo $output_variables | jq -r '.privateEndpointsSubnetName.value')
    export MMSYS_NO_PATHCONV=1 PRIVATE_ENDPOINTS_SUBNET_ID=$(echo $output_variables | jq -r '.privateEndpointsSubnetId.value')
    export VNET_NAME=$(echo $output_variables | jq -r '.vnetName.value')
    export UNIQUE_ID=$(echo $output_variables | jq -r '.uniqueId.value')
    echo "WEB_APP_NAME: $WEB_APP_NAME"
    echo "STORAGE_ACCOUNT_NAME: $STORAGE_ACCOUNT_NAME"
    echo "APP_SERVICE_NAME: $APP_SERVICE_NAME"
    echo "ACR_NAME: $ACR_NAME"
    echo "ACCOUNTS_VISION_RES_TST_NAME: $ACCOUNTS_VISION_RES_TST_NAME"
    echo "JUMP_BOX_PASSWORD: $JUMP_BOX_PASSWORD"
    echo "JUMP_BOX_USER_NAME: $JUMP_BOX_USER_NAME"
    echo "KEYVAULT_NAME: $KEYVAULT_NAME"
    echo "JUMPBOX_VM_NAME: $JUMPBOX_VM_NAME"
    echo "VNET_NAME: $VNET_NAME"
    echo "PRIVATE_ENDPOINTS_SUBNET: $PRIVATE_ENDPOINTS_SUBNET"
    echo "PRIVATE_ENDPOINTS_SUBNET_ID: $PRIVATE_ENDPOINTS_SUBNET_ID"
    echo "VNET_NAME: $VNET_NAME"
    echo "UNIQUE_ID: $UNIQUE_ID"
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
    DEPLOY_INFRA="false"
    echo -e "${YELLOW}Infrastucture will not be deployed. ${RESET}"
    echo -e "${YELLOW}if you want to deploy the infra, remove this RG or set a new RG name when asked. ${RESET}"
    if [[ "$CONFIRMATION" == "true" ]]; then
        read -p -r "Press enter to continue with the container deployment..."
    else
        echo -e "${GREEN}Continuing to the container build and push... ${RESET}"
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

az config set defaults.group=$RESOURCE_GROUP_NAME
#DEPLOY_INFRA="true"

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

    # Use the default location if the user didn't provide a name
    if [ -z "$WEB_APP_NAME" ]; then
        echo "Using the default web app name: $DEFAULT_WEB_APP_NAME"    
        WEB_APP_NAME=$DEFAULT_WEB_APP_NAME
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
    TEMPLATE_FILE_PATH="./infra-as-code/bicep/main.bicep"

    vmUserPassword=$(generate_password)   
    vmAdminUsername='azureuser'        
    echo -e "${YELLOW} vmUserPassword: $vmUserPassword${RESET}"
    #we get the current pincilal id so that we can assign the keyvault administrator role to the current user
    # userPrincipalId=$(az ad user show --id $(az account show --query id -o tsv) --query objectId -o tsv)
    userPrincipalId=$(az ad signed-in-user show --query id -o tsv)

    echo -e "${YELLOW} current userPrincipalId: $userPrincipalId${RESET}"    
    # read -p "Press enter to continue..." -r

    deploy="false" #this is used to check if the user wants to deploy the infra resources

    if [[ "$deploy" == "false" ]]; then

    MMSYS_NO_PATHCONV=1 az deployment group create \
    --template-file $TEMPLATE_FILE_PATH \
    --resource-group $RG_WEBAPP_NAME \
    --parameters appGatewayListenerCertificate=$appGatewayListenerCertificate \
                 namePrefix=$DEFAULT_PREFIX \
                 aiSearchRegion=$aiSearchRegion \
                 vnetAddressPrefix=$vnetAddressPrefix \
                 appGatewaySubnetPrefix=$appGatewaySubnetPrefix \
                 appServicesSubnetPrefix=$appServicesSubnetPrefix \
                 privateEndpointsSubnetPrefix=$privateEndpointsSubnetPrefix\
                 agentsSubnetPrefix=$agentsSubnetPrefix \
                 deployJumpBox=$deployJumpBox \
                 vmUserPassword=$vmUserPassword \
                 vmAdminUsername=$vmAdminUsername\
                 vmName='vm' \
                 enableDdosProtection=$enableDdosProtection \
                 userPrincipalId=$userPrincipalId \
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
            bicepDeploymentName="${PREFIX}-${deployment_name}-$location-${UNIQUE_ID}"

            echo -e "${YELLOW}Creating the openAI resource $aoai_resource_name in location $location...${RESET}"
            TEMPLATE_FILE_PATH="./infra-as-code/bicep/openai.bicep"
            
            # if [[ "$deploy" == "false" ]] ; then	
            #     #simulation
            #     VNET_NAME="dev-vnet-xe4t44kuwpez6"
            # privateEndpointsSubnet="snet-privateEndpoints"
            # privateEndpointsSubnetId=
            # fi

            MMSYS_NO_PATHCONV=1 az deployment group create \
                --resource-group $RG_WEBAPP_NAME \
                --name $bicepDeploymentName \
                --template-file $TEMPLATE_FILE_PATH \
                --parameters \
                    envName=$DEFAULT_PREFIX \
                    location="$location" \
                    aoaiResourceName=$aoai_resource_name \
                    openAiSkuName="$openAiSkuName" \
                    uniqueid=$UNIQUE_ID \
                    vnetName=$VNET_NAME \
                --mode Incremental || echo -e "${RED}An error occurred, but the script will continue, check the deployment log in azure portal for more details.${RESET}"
                        # Check the exit status of the deployment

            if [ $? -eq 0 ]; then
                echo -e "${GREEN}OPen AI Deployment for $location was successful/ already existed. Continuing with the script...${RESET}"    
                # ... continue with the script ...
            else    
                echo -e "${RED}Deployment failed. Exiting the script.${RED}"    
                exit 1
            fi
            output_variables=$(MMSYS_NO_PATHCONV=1 az deployment group show --resource-group $RG_WEBAPP_NAME --name $bicepDeploymentName --query properties.outputs)

            aoaiResourceId=$(echo $output_variables | jq -r '.aoaiResourceId.value')

            echo -e "${GREEN}OpenAI resource $aoai_resource_name created successfully.${RESET}"               
            #we take the resource id of the accoutn to use it later to create the private endpoint, and more
            # echo -e "${YELLOW} getting the resource id for the openAI resource $aoai_resource_name... ${RESET}"
            # resourceId=$(MMSYS_NO_PATHCONV=1 az cognitiveservices account show --resource-group "$RG_WEBAPP_NAME" --name $aoai_resource_name --query id --output tsv)
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
            #MMSYS_NO_PATHCONV=1 az resource update --ids $aoaiResourceId --set properties.networkAcls="{'defaultAction':'Deny'}"  properties.publicNetworkAccess="Disabled"               
            #we increament the location so that we get the next location in the next iteration         
            location_counter=$((location_counter+1))
            
        done        
fi
parse_output_variables

echo -e "\e[5mWe are going to deploy the web app now\e[0m"
echo "JUMP_BOX_PASSWORD: $JUMP_BOX_PASSWORD"
#we get the public ip of the current machine and add it to the keyvault firewall
public_ip=$(curl -s ifconfig.me)
echo "current Public IP: $public_ip"
#adding this IP to the keyvault fireall
echo -e "${YELLOW} Adding this Ip tpo the keyvault firewall ${RESET}"    
az keyvault network-rule add --name $KEYVAULT_NAME --ip-address $public_ip

# echo -e "${YELLOW} Adding this public Ip to the acr firewall ${RESET}"    
# az acr network-rule add --name $ACR_NAME --ip-address $public_ip
# #CDR for the acr tasks:
# az acr network-rule add --name $ACR_NAME --ip-address "51.12.101.0/26"



echo -e "${YELLOW} Enable Azure trusted services in the acr${RESET}"    
az acr update --name $ACR_NAME --allow-trusted-services true

#Uploading the code to the jumpBox VM:
#echo -e "${YELLOW} Uploading the code to the VM ${RESET}"




if [[ "$DEPLOY_INFRA" == "true" ]]; then
    echo -e "${YELLOW} Updating the password for the admin user in the VM ${RESET}"    
    az vm user update -n $JUMPBOX_VM_NAME -g  $RG_WEBAPP_NAME -u azureuser -p $vmUserPassword
fi


#TODO: getting the right configuration from the deployed parameters:
AZURE_VISION_ENDPOINT="https://$ACCOUNTS_VISION_RES_TST_NAME.cognitiveservices.azure.com/"
AZURE_VISION_KEY=$(az cognitiveservices account keys list --name $ACCOUNTS_VISION_RES_TST_NAME --resource-group $RG_WEBAPP_NAME --query key1 --output tsv)

# Print the bash variables

echo "webAppName: $WEB_APP_NAME"
echo "storageAccount: $STORAGE_ACCOUNT_NAME"
echo "appServiceName: $APP_SERVICE_NAME"
echo "containerRegistry: $ACR_NAME"
echo "AI_SEARCH_RESOURCE: $AI_SEARCH_RESOURCE"
echo "openAIResource: $openAIResource"
echo "ACCOUNTS_VISION_RES_TST_NAME: $ACCOUNTS_VISION_RES_TST_NAME"
echo "JUMP_BOX_PASSWORD: $JUMP_BOX_PASSWORD"
echo "AZURE_VISION_ENDPOINT: $AZURE_VISION_ENDPOINT"
echo "JUMP_BOX_USER_NAME: $JUMP_BOX_USER_NAME"
echo "JUMP_BOX_USER_PASSWORD: $JUMP_BOX_PASSWORD"


#check if the file share exists, if not create it with the directories needed for the ingestion
DIRECTORY_NAME="Ingested_data"
SUB_DIRECTORY_NAME="Ingested_data/mm-doc-analysis-rag-ce"
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


#NOW WE UPLOAD THE PROMPTS TO THE FILE SHARE

DIRECTORY_NAME="prompts"
CONNECTION_STRING=$(az storage account show-connection-string --name $STORAGE_ACCOUNT_NAME --query connectionString --output tsv)
# Check if the directory exists
echo -e "${YELLOW}Cheking if $DIRECTORY_NAME directory exists in file share $STORAGE_ACCOUNT_NAME. ${RESET}"

directory_exists=$(az storage directory exists --name $DIRECTORY_NAME --share-name $STORAGE_ACCOUNT_NAME --account-name $STORAGE_ACCOUNT_NAME --connection-string $CONNECTION_STRING --output tsv --query exists)

if [ "$directory_exists" == "true" ]; then
    echo -e "${YELLOW}Directory $DIRECTORY_NAME already exists in file share $STORAGE_ACCOUNT_NAME. ${RESET}"
else
    echo -e "${YELLOW}Directory $DIRECTORY_NAME does not exist in file share $STORAGE_ACCOUNT_NAME. Creating... ${RESET}"
    # Create a directory in the file share
    az storage directory create  --name $DIRECTORY_NAME --share-name $STORAGE_ACCOUNT_NAME --account-name $STORAGE_ACCOUNT_NAME --connection-string $CONNECTION_STRING    
    echo -e "${GREEN}Directory $PROMPTS_PATH created successfully.${RESET}"
    echo -e "${YELLOW} Attempting to upload the prompts to the file share...${RESET}"
    count=0
    while IFS= read -r -d '' file; do
        (( count++ ))
        # Remove the leading '../code/prompts/' from the file path
        file_path=${file#../code/prompts/}
        # Get the directory part of the file path
        dir_path=$(dirname "$file_path")

        #echo -e "${YELLOW} Creating directory $dir_path ...${RESET}"
        # Create the directory
        az storage directory create --name "$PROMPTS_PATH/$dir_path" --share-name "$STORAGE_ACCOUNT_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --connection-string "$CONNECTION_STRING"

        echo -e "${YELLOW} Uploading file $file ...${RESET}"
        # Upload the file
        az storage file upload --share-name "$STORAGE_ACCOUNT_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --source "$file" --path "$PROMPTS_PATH/$file_path" --connection-string "$CONNECTION_STRING"
    done < <(find ../code/prompts -type f -name "*.txt" -print0)

    echo -e "${GREEN}Uploaded $count files ${RESET}"
    #PROMPTS_PATH="/data/prompts" #just for documentation, already assigned at the begining of the script.
fi

#we make sure that the main ingestion folders exist in the file share:
DOCKER_CUSTOM_IMAGE_NAME_API="$ACR_NAME.azurecr.io/research-copilot:latest"
DOCKER_CUSTOM_IMAGE_NAME_UI="$ACR_NAME.azurecr.io/research-copilot:latest"
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


DOCKERFILE_PATH_UI="docker/Dockerfile_chainlit_app"

echo "Script Execution Flow:"
echo "--------------------------"
echo "| 1. Docker Login        |"
echo "|          |             |"
echo "|          V             |"
echo "| 2. Build the UI        |"
echo "|          |             |"
echo "|          V             |"
echo "| 3. Push API            |"
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

# Check if the current directory is mm-doc-analysis-rag-ce
if [[ "$(basename "$PWD")" != "mm-doc-analysis-rag-ce" ]]; then
    echo -e "${YELLOW}Warning: You are not in the mm-doc-analysis-rag-ce directory. This is required as the Docker build expects you there.${RESET}"
    confirm "change the current directory to mm-doc-analysis-rag-ce"
    if [ $? -eq 0 ]; then
        # Change the current directory to ccp-backend
        change_directory "mm-doc-analysis-rag-ce"
        if [[ "$CONFIRMATION" == "true" ]]; then
            read -p -r "Press enter to continue..."
        fi
    else
        echo "Please navigate to the mm-doc-analysis-rag-ce directory and run the script again."
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
read -p "Press enter to continue..." -r
#building and pushing the UI
# build the UI

if confirm "build the docker?"; then
    if [[ "$running_on_azure_cloud_shell" = "false" ]]; then
        # build the docker locally
        docker build -t $DOCKER_CUSTOM_IMAGE_NAME_UI -f $DOCKERFILE_PATH_UI .
    else
        # build the docker using Azure Container Registry
        az acr build --registry $ACR_NAME --image $DOCKER_CUSTOM_IMAGE_NAME_UI --file $DOCKERFILE_PATH_UI .        
    fi        
fi
image_exists=$(az acr repository show --name $ACR_NAME --image $DOCKER_CUSTOM_IMAGE_NAME_UI --output tsv --query name --verbose)

if [ "$image_exists" == "$DOCKER_CUSTOM_IMAGE_NAME_UI" ]; then
    echo "Image $DOCKER_CUSTOM_IMAGE_NAME_UI exists in registry $ACR_NAME."
else
    echo "the command image_exists az acr repository returned: $image_exists"
    echo "Image $DOCKER_CUSTOM_IMAGE_NAME_UI does not exist in registry $ACR_NAME. Exiting the script"
    #exit 1
fi

if [[ "$running_on_azure_cloud_shell" = "false" ]]; then
    if confirm "push to acr?"; then    
        docker push $DOCKER_CUSTOM_IMAGE_NAME_UI
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
if confirm "update the UI on $WEBAPP_NAME_UI with the new Image?" "$RED"; then
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

read -r -d '' app_settings << EOM
{
    "SCM_BASIC_AUTHENTICATION_ENABLED": true,
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
    "AZURE_OPENAI_RESOURCE_5": "$AZURE_OPENAI_RESOURCE_5",
    "AZURE_OPENAI_KEY_5": "$AZURE_OPENAI_KEY_5",
    "AZURE_OPENAI_RESOURCE_6": "$AZURE_OPENAI_RESOURCE_6",
    "AZURE_OPENAI_KEY_6": "$AZURE_OPENAI_KEY_6",
    "AZURE_OPENAI_RESOURCE_7": "$AZURE_OPENAI_RESOURCE_7",
    "AZURE_OPENAI_KEY_7": "$AZURE_OPENAI_KEY_7",
    "AZURE_OPENAI_RESOURCE_8": "$AZURE_OPENAI_RESOURCE_8",
    "AZURE_OPENAI_KEY_8":  "$AZURE_OPENAI_KEY_8",
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

# create the storage mount path if it does not exist in the web app
ACCOUNT_NAME='storageseh0003'
SHARE_NAME='research-copilot-storage'
STORAGE_ACCESS_KEY= $(az storage account keys list --account-name $ACCOUNT_NAME --resource-group $RG_WEBAPP_NAME --query '[0].value' --output tsv)
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

# Enable SCM basic authentication for the web app

# echo -e "${YELLOW}Setting SCM Basic Auth Publishing for web app $WEBAPP_NAME_UI...${RESET}"
# az webapp config set --name $WEBAPP_NAME_UI --resource-group $RG_WEBAPP_NAME --scm-type Basic
# if [ $? -eq 0 ]; then
#     echo -e "${GREEN}SCM Basic Auth Publishing was successfully set for web app $WEBAPP_NAME_UI.${RESET}"
# else
#     echo -e "${RED}Failed to set SCM Basic Auth Publishing for web app $WEBAPP_NAME_UI.${RESET}"
# fi


if [ "$WEBAPP_UPDATED" = "true" ]; then
    echo -e "${RED}!!!!!!!!IMPORTANT: THE IMAGE IS LARGE, IT TAKES AROUND 5-7 MINUTES TO LOAD IN THE WEB APP.${RESET}"       
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
if [[ "$DEPLOY_INFRA" == "true" ]]; then
    echo -e "${RED}The password to access the VM is $vmUserPassword ${RESET}"
fi

# Get the URL of the web app
webapp_url=$(az webapp show --name $WEBAPP_NAME_UI --resource-group $RG_WEBAPP_NAME --query defaultHostName -o tsv)
# Print the URL as a clickable link
echo -e "${BLUE}Web app URL: http://$webapp_url${RESET}"
