from fastapi import FastAPI, Request
from fastapi.responses import PlainTextResponse, FileResponse
from pydantic import BaseModel
import re
import os

import utils.cosmos_helpers as cs
from doc_utils import search, generate_section
from processor import ingest_doc_using_processors, read_asset_file, gpt4_models
from utils.cogsearch_rest import CogSearchHttpRequest
from aml_job import AmlJob
from doc_utils import *
from env_vars import *
from utils.ingestion_cosmos_helper import IngestionCosmosHelper

# Global setup

app = FastAPI()
cosmos = cs.SCCosmosClient()

def get_latest_file_version(directory, file_pattern):
    max_version = -1
    latest_file = None

    for filename in os.listdir(directory):
        match = file_pattern.match(filename)
        if match:
            version = int(match.group(1))
            if version > max_version:
                max_version = version
                latest_file = filename

    return os.path.join(directory, latest_file) if latest_file else None

file_pattern = re.compile(r'system_prompt_ver_(\d+)\.txt')

# API Endpoints

@app.get("/prompts")
def get_prompts():
    return cosmos.get_all_documents()

# A PATCH operation to upsert a prompt
@app.patch("/prompts")
def upsert_prompt(prompt):
    return cosmos.upsert_document(prompt)

# a POST operation to create a new prompt
@app.post("/prompts")
def create_prompt(prompt):
    return cosmos.create_document(prompt)

# A DELETE operation to delete a prompt
@app.delete("/prompts/{prompt_id}")
def delete_prompt(prompt_id):
    return cosmos.delete_document(prompt_id)

@app.get("/prompts/{prompt_id}", response_class=PlainTextResponse)
def get_prompt(prompt_id: str):
    prompts_path = os.environ.get("PROMPTS_PATH")
    if not prompts_path:
        #if it is empty it means the user does not have the environment variable set, 
        #so we assume its a local developer and will not populate paths from file share
        prompts_path = "../code/prompts"

    prompt_dir = os.path.join(prompts_path, prompt_id)
    prompt_file = get_latest_file_version(prompt_dir, file_pattern)
    prompt = read_asset_file(prompt_file)[0]
    return prompt

@app.get("/models")
def get_models():
    return gpt4_models

@app.get("/file", response_class=FileResponse)
def get_file(asset_path: str):
    return read_asset_file(asset_path)

class SearchRequest(BaseModel):
    query: str
    top: int
    approx_tag_limit: int
    conversation_history: str
    user_id: str
    computation_approach: str
    computation_decision: str
    vision_support: str
    include_master_py: str
    vector_directory: str
    vector_type: str
    index_name: str
    full_search_output: str
    count: int
    token_limit: int
    temperature: float
    verbose: str

# A POST /search that takes a JSON with following structure:
@app.post("/search")
def run_search(request: SearchRequest):
    # invoke search function matching the signature using the request object
    return search(request.query, request.top, request.approx_tag_limit, request.conversation_history, request.user_id, request.computation_approach, request.computation_decision, request.vision_support, request.include_master_py, request.vector_directory, request.vector_type, request.index_name, request.full_search_output, request.count, request.token_limit, request.temperature, request.verbose)

# A POST /generate_section that uses the generate_section function
@app.post("/generate_section")
def generate_section(section: str):
    return generate_section(section)

# A GET operation to get the list of existing files in downaload directory
@app.get("/{index_name}/files")
def get_download_files(index_name: str):
    existing_file_names = []
    ingestion_directory = os.path.join(ROOT_PATH_INGESTION , index_name)
    download_directory = os.path.join(ingestion_directory, 'downloads')
    try:
        files = os.listdir(download_directory)
        existing_file_names = [file for file in files if os.path.isfile(os.path.join(download_directory, file))]
    except Exception as e:
        log_message(f"Not able to get list of current files in the Downloads directory.\nException:\n{str(e)}")
        
    return existing_file_names

# A POST operation to upload files in batches in download directory
@app.post("/{index_name}/upload_files")
def upload_files(index_name: str, request: Request):
    
    ingestion_directory = os.path.join(ROOT_PATH_INGESTION , index_name)  
    os.makedirs(ingestion_directory, exist_ok=True)   
    download_directory = os.path.join(ingestion_directory, 'downloads')
    os.makedirs(download_directory, exist_ok=True)
    
    for file in request.files:
        file_path = os.path.join(download_directory, file.filename.replace(" ", "_"))
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
    ic.update_cosmos_with_download_files(index_name, download_directory)
        
    return None

class IngestionRequest(BaseModel):
    download_directory: str
    ingestion_directory: str
    index_name: str
    num_threads: int
    password: str
    delete_existing_output_dir: str
    processing_mode_pdf: str
    processing_mode_docx: str
    models: str
    vision_models: str
    verbose: str
    
# A POST /ingest that takes a JSON with the following structure:
@app.post("/ingest")
def run_ingestion(request: IngestionRequest):
    
    ingestion_directory = os.path.join(ROOT_PATH_INGESTION , request.get("index_name"))  
    os.makedirs(ingestion_directory, exist_ok=True)   
    download_directory = os.path.join(ingestion_directory, 'downloads')
    os.makedirs(download_directory, exist_ok=True)
    
    dict = request.model_dump()
    dict['download_directory'] = download_directory
    dict['ingestion_directory'] = ingestion_directory
    
    return ingest_doc_using_processors(dict)

cogsearch = CogSearchHttpRequest()
# A GET to return the list of cog_search indexes
@app.get("/indexes")
def get_indexes():
    return cogsearch.get_indexes()

# A GET to get CogSearch index documents, is exists
@app.get("/index/{index_name}/documents")
def get_index_status(index_name: str):
    index = CogSearchRestAPI(index_name)
    if index.get_index() is not None:
        documents = index.get_documents()
        return documents
    
    return None

# A GET operation to check indexing status
@app.get("/index/{index_name}/status")
def get_indexing_status(index_name: str):
    return ic.check_if_indexing_in_progress(index_name)

# A POST operation to update AmlJob status
@app.post("/index/{index_name}/status")
def update_aml_job_status(index_name: str, request: Request):
    return ic.update_aml_job_status(index_name, request.get("status"))

# A DELETE operation to clear indexing status
@app.delete("/index/{index_name}/status")
def clear_indexing_status(index_name: str):
    ic.clear_indexing_in_progress(index_name)
    return None

aml_job = AmlJob()
# A POST operation to submit an AmlJob
@app.post("/index/{index_name}/job")
def submit_aml_job(index_name: str, request: Request):
    # CHECKME - need to pass the request object to the submit_ingestion_job function
    run_id = aml_job.submit_ingestion_job(request, script = 'ingest_doc.py', source_directory='./code')
    ic.update_aml_job_id(index_name, run_id, status = "running")
    return None

@app.get("/job/{job_id}")
def set_aml_job_id(job_id: str):
    return aml_job.check_job_status_using_run_id(job_id)


ROOT_PATH_INGESTION = os.getenv("ROOT_PATH_INGESTION")
LOG_CONTAINER_NAME = os.getenv("COSMOS_LOG_CONTAINER")
DOCX_OPTIONS = os.getenv("DOCX_OPTIONS")
cosmos_log = cs.SCCosmosClient(container_name=LOG_CONTAINER_NAME)
ic = IngestionCosmosHelper()

# A GET to fetch processin plan
@app.get("/processing_plan")
def get_processing_plan():
    proc_plans = read_asset_file("./code/processing_plan.json")[0]

    if proc_plans == '':
        proc_plans = read_asset_file("../code/processing_plan.json")[0]
        
    return proc_plans

# A POST to copy the processing plan to the index
@app.post("/index/{index_name}/plan")
def copy_processing_plan_to_index(index_name: str):
    index_processing_plan_path = os.path.join(ingestion_directory, f'{index_name}.processing_plan.txt')
    plans = get_processing_plan()
    ingestion_directory = os.path.join(ROOT_PATH_INGESTION , index_name) 
    os.makedirs(ingestion_directory, exist_ok=True)
    write_to_file(plans, index_processing_plan_path, 'w')
    return None

# A GET to fetch cosmos log
@app.get("/indexes/{index_name}/log")
def get_cosmos_log(index_name: str):
    return cosmos_log.read_document(index_name, index_name)