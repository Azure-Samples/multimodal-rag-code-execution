import argparse
import os
import sys
import json
sys.path.append("./")
from doc_utils import ingest_doc
from processor import *
import doc_utils

#Cosmos will be used to store the indexing process
import utils.cosmos_helpers as cs
LOG_CONTAINER_NAME = os.getenv("COSMOS_LOG_CONTAINER")

cosmos = cs.SCCosmosClient(container_name=LOG_CONTAINER_NAME)

# Create an argument parser
parser = argparse.ArgumentParser(description='Ingest documents.')

# Add the required arguments
parser.add_argument('--ingestion_params_dict', type=str, help='Ingestion params dictionary')


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

    ingestion_directory = os.path.join(datastore_mount, ingestion_directory).replace('\\', '/')
    download_directory = os.path.join(datastore_mount, download_directory).replace('\\', '/')

    ingestion_params_dict['ingestion_directory'] = ingestion_params_dict['ingestion_directory'].replace('\\', '/')
    ingestion_params_dict['download_directory'] = ingestion_params_dict['download_directory'].replace('\\', '/')

    os.environ['ROOT_PATH_INGESTION'] = datastore_mount
    ROOT_PATH_INGESTION = datastore_mount

    print(f"\n\nROOT_PATH_INGESTION is now {ROOT_PATH_INGESTION}")
    print(f"Changing Current Working Directory in Python to {os.path.dirname(datastore_mount)}\n\n")
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


print("\n\nIngestion Directory", ingestion_directory)
print("Download Directory", download_directory)
print(f"Current Working Directory {os.getcwd()}\n\n")


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
    

doc_utils.log_ui_func_hook = append_log_message

def create_indexing_logs(index_name):
    files_object = []

    existing_process_object = cosmos.read_document(index_name, index_name)
    print(f"Existing log object: {existing_process_object}")
    
    if existing_process_object is not None:
        ingested_files = [ x['file_name'] for x in existing_process_object['files_uploaded']]
        print(f"Ingested files: {ingested_files}")
        for root, dirs, files in os.walk(download_directory):
            print(f"Found the following files: {files} in the downloads dir {download_directory}")
            for file in files:
                if file.lower() in ingested_files: continue
                extension = os.path.splitext(os.path.basename(file))[1].strip().lower()
                if extension not in ['.pdf', '.docx', '.xlsx', '.doc', '.xls']: continue

                if os.path.exists(os.path.join(root, file + '.ingested')):
                    status = 'Ingested'
                else:
                    status = 'Not ingested'

                files_object.append({
                    "file_name": file.lower(),
                    "status": status
                })

        existing_process_object['files_uploaded'].extend(files_object)
        cosmos.upsert_document(existing_process_object, category_id=index_name)
        return existing_process_object

    for root, dirs, files in os.walk(download_directory):
        for file in files:
            files_object.append({
                "file_name": file.lower(),
                "status": 'Not ingested'
            })

    progress_object = {
        "id": index_name, #using the index name as the id
        "indexId": index_name,
        'categoryId': index_name,
        "files_uploaded": files_object,
        "log_entries": [],
    }
    try:
        document = cosmos.create_document(progress_object)
        return document
    except Exception as e:
        print(f"Failed to create the document for index {index_name} with Exception {e}")
        return None


indexing_document = create_indexing_logs(index_name) 

print(f"\n\nIndexing Document:\n{indexing_document}\n\n")

if indexing_document is None:
    print(f"Failed to create the document for index {index_name}")
else:
    for root, dirs, files in os.walk(download_directory):
            print(f"Found the following files: {files} in the downloads dir {download_directory}")
            for file in files:
                # Check if the file is a PDF
                # if file.lower().endswith('.pdf'):
                print(f"Looking at file: {file}")

                ingested = False
                for uf in indexing_document["files_uploaded"]:
                    if uf['file_name'] == file.lower():
                        if uf['status'] == 'Ingested':
                            ingested = True
                            break
                
                if ingested == True: 
                    print(f"Already ingested file: {file}. Skipping.")
                    continue

                if file.endswith('.ingested'): 
                    # print(f"Ingested file flag found for: {file}. Skipping.")
                    print(f"Extension 'ingested' not supporting: {file}. Skipping.")
                    continue
                
                extension = os.path.splitext(os.path.basename(file))[1].strip().lower()
                if extension not in ['.pdf', '.docx', '.xlsx', '.doc', '.xls']: 
                    print(f"Extension not supporting: {file}. Skipping.")
                    continue

                if os.path.exists(os.path.join(root, file + '.ingested')): 
                    print(f"Ingested file flag found for: {file}. Skipping.")
                    continue

                # try:
                file_index = next((index for index, f in enumerate(indexing_document['files_uploaded']) if f['file_name'] == file.lower()), None)
                indexing_document['files_uploaded'][file_index]['status'] = 'Ingesting...'
                cosmos.upsert_document(indexing_document, category_id=index_name)
                file_path = os.path.join(root, file)

                ingestion_params_dict['doc_path'] = file_path

                # Call ingest_doc on the file
                ingest_doc_using_processors(ingestion_params_dict)

                indexing_document['files_uploaded'][file_index]['status'] = 'Ingested'
                cosmos.upsert_document(indexing_document, category_id=index_name)

                # except Exception as e:
                #     #delete the indexing_document from Cosmos DB
                #     indexing_document['files_uploaded'][file_index]['status'] = 'Failed'
                #     indexing_document['files_uploaded'][file_index]['error'] = f'{e}'
                #     cosmos.upsert_document(indexing_document, category_id=index_name)
                #     print(f"Failed to ingest the file {file} with exception: {e}")

    # cosmos.delete_document(index_name, index_name)



