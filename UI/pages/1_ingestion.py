import streamlit as st
import sys
import os

from dotenv import load_dotenv
load_dotenv()

sys.path.append("../code")
from utils.cogsearch_rest import *
from itertools import groupby
import subprocess
import time

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
    
#Main UI
st.title("Document(s) ingestion")
col1, col2 = st.columns(2)
pdf_extraction = col1.selectbox("PDF extraction:", ["GPT 4 Vision", "Doc Intelligence"] )

if (DOCX_OPTIONS == "True"):
    docx_extraction = col1.selectbox("Docx extraction:", ["pyDoc", "Doc Intelligence"] )

index_name = col2.text_input("Index name:", st.session_state.get('index_name', 'rag-data'))

number_threads = 1 # col2.slider("Number of threads:",1,4,1)
pdf_password = col2.text_input("PDF password:")
uploaded_files = col2.file_uploader("Choose a file(s) :file_folder:", accept_multiple_files=True)

# Main UI
st.markdown("""---""")


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
    with open(os.path.join(download_directory, uploaded_file.name), "wb") as f:
        f.write(uploaded_file.getvalue())
    st.session_state.files_ingested[uploaded_file.name] = "Not ingested"


bar_progress = st.progress(0, text="Please click on ingestion to start the process")

files_status = st.empty()
st.markdown("""---""")

# Placeholder for log entries
st.write("### Status Log")

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
            st.sidebar.warning("Indexing in progress. Please wait for the current process to complete.")
            st.session_state.indexing = True  
        else:
            st.session_state.indexing = False        
       
    except Exception as e:
        st.sidebar.warning(f"Error getting log document: {e}")


     
if index_name:
    check_if_indexing_in_progress()

if start_ingestion:
    
    if (st.session_state.indexing):
        st.sidebar.warning("Indexing in progress. Please wait for the current process to complete.")
    else:
        st.session_state.log_entries = []
        if len(uploaded_files) == 0:
            st.sidebar.warning("No files uploaded")
        else:
            st.session_state.indexing = True
            if pdf_extraction == "GPT 4 Vision":
                pdf_extraction_option = "gpt4_vision"
            else:
                pdf_extraction_option = "doc_intelligence"

            if docx_extraction is None:
                docx_extraction_option = "doc_intelligence"
            elif docx_extraction == "pyDoc":
                docx_extraction_option = "pydoc"
            else:
                docx_extraction_option = "doc_intelligence"
            subprocess.Popen(["python", "../code/utils/ingest_doc.py", 
                            "--download_directory", download_directory,
                            "--ingestion_directory", ingestion_directory,
                            "--pdf_extraction", pdf_extraction_option,
                            "--docx_extraction", docx_extraction_option,
                            "--text_from_images", str(True),
                            "--index_name", index_name,
                            "--number_threads", str(number_threads),
                            "--pdf_password", pdf_password,
                            "--delete_ingestion_folder", str(delete_ingestion_folder)])

    
retry = 0
while st.session_state.indexing:
    document = cosmos.read_document(index_name,index_name)
    if (document is None):
        retry = retry + 1
        time.sleep(5) # sometimes this process start before the document is commited into Cosmos DB
        if (retry > 5):
            st.sidebar.error("There was an issue with the indexing process, please check the logs")
            st.session_state.indexing = False
    else:
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

        if (processed_files == total_files):
            st.session_state.indexing = False
            bar_progress.progress(100, text="Ingestion complete")
            check_index_status(index_name)
            append_log_message("Ingestion complete.")
        else:
            time.sleep(5)
    



