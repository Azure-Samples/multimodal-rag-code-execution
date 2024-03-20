import streamlit as st
import sys
import os

from dotenv import load_dotenv
load_dotenv()

sys.path.append("../code")
from utils.cogsearch_rest import *
from itertools import groupby


import doc_utils
from doc_utils import ingest_doc, log_ui_func_hook, logc
import os

ROOT_PATH_INGESTION = os.getenv("ROOT_PATH_INGESTION")

log_entries = []
files_ingested = {}
import streamlit as st

if "page_config" not in st.session_state:

    st.set_page_config(
        page_title="Multi RAG application",
        page_icon="🧊",
        layout="wide",
    )
    st.session_state.page_config = True
    
#Main UI
st.title("Document ingestion and indexing")
col1, col2 = st.columns(2)
col1.write("## Extraction modes")
text_extraction = col1.selectbox("Text extraction:", ["GPT", "PDF"] )

image_extraction = col1.selectbox("Image extraction:", ["GPT", "PDF"] )

text_from_images = col1.toggle("Extract text from images")

col2.write("## Indexing options")

index_name = col2.text_input("Index name:", st.session_state.get('index_name', 'blackrock'))
st.session_state['index_name'] = index_name

number_threads = col2.slider("Number of threads:",1,10,1)
pdf_password = col2.text_input("PDF password:")
uploaded_files = col2.file_uploader("Choose a file(s) :file_folder:", accept_multiple_files=True)

# Main UI
st.markdown("""---""")


st.write("## Ingestion")
col1 , col2 = st.columns([1, 1])
delet_ingestion_folder = col1.toggle("Delete ingestion folder")


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
    files_ingested[uploaded_file.name] = "Not ingested"


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
        documents = index.get_documents();
        print(f"Number of documents indexed: {len(documents)}")
        #aggregate the documents by the pdf_path
        documents.sort(key=lambda x: x['filename'])
        grouped_documents = {k: list(v) for k, v in groupby(documents, key=lambda x: x['filename'])}
        for filename, docs in grouped_documents.items():
            append_log_message(f":blue[Filename:] {filename} Index as :blue[Number of documents:] {len(docs)}")  
       

def append_log_message(message, text=None):
    # Append new message to the session state list of log entries
    log_entries.append(message)
    # Display all log entries from the session state
    log_placeholder.markdown('  \n'.join(log_entries))

def update_file_status():
    files_status_messages = []
    for file, status in files_ingested.items():
        if status == "Ingesting...":
            files_status_messages.append(f":blue[File:] {file} :orange[{status}] ")
        elif status == "Ingested":
            files_status_messages.append(f":blue[File:] {file} :green[{status}] ")
        else:
            files_status_messages.append(f":blue[File:] {file} :red[{status}] ")
    files_status.markdown('  \n'.join(files_status_messages))

doc_utils.log_ui_func_hook = append_log_message



if start_ingestion:
    if len(uploaded_files) == 0:
        logc("No files uploaded")
        st.stop()
    append_log_message(f"Thread numbers: {number_threads}")
    append_log_message("Ingestion started")
    processed_files = 0
    for root, dirs, files in os.walk(download_directory):

        for file in files:
            # Check if the file is a PDF
            if file.lower().endswith('.pdf'):
                # Construct the full file path
                append_log_message(f"Processing file: {file}")
                processed_files += 1
                files_ingested[file] = "Ingesting..."
                update_file_status()

                bar_progress.progress((processed_files)/(len(uploaded_files)+1), text=f"Ingesting {file} ({processed_files} / {len(uploaded_files)})")
                file_path = os.path.join(root, file)
                # Call ingest_doc on the file
                ingest_doc(
                    file_path, ingestion_directory=ingestion_directory, 
                    extract_text_mode=text_extraction,
                    extract_images_mode=image_extraction,
                    extract_text_from_images=text_from_images,
                    index_name=index_name,
                    num_threads=number_threads,
                    password=pdf_password,
                    delete_existing_output_dir=delet_ingestion_folder)
                
                append_log_message(f":green[File processed: {file}]")
                files_ingested[file] = "Ingested"
                update_file_status()
    bar_progress.progress(100, text="Ingestion complete")
    check_index_status(index_name)
    append_log_message("Ingestion complete.")




