import streamlit as st
import sys
import os
import json
import requests
import logging
import subprocess
import time

from itertools import groupby
from dotenv import load_dotenv
load_dotenv()

sys.path.append("../code")

from env_vars import INITIAL_INDEX

class APIClient:
    def __init__(self):
        self.base_url = os.getenv("API_BASE_URL")
        
    def get_processing_plan(self):
        return requests.get(f"{self.base_url}/processing_plan").json()
    
    def get_models(self):
        return requests.get(f"{self.base_url}/models").json()
    
    def upload_files(self, index_name, files):
        return requests.post(f"{self.base_url}/index/{index_name}/upload_files", files=files)
    
    def get_existing_files(self, index_name):
        return requests.get(f"{self.base_url}/index/{index_name}/files").json()
    
    def get_index_documents(self, index_name):
        return requests.get(f"{self.base_url}/index/{index_name}/documents").json()
    
    def get_index_status(self, index_name):
        return requests.get(f"{self.base_url}/index/{index_name}/status").json()
    
    def update_index_status(self, index_name, status):
        return requests.post("/index/{index_name}/status", json={"status": status}).json()
    
    def get_index_log(self, index_name):
        return requests.get(f"{self.base_url}/index/{index_name}/log").json()
    
    def copy_processing_plan_to_index(self, index_name):
        return requests.post(f"{self.base_url}/index/{index_name}/plan").json()
    
    def clear_indexing_status(self, index_name):
        return requests.delete(f"{self.base_url}/index/{index_name}/status").json()
    
    def submit_ingestion_job(self, index_name, ingestion_params_dict):
        return requests.post(f"{self.base_url}/index/{index_name}/job", json=ingestion_params_dict).json()
    
    def get_job_status(self, job_id):
        return requests.get(f"{self.base_url}/job/{job_id}/status").json()
    
api_client = APIClient()

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

if "proc_plans" not in st.session_state:
    st.session_state.proc_plans = api_client.get_processing_plan()

if "process" not in st.session_state:
    st.session_state.process = None

if "job_status" not in st.session_state:
    st.session_state.job_status = ''

if "warning" not in st.session_state:
    st.session_state.warning = st.empty()


def log_message(message, level):
    if level == 'debug':
        logging.debug(message)
    elif level == 'info':
        logging.info(message)
    elif level == 'warning':
        logging.warning(message)
    elif level == 'error':
        logging.error(message)
    elif level == 'critical':
        logging.critical(message)
    else:
        logging.info('Invalid log level, defaulting to info')
        logging.info(message)

#Main UI

retry = 0

st.title("Document Ingestion - v.1.0.2")
col1, col2 = st.columns(2)

hybrid_label = "Hybrid (choose if pptx file is tidy - default option)"
gpt4v_label = "GPT 4 Vision (choose if pptx is very messy, or pdf is scanned)"
docint_label_pdf = "Document Intelligence (choose if this pdf is saved from docx)"
docint_label_docx = "Document Intelligence"

pdf_extraction = col1.selectbox("PDF extraction:", [hybrid_label, gpt4v_label, docint_label_pdf] )

try:
    docx_extraction = col1.selectbox("Docx extraction:", [docint_label_docx, "Python-Docx"] )
except:
    docx_extraction = col1.selectbox("Docx extraction:", [docint_label_docx] )

xlsx_extraction = col1.selectbox("Xlsx extraction:", ["OpenPyxl"] )

chunk_size = int(col1.text_input("Chunk Size:", '800'))
chunk_overlap = int(col1.text_input("Chunk Overlap:", '128'))

index_name = col2.text_input("Index name:", st.session_state.get('index_name', INITIAL_INDEX))
index_name = index_name.strip()

gpt4_models = api_client.get_models()
available_models = len([1 for x in gpt4_models if x['AZURE_OPENAI_RESOURCE'] is not None])


# number_threads = col2.slider("Number of threads:", 1, available_models, available_models)
number_threads = col2.text_input("Number of threads:", available_models, disabled=True)
pdf_password = col2.text_input("PDF password:")
job_execution = col2.selectbox("Job Execution:", ["Azure Machine Learning", "Subprocess (Local Testing)"] )
uploaded_files = col2.file_uploader("Choose a file(s) :file_folder:", accept_multiple_files=True)


st.session_state.num_threads = number_threads

def proc_plan_chance():
    st.session_state.proc_plans = st.session_state.processingPlansKey 
    log_message("Processing Plans Changed: ", st.session_state.proc_plans)

st.text_area("Processing Plans (Leave as Default - no need to change)", value=st.session_state.proc_plans, height=150, key="processingPlansKey", on_change=proc_plan_chance) 

# Main UI
st.markdown("""---""")
st.write("## Ingestion")
col1 , col2 = st.columns([1, 1])
delcol, proc_plan_col = col1.columns([1, 1])
delete_ingestion_folder = delcol.toggle("Delete Ingestion Folder")
copy_proc_plan = proc_plan_col.toggle("Copy Processing Plan", value=True)

ingest_col, clear_col, spinner_col = col1.columns([1, 1, 1])

start_ingestion = ingest_col.button("Start Ingestion")
clear_ingestion = clear_col.button("Clear Ingesting")
refresh = spinner_col.button("Refresh")

col2.write(f":blue[Index name:] :green[{index_name}]")
# col2.text(f":blue[Job Status:] :green[{st.session_state.job_status}]")

existing_file_names = api_client.get_existing_files(index_name)


## COPY UPLOADED FILES TO THE DOWNLOAD DIRECTORY AND RENAME THEM
# for uploaded_file in uploaded_files :
#     log_message("Uploaded Files -- before processing", uploaded_files)
#     #Use the file here. For example, you can read it:
#     if uploaded_file.name.replace(" ", "_") in st.session_state.files_ingested: continue

#     new_name = os.path.join(download_directory, uploaded_file.name.replace(" ", "_"))
#     old_name = os.path.join(download_directory, uploaded_file.name)

#     if not os.path.exists(new_name):
#         with open(os.path.join(download_directory, uploaded_file.name), "wb") as f:
#             f.write(uploaded_file.getvalue())

#         try:
#             os.rename(old_name, new_name)      
#         except Exception as e:
#             log_message(f"Error renaming file to {new_name}. Most likely a problem with permissions accessing the downloads folder {download_directory}.\nException:\n{e}")

#     st.session_state.files_ingested[uploaded_file.name.replace(" ", "_")] = "Not ingested"
#     log_message("st.session_state.files_ingested", st.session_state.files_ingested)

file_to_upload = []
for uploaded_file in uploaded_files:
    file = uploaded_file.getvalue()
    file_to_upload.append(('file', (uploaded_file.name, file, uploaded_file.type)))
    
api_client.upload_files(index_name, file_to_upload)


bar_progress = st.progress(0, text="Please click on ingestion to start the process")

files_status = st.empty()
st.markdown("""---""")

# Placeholder for log entries
st.write("### Status Log")

log_placeholder = st.empty()

# check the Azure Cognitive index for the number of documents indexed
def check_index_status(index_name, download_directory):
    documents = api_client.get_index_documents(index_name)
    if documents is not None:
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
    log_message("check_if_indexing_in_progress")
    try:
        if "aml_job_id" not in st.session_state:
                st.session_state.aml_job_id = None

        st.session_state.indexing, document = api_client.get_index_status(index_name)
        # log_message("Document", document, "Indexing State", st.session_state.indexing)

        if document is not None:
            job_id = document.get('job_id', '')
            job_status = document.get('job_status', '')
            log_message("\n\nJob ID Found in Cosmos", job_id, "\n\n")

            if (job_id != '') and (job_status == 'running'):
                try:    
                    status = api_client.get_job_status(st.session_state.aml_job_id)
                    log_message(f"Checking Run_ID: {job_id}, status {status}")

                    if status not in ["Completed", "Failed", "Canceled"]:
                        st.session_state.job_status = f"AML Job is: {status}"
                        st.session_state.warning = st.sidebar.info(f"AML Job is: {status}", icon="ℹ️")
                    else:
                        st.session_state.indexing = False
                        update_file_list_UI(do_check_job_status=False)
                        api_client.update_index_status(index_name, "not_running")

                except Exception as e:
                    log_message(f"Error getting AML job status: {e}")

    except Exception as e:
        st.session_state.warning = st.sidebar.warning(f"Error getting log document: {e}")

def check_job_status():
    log_message("check_job_status")

    with st.spinner("Please wait ..."):
        
        log_message("check_job_status::spinner")        

        if st.session_state.aml_job_run_id is not None:
            status = api_client.get_job_status(st.session_state.aml_job_run_id)
            log_message(f"Status of AML Job {status}")
            log_message("AML Job Run ID", st.session_state.aml_job_run_id)
            st.session_state.warning.empty()
            st.session_state.job_status = f"AML Job is: {status}"
            st.session_state.warning = st.sidebar.info(f"AML Job is: {status}", icon="ℹ️")

            if  status in ["Completed", "Failed", "Canceled"]:
                st.session_state.indexing = False
                st.session_state.aml_job_run_id = None
                check_if_indexing_in_progress()
                # update_file_list_UI()
                api_client.update_index_status(index_name, "not_running")

        if st.session_state.process is not None:
            status = st.session_state.process.poll()
            st.session_state.warning.empty()
            log_message(f"Status of Subprocess {status}")

            if status is not None:
                st.session_state.job_status = f"Python Subprocess is: Completed"
                st.session_state.warning = st.sidebar.info(f"Python Subprocess is: Completed", icon="ℹ️")
                st.session_state.indexing = False
                st.session_state.process = None
                check_if_indexing_in_progress()
                # update_file_list_UI()
            else:
                st.session_state.job_status = f"Python Subprocess is: Running"
                st.session_state.warning = st.sidebar.info(f"Python Subprocess is: Running", icon="ℹ️")

        if st.session_state.aml_job_run_id is None:
            st.session_state.indexing = False
            check_if_indexing_in_progress()
            # update_file_list_UI()
            api_client.update_index_status(index_name, "not_running")

def update_file_list_UI(do_sleep = False, do_check_job_status=True):
    log_message("update_file_list_UI")
    global retry # FIXME: remove global variable
    index_log = api_client.get_index_log(index_name)
    if (index_log is None):
        retry = retry + 1
        time.sleep(1) # sometimes this process start before the document is commited into Cosmos DB
        if (retry > 60):
            st.sidebar.error("There was an issue with the indexing process, please check the logs")
            st.session_state.indexing = False
    else:
        # log_message("Updating file_list_UI", st.session_state.files_ingested )
        st.session_state.files_ingested = {}
        processed_files = 0
        processing_files = 0
        total_files = 0
        files = index_log['files_uploaded']
        logs = index_log['log_entries']
        
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
            # check_index_status(index_name, download_directory)
            append_log_message("Ingestion complete.")
            if do_check_job_status: check_job_status()
            try:
                st.session_state.warning.empty()
            except:
                pass
        else:
            if do_sleep: 
                if do_check_job_status: check_job_status()
                log_message("Sleeping 5 seconds")
                # time.sleep(5)


if copy_proc_plan:
    try:
        api_client.copy_processing_plan_to_index(index_name)
        # st.session_state.warning = st.sidebar.success("Processing plan copied successfully.")
    except Exception as e:
        st.session_state.warning = st.sidebar.error(f"Error copying processing plan: {e}")
        log_message("Error copying processing plan: ", e)

if index_name:
    log_message("if index_name")
    check_if_indexing_in_progress()
    update_file_list_UI()

if clear_ingestion: 
    log_message("if clear_ingestion")
    api_client.clear_indexing_status(index_name)
    check_if_indexing_in_progress()
    update_file_list_UI()

if start_ingestion:
    log_message("if start_ingestion")
    
    if (st.session_state.indexing):
        st.session_state.warning = st.sidebar.warning("Indexing in progress. Please wait for the current process to complete.")
    else:
        st.session_state.log_entries = []

        pending_files = []
        try: 
            document = api_client.get_index_log(index_name)
            if document is not None:
                 pending_files = [x['file_name'] for x in document['files_uploaded'] if (x['status'] == 'Not ingested') or (x['status'] == 'Ingesting...')]
                 log_message("Pending files: ", pending_files)
        except Exception as e:
            log_message("Error getting log document: ", e)
        

        if (len(uploaded_files) == 0) and (len(pending_files) == 0):
            st.session_state.warning = st.sidebar.warning("No files uploaded")
        else:
            st.session_state.indexing = True
            if pdf_extraction == gpt4v_label:
                pdf_extraction_option = 'gpt-4-vision'
            elif pdf_extraction == docint_label_pdf:
                pdf_extraction_option = 'document-intelligence'
            elif pdf_extraction == hybrid_label:
                pdf_extraction_option = 'hybrid'                
            else:
                pdf_extraction_option = 'document-intelligence'

            if docx_extraction == docint_label_docx:
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

            log_message("Ingestion Param dict", ingestion_params_dict)

            try:
                if job_execution == "Azure Machine Learning":
                    log_message("Current working directory:", os.path.abspath(os.getcwd()))
                    log_message("ROOT_PATH_INGESTION:", ROOT_PATH_INGESTION)

                    st.write(f"Current working directory: {os.path.abspath(os.getcwd())}")
                    st.write(f"ROOT_PATH_INGESTION: {ROOT_PATH_INGESTION}")

                    st.write(f"\n\nCWD Files: {os.listdir(os.getcwd())}")
                    st.write(f"ROOT_PATH_INGESTION Files: {os.listdir(ROOT_PATH_INGESTION)}")
                    st.write(f"Root Path Files: {os.listdir('./')}\n\n")
                    
                    st.session_state.aml_job_id = api_client.submit_ingestion_job(index_name, ingestion_params_dict)
                
                elif job_execution == "Subprocess (Local Testing)":
                    process = subprocess.Popen(["python", "../code/ingest_doc.py", 
                                    "--ingestion_params_dict", json.dumps(ingestion_params_dict),
                                    ])

                    st.session_state.process = process
                else:
                    st.session_state.warning = st.sidebar.warning("This Job Execution mode is not supported yet.")

            except Exception as e:
                st.session_state.warning = st.sidebar.error(f"Error starting ingestion job: {e}")
                st.session_state.indexing = False
                append_log_message("Error starting ingestion job", e)
                log_message("Error starting ingestion job", e)

if st.session_state.indexing or refresh:
    log_message("while st.session_state.indexing")
    update_file_list_UI(do_sleep = True)
