import argparse
import os
import sys
import json
import logging
from doc_utils import *
from processor import *
import utils.logc
from utils.ingestion_cosmos_helper import *
from log_utils import setup_logger

sys.path.append("./")

#Cosmos will be used to store the indexing process
import utils.cosmos_helpers as cs
LOG_CONTAINER_NAME = os.getenv("COSMOS_LOG_CONTAINER")

cosmos = cs.SCCosmosClient(container_name=LOG_CONTAINER_NAME)
ic = IngestionCosmosHelper()

# Create an argument parser
parser = argparse.ArgumentParser(description='Ingest documents.')

# Add the required arguments
parser.add_argument('--ingestion_params_dict', type=str, help='Ingestion params dictionary')

setup_logger()

# Parse the command-line arguments
args = parser.parse_args()

# Access the arguments
ingestion_params_dict = json.loads(args.ingestion_params_dict)

## AML Job
datastore_mount = ingestion_params_dict.get('datastore_mount', None)

if datastore_mount is not None:
    ingestion_directory = ingestion_params_dict['ingestion_directory']
    download_directory = ingestion_params_dict['download_directory']

    if ingestion_directory.startswith(ROOT_PATH_INGESTION): ingestion_directory = ingestion_directory[len(ROOT_PATH_INGESTION):]
    if download_directory.startswith(ROOT_PATH_INGESTION): download_directory = download_directory[len(ROOT_PATH_INGESTION):]

    ingestion_directory = ingestion_directory.replace('\\', '/')
    download_directory = download_directory.replace('\\', '/')

    if ingestion_directory.startswith('/'): ingestion_directory = ingestion_directory[1:]
    if download_directory.startswith('/'): download_directory = download_directory[1:]

    ingestion_directory = os.path.join(datastore_mount, ingestion_directory).replace('\\', '/')
    download_directory = os.path.join(datastore_mount, download_directory).replace('\\', '/')

    # ingestion_params_dict['ingestion_directory'] = ingestion_params_dict['ingestion_directory'].replace('\\', '/')
    # ingestion_params_dict['download_directory'] = ingestion_params_dict['download_directory'].replace('\\', '/')

    ingestion_params_dict['ingestion_directory'] = f"../{ingestion_params_dict['index_name']}"
    ingestion_params_dict['download_directory']  = f"../{ingestion_params_dict['index_name']}/downloads"

    os.environ['ROOT_PATH_INGESTION'] = datastore_mount
    ROOT_PATH_INGESTION = datastore_mount

    logging.info(f"\n\nROOT_PATH_INGESTION is now {ROOT_PATH_INGESTION}")
    # logging.info(f"Changing Current Working Directory in Python to {os.path.dirname(datastore_mount)}\n\n")
    os.chdir(os.path.join(datastore_mount, ingestion_params_dict["index_name"]))

else:
    ingestion_directory = ingestion_params_dict['ingestion_directory']
    download_directory = ingestion_params_dict['download_directory']


index_name = ingestion_params_dict['index_name']
number_threads = ingestion_params_dict['num_threads']
password = ingestion_params_dict['password']
delete_existing_output_dir = ingestion_params_dict['delete_existing_output_dir']
processing_mode_pdf = ingestion_params_dict['processing_mode_pdf']
processing_mode_docx = ingestion_params_dict['processing_mode_docx']
processing_mode_xlsx = ingestion_params_dict['processing_mode_xlsx']


logging.info("\n\nIngestion Directory: %s", ingestion_directory)
logging.info("Download Directory: %s", download_directory)
logging.info("Current Working Directory: %s\n\n", os.getcwd())


processing_logs = []

def append_log_message(message, text=None):
    # Append new message to the session state list of log entries
    processing_logs.append(message + f": {text}" if text else "")

    # Display all log entries from the session state
    #store those logs in the cosmos DB index object
    try:
        document = cosmos.read_document(index_name,index_name)
    except:
        document = None
    if document is not None:
        document['log_entries'] = processing_logs
        cosmos.upsert_document(document, index_name)
    
# Ensure all doc_utils.logc calls are redirected to the append_log_message function
utils.logc.log_ui_func_hook = append_log_message

def create_indexing_logs(index_name):
    return ic.update_cosmos_with_download_files(index_name, download_directory)


indexing_document = create_indexing_logs(index_name) 

logging.info(f"\n\nIndexing Document:\n%s\n\n", indexing_document)

if indexing_document is None:
    logging.info(f"Failed to create the document for index %s", index_name)
else:
    for root, dirs, files in os.walk(download_directory):
            logging.info(f"Found the following files: %s in the downloads dir %s", files, download_directory)
            for file in files:
                logging.info(f"Looking at file: %s", file)

                file_index = next((index for index, f in enumerate(indexing_document['files_uploaded']) if f['file_name'] == file.lower()), None)

                ingested = False
                for uf in indexing_document["files_uploaded"]:
                    if uf['file_name'] == file.lower():
                        if uf['status'] == 'Ingested':
                            ingested = True
                            break
                
                if ingested == True: 
                    logging.info(f"Already ingested file: %s. Skipping.", file)
                    continue

                if file.endswith('.ingested'): 
                    # logging.info(f"Ingested file flag found for: %s. Skipping.", file)
                    logging.info(f"Extension 'ingested' not supporting: %s. Skipping.", file)
                    continue
                
                extension = os.path.splitext(os.path.basename(file))[1].strip().lower()
                if extension not in ['.pdf', '.docx', '.xlsx', '.doc', '.xls', '.csv']: 
                    logging.info(f"Extension not supported: %s. Skipping.", file)
                    continue

                if os.path.exists(os.path.join(root, file + '.ingested')): 
                    indexing_document['files_uploaded'][file_index]['status'] = 'Ingested'
                    cosmos.upsert_document(indexing_document, category_id=index_name)
                    logging.info(f"Ingested file flag found for: %s. Skipping.", file)
                    continue

                # try:
                
                indexing_document['files_uploaded'][file_index]['status'] = 'Ingesting...'
                cosmos.upsert_document(indexing_document, category_id=index_name)

                # Call ingest_doc on the file
                file_path = os.path.join(root, file)
                ingestion_params_dict['doc_path'] = file_path

                ingest_doc_using_processors(ingestion_params_dict)
                # time.sleep(2)

                indexing_document['files_uploaded'][file_index]['status'] = 'Ingested'
                cosmos.upsert_document(indexing_document, category_id=index_name)

                # except Exception as e:
                #     indexing_document['files_uploaded'][file_index]['status'] = 'Failed'
                #     indexing_document['files_uploaded'][file_index]['error'] = f'{e}'
                #     cosmos.upsert_document(indexing_document, category_id=index_name)
                #     logging.info(f"Failed to ingest the file %s with exception: %s", file, e)
