# 1-click deployment

The new way to deploy this solutions is using the 1-click deployment. This is the recommended way to deploy this solution.

## Known limitations

Due to an [upstream Bicep limitations with Service Principals](https://learn.microsoft.com/en-us/graph/templates/known-issues-graph-bicep?view=graph-bicep-1.0#application-passwords-are-not-supported-for-applications-and-service-principals), the 1-click deployment will NOT be able to create a secret. You will need to run a post-deployment script to create the secret and assign it to the API WebApp in order to complete the deployment.

## Pre-requisites

- You will need to have an Azure subscription and be able to create resources in it. At least a resource group is required, and the user must have `Owner` permissions.
- Addiitonally, you will need to have privileges to create an app registration/service principal.
- Using Cloud Shell is also recommend to finalize the deployment.

## Deployment steps (Azure Portal)

1. Click the "Deploy to Azure" button

    [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/?feature.customportal=false#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure-Samples%2Fmultimodal-rag-code-execution%2Fmain%2Fdeployment%2Finfra-as-code-public%2Fbicep%2Fmain-1click.json)

1. Fill in parameters

    There no special parameters for this deployment. Optional parameters are available to customize the deployment (see below). Typically, only `openAIName` and `openAIRGName` are used to reuse an existing Azure OpenAI resource.

    Average deployment time is 10 minutes when no existing container registry is set.

1. Finalize deployment

    After the deployment is complete, you will need to run a post-deployment script to create the secret and assign it to the API WebApp.

    1. Open the **Azure Cloud Shell (Bash)**
    1. Upload the `set-sp-script.sh` script to the Cloud Shell
    1. Run `chmod +x set-sp-script.sh`
    1. Run `./set-sp-script.sh <appId> <api-webapp-name> <resource-group-name>`.
    
        Values can be found in the deployment outputs: go to the resource group, select the deployment `main-1click`, and click on the `Outputs` tab.

## Customization

The following parameters are available for customization:

- `openAIName` and `openAIRGName`: Name and resource group for the Azure OpenAI resource to reuse, instead of creating a new one.
- `containerRegistryName` and `containerRegistryPassword`: Name and password for an existing Azure Container Registry to reuse, instead of creating a new one. When not set, a new container registry will be created and images will be built pushed to it via cloning the GitHub repository.
- `namePrefix`: Prefix for all resources created by the deployment. Default is `dev`.

## Deployment steps (local)

1. Clone the GitHub repository

    ```bash
    git clone https://github.com/Azure-Samples/multimodal-rag-code-execution

    cd multimodal-rag-code-execution
    ```

1. Run the deployment script

    ```bash
    az group create --name multimodal-rag-code-execution --location <location>

    az deployment group create --resource-group multimodal-rag-code-execution --template-file deployment/infra-as-code-public/bicep/main-1click.bicep --parameters <key=value>
    ```

1. Finalize deployment

    After the deployment is complete, you will need to run a post-deployment script to create the secret and assign it to the API WebApp.

    1. Run `chmod +x set-sp-script.sh`
    1. Run `./set-sp-script.sh <appId> <api-webapp-name> <resource-group-name>`.
    
        Values can be found in the deployment outputs: go to the resource group, select the deployment `main-1click`, and click on the `Outputs` tab.