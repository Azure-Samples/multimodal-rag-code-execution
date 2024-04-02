# Deployment Script for Azure Resources in a sandbox subscription

This repository contains a Bash script (`deploy_public.sh`) that automates the deployment of Azure resources. It does so by deploying everything public, to simplifying prototying and de deployment os POC's in SandBox Subscriptions. 

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

These applications can be installed in severall ways, if the script fails, you will need to troubleshoot the deployment. Or just do it yourself/


## Configuration

Before running the script, you need to set up a few configuration variables:

- `SUBSCRIPTION`: This is your Azure subscription ID. The script will use this subscription to deploy the resources. You can find your subscription ID in the Azure portal, or by running the `az account show --query id --output tsv` command in the Azure CLI.

- `RG_WEBAPP_NAME`: This is the name of the Azure resource group where the web app will be deployed. A resource group is a logical container for resources deployed on Azure. Make sure to choose a unique name for your resource group.

You can set these variables in your env file environment (recommended), or you can set them directly in the script before running it.

The repo contains a sample .env.sample file. Copy it and adapt it to your needs.

## Note on redeploying: Force Redeployment

By default the script checks if the target resource group is empty and, if it is, it will go an attempt deploying all the infrastucture. If the resource group is not empty, it assumes that you want to deploy a new version of the application (CI/CD) and it will do the following: 
- Build the Docker images.
- Push them to the Azure Container Registry (ACR).
- :exclamation: **Important**: Set the web app settings to default values.

The `deploy_public.sh` script accepts an optional `force_redeploy` parameter. This parameter controls whether the script should force a redeployment of the resources, even if they're already present in the resource group. 

To use the `force_redeploy` parameter, pass `true` or `false` as an argument when running the script:

```shellscript
./deploy_public.sh force_redeploy true
```

## Running the Script

1. Clone this repository to your local machine:

    ```shellscript
    git clone <repository-url>
    ```

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

The script will check if Docker and jq are installed and running. If not, it will prompt you to install them. It will then proceed with the deployment of Azure resources.

## Troubleshooting

If you encounter any issues while running the script, the script will log the errors, and continue if the errors are related to the deployment 



## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the terms of the MIT license.
