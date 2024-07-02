# Deployment Script for Azure Resources in a sandbox subscription

This repository contains a Bash script (`deploy_public.sh`) that automates the deployment of Azure resources. It does so by deploying everything public, to simplifying prototying and de deployment of POC's in SandBox Subscriptions. 

We are preparing and enterprise deployment version as well but, in the meantime, you can use this for exploration, demos and POCs.

## Environment Compatibility

This script has been tested and confirmed to work on Git Bash on Windows. If you're using a different shell or operating system, the script may not work as expected.

### Requirements for Git Bash

- **Git Bash**: The script uses features specific to Bash, so it needs to be run in Git Bash or a similar Bash-compatible shell.

- **Azure CLI**: The script uses the Azure CLI to manage Azure resources. You can install the Azure CLI from the [official website](https://docs.microsoft.com/cli/azure/install-azure-cli).

- **Docker**: The script requires Docker to build and push Docker images. You can install Docker from the [official website](https://docs.docker.com/get-docker/).

- **jq**: The script uses jq to parse JSON data. You can install jq from the [official website](https://stedolan.github.io/jq/download/).

- **Chocolatey**: The script uses Chocolatey to install software on Windows. You can install Chocolatey from the [official website](https://chocolatey.org/install).

Please ensure that all these requirements are met before running the script in Git Bash.

## Prerequisites


The script will veify that you have the following requirements installed. 
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [Docker](https://docs.docker.com/get-docker/)
- [jq](https://stedolan.github.io/jq/download/)
- [Chocolatey](https://chocolatey.org/install) (Only for Windows users)

These applications can be installed in severall ways, if the script fails, you will need to troubleshoot the deployment. Or just do it manually.


## Configuration

Before running the script, you need to set up a few configuration variables:

- `SUBSCRIPTION`: This is your Azure subscription ID. The script will use this subscription to deploy the resources. You can find your subscription ID in the Azure portal, or by running the `az account show --query id --output tsv` command in the Azure CLI.

- `RG_WEBAPP_NAME`: This is the name of the Azure resource group where the web app will be deployed. A resource group is a logical container for resources deployed on Azure. Make sure to choose a unique name for your resource group.

You can set these variables in your env file environment (recommended), or you can set them directly in the script before running it.

The repo contains a sample .env.sample file. Copy it and adapt it to your needs.

## Argument Parameters

The script supports various parameters to control its behavior during deployment, although we recommend deploying first without any paramters. Later on, if you want to control future deployments you can explore the options that these parameters will enable. 
These parameters can be passed as command-line arguments when executing the script. Below is an explanation of each parameter and examples of how to use them.

### General Parameters

- **`force_redeploy`**: Accepts `true` or `false`. Forces the redeployment of the infrastructure. Use this parameter to trigger a full redeployment even if the infrastructure already exists.
- **`update_webapp_settings`**: Accepts `true` or `false`. Updates the web app settings to the default configuration specified within the script. By default the script will always update the settings. This is useful when you do not want the update them so you will be setting this to false.
- **`force_build_on_cloud`**: Accepts `true` or `false`. Forces the build process to occur on Azure Container Registry (ACR) in the cloud, bypassing local Docker builds. This is useful in stuations where the terminal running the script does not have access to a running docker such as the Azure Cloud Shell (keep in mind that docker CLI is still required). If you local docker is also performing slow you can set this parameter to true, and the build and push will be triggered in the ACR by creating a dinamic build & push ACR task.
- **`update_settings_only`**: Accepts `true` or `false`. If set to `true`, the script will only update the web app settings without building containers or deploying infrastructure. This is useful when you want to refresh the settings to the original state. 

### Web App Build Parameters
This two settings are useful when you just want to rebuild one of the web apps.
- **`build_chainlit`**: Accepts `true` or `false`. Determines whether to update the Chainlit web app. This is the web app that exposes the chat functionality
- **`build_streamlit`**: Accepts `true` or `false`. Determines whether to update the Streamlit web app. This is the web app that exposes the ingestion and prompt management functionalities.

### Azure Integration Parameters

- **`login_to_azure`**: Accepts `true` or `false`. Determines whether the script should automatically handle Azure login. Set this to `false` if already logged in or running in an environment like Azure Cloud Shell.
- **`azure_resources_file`**: Specifies the file name that contains the output variables from Azure deployment. This is crucial for scripts that rely on specific Azure resource configurations.

### Usage Examples

Here are a few examples of how to run the script with these parameters:

```bash
# Update only the settings of web apps without redeploying infrastructure or building containers
./deploy.sh update_settings_only=true

# Force a redeployment of the infrastructure and update the Chainlit web app
./deploy.sh force_redeploy=true build_chainlit=true

# Perform a cloud-based build and update the Streamlit app without updating settings
./deploy.sh force_build_on_cloud=true build_streamlit=true update_webapp_settings=false
```

## `Force Redeployment` Parameter

### Overview
By default the script checks if the target resource group is empty and, if it is, it will go an attempt deploying all the infrastucture. If the resource group is not empty, it assumes that you want to deploy a new version of the application (CI/CD) and it will do the following: 
- Build the Docker images.
- Push them to the Azure Container Registry (ACR).
- :exclamation: **Important**: it will set the web app settings to default values and you will loose any customization to the environment variables in both web apps.

The `deploy_public.sh` script accepts an optional `force_redeploy` parameter. This parameter controls whether the script should force a redeployment of the resources, even if they're already present in the resource group. 

To use the `force_redeploy` parameter, pass `true` or `false` as an argument when running the script:

```shellscript
./deploy_public.sh force_redeploy true
```

## `azure_resources_file` Parameter

### Overview
You should use this **only** on custom deployments (where Azure resources were not deployed by this script)  This method forces the script to read the resources names from the passed file. and will ignore any ouptuts generated as part of a generated deployment template at resource group level. 
The `azure_resources_file` parameter allows you to specify a JSON file that contains output variables from an Azure deployment. This file is critical when the script needs to obtain Azure resource configurations dynamically, especially in custom deployments where resource names or settings may vary between executions.

### How It Works

When provided, the script will attempt to read this file and extract Azure resource configuration details necessary for subsequent operations, such as setting up web app configurations or integrating services. If the file does not exist or is misconfigured, the script will default to attempting to retrieve the same information directly from the live Azure resource group, ensuring robustness in handling various deployment scenarios.
As an example we are providing the azure_resources_file_example.json file that you can use to pupulate it with your custome deployments, and pass it through as an argument so that all the web app settings are generated with the right values. 

### Script Processing Logic

Here's a breakdown of how the script processes the `azure_resources_file`:

1. **File Reading**: The script reads the JSON file specified by the `azure_resources_file` parameter.
2. **Error Handling**: If the file cannot be read (either because it does not exist or due to permission issues), the script defaults to fetching configuration details from the Azure resource group.
3. **Variable Assignment**: The script assigns values from the JSON file to variables that are used throughout the deployment process.

## `get_variables_from_live_rg` Parameter

### Overview
Avoid using this method if you created all the infrastucture using this script. This option is provided for clients with complex hybrid deployments generated manually. The script will detect if the current deployment is custom or generated with the script, and will automatically use this setting when manual deployments detected.

The `get_variables_from_live_rg` (Get Variables from Live Resource Group) parameter allows the script to dynamically fetch configuration details directly from an existing Azure Resource Group. This is particularly useful in scenarios where the deployment configuration needs to adapt to the current state of Azure resources, ensuring that the script operates with the most up-to-date information.

### How It Works

When set to `true`, this parameter instructs the script to bypass static configurations or predefined JSON files for resource details. Instead, it retrieves the current settings directly from the Azure services within the specified Resource Group. This method ensures that the script uses the latest configurations and is especially critical in dynamic environments where resource settings might change frequently.

### Script Processing Logic

Here's a summary of how the script processes the `get_variables_from_live_rg`:

1. **Check Parameter**: The script first checks if `get_variables_from_live_rg` is set to `true`.
2. **Fetch Configurations**: If true, the script fetches live configurations such as web app settings, container registry details, and other necessary parameters directly from the Azure Resource Group.
3. **Error Handling**: Proper error checks are implemented to handle situations where the script might fail to retrieve some or all of the configuration details.


## Running the Script

1. Clone this repository to your local machine:

2. Navigate to the directory containing the script:

    ```shellscript
    cd deployment
    ```

3. Make the script executable:

    ```shellscript
    chmod +x deploy_public.sh
    ```

4. Run the script:

    ```shellscript
    ./deploy_public.sh
    ```

If all the requirements are in place,  the sript will then proceed with the deployment of Azure resources.

## Troubleshooting

If you encounter any issues while running the script, the script will log the errors, and continue if the errors are related to the deployment 



## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the terms of the MIT license.
