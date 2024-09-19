# 1-click deployment

The new way to deploy this solutions is using the 1-click deployment. This is the recommended way to deploy this solution.

## Pre-requisites

- You will need to have an Azure subscription and be able to create resources in it. At least a resource group is required, and the user must have `Owner` permissions on it.

## Deployment steps (Azure Portal)

1. Click the "Deploy to Azure" button

    [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/?feature.customportal=false#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure-Samples%2Fmultimodal-rag-code-execution%2Fmain%2Fdeployment%2Finfra-as-code-public%2Fbicep%2Fmain-1click.json)

1. Fill in parameters

    There are no special parameters for this deployment. Optional parameters are available to customize the deployment (see below). Typically, only `openAIName` and `openAIRGName` are used to reuse an existing Azure OpenAI resource.

    Average deployment time is 10 minutes when no existing container registry is set.

## Customization

The following parameters are available for customization:

- `openAIName` and `openAIRGName`: Name and resource group for the Azure OpenAI resource to reuse, instead of creating a new one.
registry will be created and images will be built pushed to it via cloning the GitHub repository.
- `namePrefix`: Prefix for all resources created by the deployment. Default is `dev`.
- `newOpenAILocation`: Location for the new Azure OpenAI resource. Default is empty and will be ignored unless `openAIName` is blank.
- `skipImagesBuild`: `True` not to build images from the remote repository. Default is `False`. If set to `True`, the deployment will not 
create a container registry and you will need to build the images manually (see below).
- `useWebApps`: `True` to provision Azure WebApps instead of Container App to host images. Default is `False`.

## Deployment steps (local)

1. Clone the GitHub repository

    ```bash
    git clone https://github.com/Azure-Samples/multimodal-rag-code-execution

    cd multimodal-rag-code-execution
    ```

1. Run the deployment script

    You could run the below commands in either a Powershell or a Git Bash.

    ```bash
    az login
    
    az upgrade

    az bicep upgrade

    az group create --name multimodal-rag-code-execution --location <location>
    
    ## [OPTION 1] USE AN EXISTING OPENAI RESOURCE
    ## Existing OpenAI Resource must have one model name 'gpt-4o' and another named 'text-embedding-3-large'. Please provide the name of the OAI resource and the RG name where that resource is
    az deployment group create --resource-group multimodal-rag-code-execution --template-file deployment/infra-as-code-public/bicep/main-1click.bicep --parameters aiSearchRegion=eastus openAIName=<OAI_NAME> openAIRGName=<OAI_RG_NAME>

    ## [OPTION 2] CREATE A NEW OPENAI RESOURCE
    az deployment group create --resource-group multimodal-rag-code-execution --template-file deployment/infra-as-code-public/bicep/main-1click.bicep --parameters aiSearchRegion=eastus newOpenAILocation=eastus

    ```

### Screenshots of the Deployment

In the Azure portal, go to Deployments:

<br />
<p align="center">
<img src="../images/depl-image3.png" width="800" />
</p>
<br/>

Check all resources being deployed:

<br />
<p align="center">
<img src="../images/depl-image2.png" width="800" />
</p>
<br/>

### Troubleshooting

If you see the below screenshot, please check your API web app, check its Environment Variables, and try to restart it.

Variables to check are:

- DOCKER_REGISTRY_SERVER_URL
- DOCKER_REGISTRY_SERVER_USERNAME
- DOCKER_REGISTRY_SERVER_PASSWORD

If problem persists, go to WebApp Deployment Center, and make sure:

- The container registry is connected via Admin credentials
- The "Continuous Deployment" option is enabled

<br />
<p align="center">
<img src="../images/depl-image.png" width="800" />
</p>
<br/>

## Updating web app images

There are two ways to update the web app images:

- **Option 1**: Rebuilding from remote git repository
- **Option 2**: Rebuilding from local

### Option 1: Rebuilding from remote git repository

This is the recommended approach if you simply need to get the latest features and bug fixes.

1. Go to the Azure Portal and open a Cloud Shell (Bash)
1. Copy the `update_webapps_from_github.sh` script to the Cloud Shell
1. Run `chmod +x update_webapps_from_github.sh`
1. Run `./update_webapps_from_github.sh <resource-group-name>`

Please note images will be built and pushed to the container registry sequentially. This process will take about 10 minutes. Additionally, the script will restart the API WebApp to use the new images.

### Option 2: Rebuilding from local

This is the recommended way to update the images if you have made changes to the code, or if you chose not to build from the remote repository.

1. Clone the GitHub repository

    ```bash
    git clone https://github.com/Azure-Samples/multimodal-rag-code-execution

    cd multimodal-rag-code-execution
    ```

1. Make all required changes to the code
1. Run the `publish-aca.ps1` script using PowerShell (or `publish-webapp.ps1` in case of WebApps)

    ```powershell
    # Make sure to run from root of the repository
    .\deployment\publish-aca.ps1 -RG <resource-group-name>
    ```

    **NOTES**
    - script assumes you have the Azure CLI installed and logged in to the correct subscription
    - target resorce group must have been created by the deployment script
    - images will be built and pushed to the container registry sequentially. This process will take about 10 minutes.
    - All Container/Web Apps will restart to use the new images

## Local development

If you want to develop locally using resources you deployed, you must first create a Service Principal and assign it Contributor permissions on the resource group and AML Workspace. Otherwise the API won't have access to the AML Workspace.

Then, configure the following environment variables in a `.env` file:

```env
AML_PASSWORD=
AML_SERVICE_PRINCIPAL_ID=
AML_TENANT_ID=
```

You can use the `set-sp-secret.sh` script to create the SP and a secret with the right permissions (can be run in Cloud Shell):

```bash
./set-sp-secret.sh <sp-name> <resource-group-name>
```
