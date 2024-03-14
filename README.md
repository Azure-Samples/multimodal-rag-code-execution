# Research CoPilot: Multimodal RAG with Code Execution

Multimodal Document Analysis with RAG and Code Execution: using Text, Images and Data Tables with GPT4-V, TaskWeaver, and Assistants API:

## Features
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


# Solution Stages

This solution implements a three-stage process: 
1. Ingestion stage for extracting data
1. Search stage for enabling search capabilities with code execution, and (3)
1. Generation stage for creating custom-tailored outputs such as business or industry overviews.


<br />

## Getting Started

### Prerequisites

(ideally very short, if any)

- OS
- Library version
- ...

### Installation

(ideally very short)

- npm install [package name]
- mvn install
- ...

### Quickstart
(Add steps to get up and running quickly)

1. git clone [repository clone url]
2. cd [repository name]
3. ...


## Demo

A demo app is included to show how to use the project.

To run the demo, follow these steps:

(Add steps to start up the demo)

1.
2.
3.

## Resources

(Any additional resources or related projects)

- Link to supporting information
- Link to similar sample
- ...
