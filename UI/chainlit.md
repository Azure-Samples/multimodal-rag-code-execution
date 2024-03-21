# Welcome to the Research CoPilot

This document outlines the primary commands and options available in the testing tool for the Research CoPilot solution.

| **Command**           | **Usage**                                                                                       |
|:--------------------- |:------------------------------------------------------------------------------------------------|
| **cmd index**         | Type `cmd index` to change the name of the AI Search index.                                     |
| **cmd password**      | Type `cmd password` to change the PDF password (if PDFs are password-protected).                |
| **cmd text_processing** | Type `cmd text_processing` to change the text post-processing mode. Allowed values are "PDF" or "GPT".   |
| **cmd image_detection** | Type `cmd image_detection` to change the images detection and extraction mode.  Allowed values are "PDF" or "GPT".   |
| **cmd OCR**           | Type `cmd OCR` to enable or disable text extraction from images. Allowed values "True" or "False".     |
| **cmd threads**       | Type `cmd threads` to change the number of threads. Allows for multi-threading during ingestion. Make sure that AZURE_OPENAI_RESOURCE_x and AZURE_OPENAI_KEY_x are properly configured in your .env file.     |
| **cmd delete_dir**    | Type `cmd delete_dir` to enable or disable deleting existing output directory if ingestion is restarted.                  |
| **cmd code_interpreter**    | Type `cmd delete_dir` to change the used Code Interpreter. Allowed values are "NoComputationTextOnly", "Taskweaver", "AssistantsAPI", or "LocalPythonExec".                  |
| **cmd upload**        | Type `cmd upload` to upload document files for ingestion.                                        |
| **cmd ingest**        | Type `cmd ingest` to start the ingestion process of the uploaded files.                         |
| **cmd prompts**        | Type `cmd prompts` to display all available generation prompts.                                |
| **cmd gen**           | Type `cmd gen` to generate from pre-existing prompts.                                             |
| **Query**             | Type your query in plain English and wait for the response.                                     |