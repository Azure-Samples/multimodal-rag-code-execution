> **Note:**
> Start with the Tutorial Notebooks in the Tutorials folder [here](tutorials/). 


<br/>

# Research CoPilot: Multimodal RAG with Code Execution
Multimodal Document Analysis with RAG and Code Execution: using Text, Images and Data Tables with GPT4-V, TaskWeaver, and Assistants API:


1. The work focuses on processing multi-modal analytical documents by extracting text, images, and data tables to maximize data representation and information extraction, utilizing formats like Python code, Markdown, and Mermaid script for compatibility with GPT-4 models.
1. Text is programmatically extracted from documents, processed to improve structure and tag extraction for better searchability, and numerical data is captured through generated Python code for later use.
1. Images and data tables are processed to generate multiple text-based representations (including detailed text descriptions, Mermaid, and Python code for images, and various formats for tables) to ensure information is searchable and usable for calculations, forecasts, and applying machine learning models using Code Interpreter capabilities.


<br/>

## Current Challenges
1. As of today with conventional techniques, to be able to search through a knowledge base with RAG, text from documents need to be extracted, chunked and stored in a vector database
1. This process now is purely concerned with text: 
    * If the documents have any images, graphs or tables, these elements are usually either ignored or extracted as messy unstructured text
    * Retrieving unstructured table data through RAG will lead to very low accuracy answers
1. LLMs are usually very bad with numbers. If the query requires any sort of calculations, LLMs usually hallucinate or make basic math mistakes


<br/>

## Why do we need this solution?

1. Ingest and interact with multi-modal analytics documents with lots of graphs, numbers and tables
1. Extract structured information from some elements in documents which wasn’t possible before:
    * Images
    * Graphs
    * Tables
1. Use the Code Interpreter to formulate answers where calculations are needed based on search results 


<br/>


## Examples of Industry Applications

1. Analyze Investment opportunity documents for Private Equity deals
1. Analyze tables from tax documents for audit purposes
1. Analyze financial statements and perform initial computations
1. Analyze and interact with multi-modal Manufacturing documents 
1. Process academic and research papers
1. Ingest and interact with textbooks, manuals and guides
1. Analyze traffic and city planning documents 

<br/>
<br/>

# Solution Features

The following are technical features implemented as part of this solution:

1. Supported file formats are PDFs, MS Word documents, MS Excel sheets, and csv files. 
1. Ingestion of multimodal documents including images and tables
1. Ingestion jobs run on Azure Machine Learning for reliable long-duration execution and monitoring
1. Full deployment script that will create the solution components on Azure and build the docker images for the web apps
1. Hybrid search with AI Search using vector and keyword search, and semantic re-ranker
1. Extraction of chunk-level tags and whole-document-level chunks to optimize keyword search
1. Whole document summaries used as part of the final search prompt to give extra context 
1. Code Execution with the OpenAI Assistants API Code Interpreter
1. Tag-based Search for optimizing really long user query, e.g. Generation Prompts
1. Modular and easy-to-use interface with Processors for customizable processing pipelines
1. Smart chunking of Markdown tables with repeatable header and table summary in every chunk
1. Support for the two new embedding models `text-embedding-3-small` and `text-embedding-3-large`, as well as for `text-embedding-ada-002`


## In-the-Works Upcoming Features

1. Dynamic semantic chunking with approximate fixed size chunks (soon)
1. Graph DB support for enhanced data retrieval. The Graph DB will complement, and not replace, the AI Search resource.


<br/>

## Solution Architecture

The below is the logical architecture of this solution. The GraphDB is not yet added to the solution, but the integration is currently in development: 

<br />
<p align="center">
<img src="images/arch.png" width="800" />
</p>
<br/>

<br/>



## Important Findings

1. GPT-4-Turbo is a great help with its large 128k token window
1. GPT-4-Turbo with Vision is great at extracting tables from unstructured document formats
1. GPT-4 models can understand a wide variety of formats (Python, Markdown, Mermaid, GraphViz DOT, etc..) which was essential in maximizing  information extraction
1. A new approach to vector index searching based on tags was needed because the Generation Prompts were very lengthy compared to the usual user queries
1. Taskweaver’s and Assistants API’s Code Interpreters were introduced to conduct open-ended analytics questions

<br/>
<br/>


# Enterprise Deployment

Please check our [Enterprise Deployment](ENTERPRISE_DEPLOYMENT.md) guide for how to deploy this in a secure manner to a client's tenant. For local development or testing the solution, please use the tutorial notebooks or the Chainlit app described below.

<br/>
<br/>




# Tutorial Notebooks

Please start with the Tutorial notebooks [here](tutorials/). These notebooks illustrate a series of concepts that have been used in this repo. 



<br/>
<br/>


# How to Use this Solution

There are two web apps that are implemented as part of this solution. The Streamlit web app and the Chainlit web app.

1. The Streamlit web app includes the following: 
    * The web app can ingest documents, which will create an ingestion job either using Azure Machine Learning (recommended) or using a Python sub-process on the web app itself (for local testing only). 
    * The second part of the Streamlit app is Generation. The "Prompt Management" view will enable the user to build complex prompts with sub-sections, save them to Cosmos, and use the solution to generate output based on these prompts
1. The Chainlit web app is used to chat with the ingested documents, and has advanced functionality, such as an audit trail for the search, and references section for the answer with multimodal support (images and tables can be viewed).

<br/>


## Prepare the local Conda Environment

The Conda environment can be installed by running the following commands from the **project root folder**. Please follow the below commands to create a **new** conda environment. The Python version can be >= 3.10 (but was thoroughly tested on 3.10):

```bash
# create the conda environment
conda create -n mmdoc python=3.10

# activate the conda environment
conda activate mmdoc

# install the project requirements
pip install -r requirements.txt
```

## Prepare the .env File 

Configure properly your `.env` file. Refer to the `.env.sample` file included in this solution. All non-optional values must be filled in, in order for this solution to function properly.

The .env file is used for:

1. Local Development if needed
1. The deployment script will read values from the `.env` file and will population the Configuration Variables for both web apps. 

<br/>


## Running the Chainlit Web App

The Chainlit web app is the main web app to chat with your data. To run the web app locally, please execute in your conda environment the following:

```bash
# cd into the ui folder
cd ui

# run the chainlit app
chainlit run chat.py
```
<br/>



## Running the Streamlit Web App

The Streamlit web app is the main web app to ingest your documents and to build prompts for Generation. To run the web app locally, please execute in your conda environment the following:

```bash
# cd into the ui folder
cd ui

# run the chainlit app
streamlit run main.py
```
<br/>


### Guide to configure the Chainlit and Streamlit Web Apps

1. Configure properly your `.env` file. Refer to the `.env.sample` file included in this solution.
1. In the Chainlit web app, use `cmd index` to set the index name.


<br/>
<br/>


## Deploying on Azure

We are currently building an ARM template for a one-click deployment. In the meantime, please use the below script to deploy on the Azure cloud. Please make sure to fill in your `.env` file properly **before** running the deployment script. The below script has to run in a `Git Bash` shell, and will not run in Powershell bash. Visit the deployment [Section](https://github.com/Azure-Samples/multimodal-rag-code-execution/blob/main/deployment/README.md) here to get detailed instructions and advance deployment options. 

```bash
# cd into the deployment folder
cd deployment

# run the deployment script
./deploy_public.sh
```



<br/>
<br/>

### Local Development for Azure Cloud

For rapid development iterations and for testing on the cloud, the `push.ps1` script can be used to build only the docker images and push them to the Azure Container Registry, without creating or changing any other component in the resource group or in the architecture. The docker images will have then to be **manually** assigned to the web app, by going to the web app page in the Azure Portal, and then navigate to `Deployment > Deployment Center` on the left-hand side, and then go to `Settings` on the right-hand side, then to the `Tag` dropdown and choose the correct docker image. 

Please edit the `push.ps1` script, and fill in the right values for the Azure Container Registry endpoint, username and password, for the Resource Group name, and Subscription ID. Then, to run the script, follow the below instrcutions in a `Powershell`. It is important that Docker Desktop version is installed and running at that point locally. The command has to be run from the root directory of the project: 

```bash
# cd into the root folder of the project
cd <project root>

# run the docker images update script
deployment/push.ps1
```
 
<br />
<p align="center">
<img src="images/pushacr.png" width="800" />
</p>
<br/>


<br/>

## Code Interpreters

Code Interpreters Available in this Solution:
1. Assistants API: OpenAI AssistantsAPI is the default out-of-the-box code interpreter for this solution running on Azure.
1. Taskweaver: is optional to install and use, and is fully supported


<br/>

<br/>

## Taskweaver Installation (optional)


TaskWeaver requires **Python >= 3.10**. It can be installed by running the following command from the project root folder. Please follow the below commands **very carefully** and start by creating a **new** conda environment:

```bash
# create the conda environment
conda create -n mmdoc python=3.10

# activate the conda environment
conda activate mmdoc

# install the project requirements
pip install -r requirements.txt

# clone the repository
git clone https://github.com/microsoft/TaskWeaver.git

# cd into Taskweaver
cd TaskWeaver

# install the Taskweaver requirements
pip install -r requirements.txt

# copy the Taskweaver project directory into the root folder and name it 'test_project'
cp -r project ../test_project/

```

<br/>


> **Note:**
> Inside the `test_project` directory, there's a file called `taskweaver_config.json` which needs to be populated. Please refer to the `taskweaver_config.sample.json` file in the root folder of this repo, fill in the Azure OpenAI model values for GPT-4-Turbo, rename it to `taskweaver_config.json`, and then copy it inside `test_project` (or overwrite existing).

<br/>

> **Note:**
> Similiarly, there are a number of test notebooks in this solution that use Autogen. If the user wants to experiment with Autogen, then in this case, the file `OAI_CONFIG_LIST` in the `code` folder needs to be configured. Please refer to `OAI_CONFIG_LIST.sample`, populate it with the right values, and then rename it to `OAI_CONFIG_LIST`.

