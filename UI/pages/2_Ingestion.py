import streamlit as st
import sys
import os
import json

from dotenv import load_dotenv
load_dotenv()

sys.path.append("../code")
from utils.cogsearch_rest import *
from itertools import groupby
import subprocess
import time
from aml_job import *
from doc_utils import *


import utils.cosmos_helpers as cs

ROOT_PATH_INGESTION = os.getenv("ROOT_PATH_INGESTION")
LOG_CONTAINER_NAME = os.getenv("COSMOS_LOG_CONTAINER")
DOCX_OPTIONS = os.getenv("DOCX_OPTIONS")
cosmos = cs.SCCosmosClient(container_name=LOG_CONTAINER_NAME)

if "log_entries" not in st.session_state:
    st.session_state.log_entries = []

if "files_ingested" not in st.session_state:
    st.session_state.files_ingested = {}

if "indexing" not in st.session_state:
    st.session_state.indexing = False

if "page_config" not in st.session_state:

    st.set_page_config(
        page_title="Multi RAG application",
        page_icon="🧊",
        layout="wide",
    )
    st.session_state.page_config = True


if "num_threads" not in st.session_state:
    st.session_state.num_threads = 1


#Main UI

retry = 0

st.title("Document(s) ingestion")
col1, col2 = st.columns(2)
pdf_extraction = col1.selectbox("PDF extraction:", ["Hybrid", "GPT 4 Vision", "Document Intelligence"] )

try:
    from docx import Document
    docx_extraction = col1.selectbox("Docx extraction:", ["Python-Docx", "Document Intelligence"] )
except:
    docx_extraction = col1.selectbox("Docx extraction:", ["Document Intelligence"] )

xlsx_extraction = col1.selectbox("Xlsx extraction:", ["OpenPyxl"] )

chunk_size = int(col1.text_input("Chunk Size:", '512'))
chunk_overlap = int(col1.text_input("Chunk Overlap:", '128'))

index_name = col2.text_input("Index name:", st.session_state.get('index_name', 'rag-data'))

available_models = len([1 for x in gpt4_models if x['AZURE_OPENAI_RESOURCE'] is not None])


# number_threads = col2.slider("Number of threads:", 1, 7, st.session_state.num_threads)
number_threads = col2.text_input("Number of threads:", available_models, disabled=True)
pdf_password = col2.text_input("PDF password:")
job_execution = col2.selectbox("Job Execution:", ["Azure Machine Learning", "Subprocess (Local Testing)"] )
uploaded_files = col2.file_uploader("Choose a file(s) :file_folder:", accept_multiple_files=True)

# Main UI
st.markdown("""---""")
st.session_state.num_threads = number_threads


st.write("## Ingestion")
col1 , col2 = st.columns([1, 1])
delete_ingestion_folder = col1.toggle("Delete ingestion folder")


start_ingestion = col1.button("Start ingestion")

download_directory =""
ingestion_directory = ""
ingestion_directory = os.path.join(ROOT_PATH_INGESTION , index_name) 
os.makedirs(ingestion_directory, exist_ok=True)
download_directory = os.path.join(ingestion_directory, 'downloads')
os.makedirs(download_directory, exist_ok=True)

col2.write(f":blue[Download directory:] :green[{download_directory}]")
col2.write(f":blue[Ingestion directory:] :green[{ingestion_directory}]")
col2.write(f":blue[Index name:] :green[{index_name}]")

for uploaded_file in uploaded_files :
    #Use the file here. For example, you can read it:
    if uploaded_file.name.replace(" ", "_") in st.session_state.files_ingested: continue
    with open(os.path.join(download_directory, uploaded_file.name), "wb") as f:
        f.write(uploaded_file.getvalue())
    os.rename(os.path.join(download_directory, uploaded_file.name), os.path.join(download_directory, uploaded_file.name.replace(" ", "_")))      
    st.session_state.files_ingested[uploaded_file.name.replace(" ", "_")] = "Not ingested"


bar_progress = st.progress(0, text="Please click on ingestion to start the process")

files_status = st.empty()
st.markdown("""---""")

# Placeholder for log entries
st.write("### Status Log - 0.0.3")

log_placeholder = st.empty()


#check the Azure Cognitive index for the number of documents indexed
def check_index_status(index_name):
    index = CogSearchRestAPI(index_name)
    if index.get_index() is not None:
        documents = index.get_documents()
        #aggregate the documents by the pdf_path
        documents.sort(key=lambda x: x['filename'])
        grouped_documents = {k: list(v) for k, v in groupby(documents, key=lambda x: x['filename'])}
        for filename, docs in grouped_documents.items():
            append_log_message(f":blue[Filename:] {filename} Index as :blue[Number of documents:] {len(docs)}")  
       

def append_log_message(message, text=None):
    # Append new message to the session state list of log entries
    st.session_state.log_entries.append(message)
    log_placeholder.markdown('  \n'.join(st.session_state.log_entries))

def update_file_status():
    files_status_messages = []
    for file, status in st.session_state.files_ingested.items():
        if status == "Ingesting...":
            files_status_messages.append(f":blue[File:] {file} :orange[{status}] ")
        elif status == "Ingested":
            files_status_messages.append(f":blue[File:] {file} :green[{status}] ")
        else:
            files_status_messages.append(f":blue[File:] {file} :red[{status}] ")
    files_status.markdown('  \n'.join(files_status_messages))



def check_if_indexing_in_progress():
    try:
        #f there is a document with that name, means indexing is still happening
        document = cosmos.read_document(index_name, index_name)
        if document is not None:
            file_status = [ x['status'] for x in document['files_uploaded']]

            if 'Ingesting...' in file_status:
                st.session_state.warning = st.sidebar.warning("Indexing in progress. Please wait for the current process to complete.")
                st.session_state.indexing = True  
            else:
                st.session_state.indexing = False                
        else:
            st.session_state.indexing = False        
       
    except Exception as e:
        st.session_state.warning = st.sidebar.warning(f"Error getting log document: {e}")


def update_file_list_UI(do_sleep = False):
    global retry
    document = cosmos.read_document(index_name,index_name)
    if (document is None):
        retry = retry + 1
        time.sleep(1) # sometimes this process start before the document is commited into Cosmos DB
        if (retry > 60):
            st.sidebar.error("There was an issue with the indexing process, please check the logs")
            st.session_state.indexing = False
    else:
        st.session_state.files_ingested = {}
        processed_files = 0
        processing_files = 0
        total_files = 0
        files = document['files_uploaded']
        logs = document['log_entries']
        for file in files:
            total_files += 1
            if file['status'] == 'Ingested':
                st.session_state.files_ingested[file['file_name']] = "Ingested"
                processed_files += 1
                processing_files += 1
            elif file['status'] == 'Ingesting...':
                st.session_state.files_ingested[file['file_name']] = "Ingesting..."
                processing_files += 1
            else:
                st.session_state.files_ingested[file['file_name']] = "Not Ingested"
        update_file_status()
        log_placeholder.markdown('  \n'.join(logs))
        bar_progress.progress((processing_files)/(total_files+1), text=f"Ingesting {processing_files} / {total_files}")

        if (processed_files == total_files) and (total_files > 0):
            st.session_state.indexing = False
            bar_progress.progress(100, text="Ingestion complete")
            check_index_status(index_name)
            append_log_message("Ingestion complete.")
            try:
                st.session_state.warning.empty()
            except:
                pass
        else:
            if do_sleep: time.sleep(5)


if index_name:
    check_if_indexing_in_progress()
    update_file_list_UI()

if start_ingestion:
    
    if (st.session_state.indexing):
        st.session_state.warning = st.sidebar.warning("Indexing in progress. Please wait for the current process to complete.")
    else:
        st.session_state.log_entries = []

        pending_files = []
        try: 
            document = cosmos.read_document(index_name, index_name)
            if document is not None:
                 pending_files = [x['file_name'] for x in document['files_uploaded'] if (x['status'] == 'Not ingested') or (x['status'] == 'Ingesting...')]
                 print("Pending files: ", pending_files)
        except Exception as e:
            print("Error getting log document: ", e)
        

        if (len(uploaded_files) == 0) and (len(pending_files) == 0):
            st.session_state.warning = st.sidebar.warning("No files uploaded")
        else:
            st.session_state.indexing = True
            if pdf_extraction == "GPT 4 Vision":
                pdf_extraction_option = 'gpt-4-vision'
            elif pdf_extraction == "Document Intelligence":
                pdf_extraction_option = 'document-intelligence'
            elif pdf_extraction == "Hybrid":
                pdf_extraction_option = 'hybrid'                
            else:
                pdf_extraction_option = 'document-intelligence'

            if docx_extraction == "Document Intelligence":
                docx_extraction_option = 'document-intelligence'
            elif docx_extraction == "Python-Docx":
                docx_extraction_option = 'py-docx'
            else:
                docx_extraction_option = 'document-intelligence'

            if xlsx_extraction is None:
                xlsx_extraction_option = 'openpyxl'
            elif xlsx_extraction == "OpenPyxl":
                xlsx_extraction_option = 'openpyxl'
            else:
                xlsx_extraction_option = 'openpyxl'

            ingestion_params_dict = {
                "download_directory" : download_directory,
                "ingestion_directory" : ingestion_directory,
                "index_name" : index_name,
                'num_threads' : available_models,
                "password" : pdf_password,
                "delete_existing_output_dir" : delete_ingestion_folder,
                "processing_mode_pdf" : pdf_extraction_option,
                "processing_mode_docx" : docx_extraction_option,
                'processing_mode_xlsx' : xlsx_extraction_option,
                'models': gpt4_models,
                'vision_models': gpt4_models,
                'chunk_size': int(chunk_size),
                'chunk_overlap': int(chunk_overlap),
                'verbose': True
            }


            if job_execution == "Azure Machine Learning":
                print("Current working directory:", os.path.abspath(os.getcwd()))
                print("ROOT_PATH_INGESTION:", ROOT_PATH_INGESTION)

                st.write(f"Current working directory: {os.path.abspath(os.getcwd())}")
                st.write(f"ROOT_PATH_INGESTION: {ROOT_PATH_INGESTION}")

                st.write(f"\n\nCWD Files: {os.listdir(os.getcwd())}")
                st.write(f"ROOT_PATH_INGESTION Files: {os.listdir(ROOT_PATH_INGESTION)}")
                st.write(f"Root Path Files: {os.listdir('./')}\n\n")
                


                job = AmlJob()
                job.submit_ingestion_job(ingestion_params_dict, script = 'ingest_doc.py', source_directory='./code')
            
            elif job_execution == "Subprocess (Local Testing)":
                subprocess.Popen(["python", "../code/utils/ingest_doc.py", 
                                "--ingestion_params_dict", json.dumps(ingestion_params_dict),
                                ])
            else:
                st.session_state.warning = st.sidebar.warning("This Job Execution mode is not supported yet.")

    

while st.session_state.indexing:
    update_file_list_UI(do_sleep = True)
    



