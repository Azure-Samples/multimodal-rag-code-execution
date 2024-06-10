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
from env_vars import *


from utils.ingestion_cosmos_helper import *
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

if "proc_plans" not in st.session_state:
    proc_plans = read_asset_file("./code/processing_plan.json")[0]

    if proc_plans == '':
        proc_plans = read_asset_file("../code/processing_plan.json")[0]

    st.session_state.proc_plans = proc_plans

if "process" not in st.session_state:
    st.session_state.process = None

if "job_status" not in st.session_state:
    st.session_state.job_status = ''

if "warning" not in st.session_state:
    st.session_state.warning = st.empty()



#Main UI
ic = IngestionCosmosHelper()

aml_job = None
retry = 0

st.title("Document Ingestion - v.1.0.2")
col1, col2 = st.columns(2)

hybrid_label = "Hybrid (choose if pptx file is tidy - default option)"
gpt4v_label = "GPT 4 Vision (choose if pptx is very messy, or pdf is scanned)"
docint_label_pdf = "Document Intelligence (choose if this pdf is saved from docx)"
docint_label_docx = "Document Intelligence"

pdf_extraction = col1.selectbox("PDF extraction:", [hybrid_label, gpt4v_label, docint_label_pdf] )

try:
    from docx import Document
    docx_extraction = col1.selectbox("Docx extraction:", [docint_label_docx, "Python-Docx"] )
except:
    docx_extraction = col1.selectbox("Docx extraction:", [docint_label_docx] )

xlsx_extraction = col1.selectbox("Xlsx extraction:", ["OpenPyxl"] )

chunk_size = int(col1.text_input("Chunk Size:", '800'))
chunk_overlap = int(col1.text_input("Chunk Overlap:", '128'))

index_name = col2.text_input("Index name:", st.session_state.get('index_name', INITIAL_INDEX))
index_name = index_name.strip()

available_models = len([1 for x in gpt4_models if x['AZURE_OPENAI_RESOURCE'] is not None])


# number_threads = col2.slider("Number of threads:", 1, available_models, available_models)
number_threads = col2.text_input("Number of threads:", available_models, disabled=True)
pdf_password = col2.text_input("PDF password:")
job_execution = col2.selectbox("Job Execution:", ["Azure Machine Learning", "Subprocess (Local Testing)"] )
uploaded_files = col2.file_uploader("Choose a file(s) :file_folder:", accept_multiple_files=True)


st.session_state.num_threads = number_threads

def proc_plan_chance():
    st.session_state.proc_plans = st.session_state.processingPlansKey 
    print("Processing Plans Changed: ", st.session_state.proc_plans)

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

download_directory =""
ingestion_directory = ""
ingestion_directory = os.path.join(ROOT_PATH_INGESTION , index_name) 
os.makedirs(ingestion_directory, exist_ok=True)
download_directory = os.path.join(ingestion_directory, 'downloads')
os.makedirs(download_directory, exist_ok=True)

col2.write(f":blue[Download directory:] :green[{download_directory}]")
col2.write(f":blue[Ingestion directory:] :green[{ingestion_directory}]")
col2.write(f":blue[Index name:] :green[{index_name}]")
# col2.text(f":blue[Job Status:] :green[{st.session_state.job_status}]")

existing_file_names = []
try:
    files = os.listdir(download_directory)
    existing_file_names = [file for file in files if os.path.isfile(os.path.join(download_directory, file))]
except Exception as e:
    print(f"Not able to get list of current files in the Downloads directory.\nException:\n{str(e)}")


## COPY UPLOADED FILES TO THE DOWNLOAD DIRECTORY AND RENAME THEM
for uploaded_file in uploaded_files :
    print("Uploaded Files -- before processing", uploaded_files)
    #Use the file here. For example, you can read it:
    if uploaded_file.name.replace(" ", "_") in st.session_state.files_ingested: continue

    new_name = os.path.join(download_directory, uploaded_file.name.replace(" ", "_"))
    old_name = os.path.join(download_directory, uploaded_file.name)

    if not os.path.exists(new_name):
        with open(os.path.join(download_directory, uploaded_file.name), "wb") as f:
            f.write(uploaded_file.getvalue())

        try:
            os.rename(old_name, new_name)      
        except Exception as e:
            logc(f"Error renaming file to {new_name}. Most likely a problem with permissions accessing the downloads folder {download_directory}.\nException:\n{e}")

    st.session_state.files_ingested[uploaded_file.name.replace(" ", "_")] = "Not ingested"
    print("st.session_state.files_ingested", st.session_state.files_ingested)

ic.update_cosmos_with_download_files(index_name, download_directory)


bar_progress = st.progress(0, text="Please click on ingestion to start the process")

files_status = st.empty()
st.markdown("""---""")

# Placeholder for log entries
st.write("### Status Log")

log_placeholder = st.empty()


#check the Azure Cognitive index for the number of documents indexed
def check_index_status(index_name, download_directory):
    index = CogSearchRestAPI(index_name)
    if index.get_index() is not None:
        # doc_count_in_vecstore = cogrequest.get_stats()['documentCount']

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
    print("check_if_indexing_in_progress")
    try:
        if "aml_job" not in st.session_state:
            try:
                st.session_state.aml_job = AmlJob()
            except:
                st.session_state.aml_job = None

        st.session_state.indexing, document = ic.check_if_indexing_in_progress(index_name)
        # print("Document", document, "Indexing State", st.session_state.indexing)

        if document is not None:
            job_id = document.get('job_id', '')
            job_status = document.get('job_status', '')
            print("\n\nJob ID Found in Cosmos", job_id, "\n\n")

            if (job_id != '') and (job_status == 'running'):
                try:    
                    status = st.session_state.aml_job.check_job_status_using_run_id(job_id)
                    print(f"Checking Run_ID: {job_id}, status {status}")

                    if status not in ["Completed", "Failed", "Canceled"]:
                        st.session_state.job_status = f"AML Job is: {status}"
                        st.session_state.warning = st.sidebar.info(f"AML Job is: {status}", icon="ℹ️")
                    else:
                        st.session_state.indexing = False
                        update_file_list_UI(do_check_job_status=False)
                        ic.update_aml_job_status(index_name, "not_running")

                except Exception as e:
                    print(f"Error getting AML job status: {e}")

    except Exception as e:
        st.session_state.warning = st.sidebar.warning(f"Error getting log document: {e}")






def check_job_status():
    print("check_job_status")

    with st.spinner("Please wait ..."):
        # print("AML Job", st.session_state.aml_job.run is not None)
        print("check_job_status::spinner")        

        if st.session_state.aml_job.run is not None:
            status = st.session_state.aml_job.run.get_status()
            print(f"Status of AML Job {status}")
            print("AML Job Run ID", st.session_state.aml_job.run.id)
            st.session_state.warning.empty()
            st.session_state.job_status = f"AML Job is: {status}"
            st.session_state.warning = st.sidebar.info(f"AML Job is: {status}", icon="ℹ️")

            if  status in ["Completed", "Failed", "Canceled"]:
                st.session_state.indexing = False
                st.session_state.aml_job.run = None
                check_if_indexing_in_progress()
                # update_file_list_UI()
                ic.update_aml_job_status(index_name, "not_running")

        if st.session_state.process is not None:
            status = st.session_state.process.poll()
            st.session_state.warning.empty()
            print(f"Status of Subprocess {status}")

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

        if st.session_state.aml_job.run is None:
            st.session_state.indexing = False
            check_if_indexing_in_progress()
            # update_file_list_UI()
            ic.update_aml_job_status(index_name, "not_running")



def update_file_list_UI(do_sleep = False, do_check_job_status=True):
    print("update_file_list_UI")
    global retry
    document = cosmos.read_document(index_name,index_name)
    if (document is None):
        retry = retry + 1
        time.sleep(1) # sometimes this process start before the document is commited into Cosmos DB
        if (retry > 60):
            st.sidebar.error("There was an issue with the indexing process, please check the logs")
            st.session_state.indexing = False
    else:
        # print("Updating file_list_UI", st.session_state.files_ingested )
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
                print("Sleeping 5 seconds")
                # time.sleep(5)




if copy_proc_plan:
    try:
        index_processing_plan_path = os.path.join(ingestion_directory, f'{index_name}.processing_plan.txt')
        write_to_file(st.session_state.proc_plans, index_processing_plan_path, 'w')
        # st.session_state.warning = st.sidebar.success("Processing plan copied successfully.")
    except Exception as e:
        st.session_state.warning = st.sidebar.error(f"Error copying processing plan: {e}")
        print("Error copying processing plan: ", e)


if index_name:
    print("if index_name")
    check_if_indexing_in_progress()
    update_file_list_UI()



if clear_ingestion: 
    print("if clear_ingestion")
    ic.clear_indexing_in_progress(index_name)
    check_if_indexing_in_progress()
    update_file_list_UI()


if start_ingestion:
    print("if start_ingestion")
    
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

            print("Ingestion Param dict", ingestion_params_dict)

            try:
                if job_execution == "Azure Machine Learning":
                    print("Current working directory:", os.path.abspath(os.getcwd()))
                    print("ROOT_PATH_INGESTION:", ROOT_PATH_INGESTION)

                    st.write(f"Current working directory: {os.path.abspath(os.getcwd())}")
                    st.write(f"ROOT_PATH_INGESTION: {ROOT_PATH_INGESTION}")

                    st.write(f"\n\nCWD Files: {os.listdir(os.getcwd())}")
                    st.write(f"ROOT_PATH_INGESTION Files: {os.listdir(ROOT_PATH_INGESTION)}")
                    st.write(f"Root Path Files: {os.listdir('./')}\n\n")
                    
                    # aml_job = AmlJob()
                    st.session_state.aml_job.submit_ingestion_job(ingestion_params_dict, script = 'ingest_doc.py', source_directory='./code')

                    ic.update_aml_job_id(index_name, st.session_state.aml_job.run.id, status = "running")
                
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
                print("Error starting ingestion job", e)

    

if st.session_state.indexing or refresh:
    print("while st.session_state.indexing")
    update_file_list_UI(do_sleep = True)
    



