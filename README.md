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


## Important Findings

1. GPT-4-Turbo is a great help with its large 128k token window
1. GPT-4-Turbo with Vision is great at extracting tables from unstructured document formats
1. GPT-4 models can understand a wide variety of formats (Python, Markdown, Mermaid, GraphViz DOT, etc..) which was essential in maximizing  information extraction
1. A new approach to vector index searching based on tags was needed because the Generation Prompts were very lengthy compared to the usual user queries
1. Taskweaver’s and Assistants API’s Code Interpreters were introduced to conduct open-ended analytics questions

<br/>
<br/>


# Enterprise Deployment

Please check our [Enterprise Deployment](ENTERPRISE_DEPLOYMENT.md) guide for how to deploy this in a secure manner to a client's tenant. For local development testing, please use the tutorial notebooks or the Chainlit app described below.

<br/>
<br/>




# Tutorial Notebooks

Please start with the Tutorial notebooks [here](tutorials/). These notebooks illustrate a series of concepts that have been used in this repo. 



<br/>
<br/>


# Running the Chainlit Web App

To run the web app locally, please execute in your conda environment the following:
```bash
# cd into the app folder
cd app

# run the chainlit app
chainlit run test-app.py
```
<br/>


### Guide to use the Chainlit Web App

1. Configure properly your `.env` file. Refer to the `.env.sample` file included in this solution.
1. Use `cmd index` to set the index name and the ingestion directory.
1. Use `cmd upload` to upload the documents you need ingestion. As of today, this solution works **ONLY** with PDF files.
1. If the document(s) is/are large, then you can try multi-threading, by using `cmd threads`. This will use multiple Azure OpenAI resources in multiple regions to speed up the ingestion ofthe document(s).
1. Use `cmd ingest` to start the ingestion process. Please wait until the process is complete and confirmation that the document has been ingested is printed.
1. Try different settings. For example, if this is a clean digital PDF (e.g. MS Word document saved as PDF), then for `text_processing` and `image_detection`, it is ok to leave their values as `PDF`. However, if this is a PDF of a Powerpoint presentation with lots of vector graphics in it, it's recommended that both of these settings are set to `GPT`, along with setting `OCR` to `True`.
1. Then type any query in the input field which will search the field. Choose your Code Interpreter, either `Taskweaver` or `AssistantsAPI`.



<br/>

<br/>

## Code Interpreters

Code Interpreters Available in this Solution:
1. Assistants API: It is the default code interpreter. OpenAI AssistantsAPI is supported for now. The Azure version will soon follow when it's released.
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

