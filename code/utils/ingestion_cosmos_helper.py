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

import utils.cosmos_helpers as cs


cosmos = cs.SCCosmosClient(container_name=COSMOS_LOG_CONTAINER)


class IngestionCosmosHelper():

    def __init__(self):
        self.client = cosmos


    def create_index_document(self, document):
        return self.client.create_document(document)


    def get_index_document(self, index_name):
        return self.client.read_document(index_name, index_name)


    def upsert_document(self, document, index_name):
        return self.client.upsert_document(document, category_id=index_name)


    def check_if_indexing_in_progress(self, index_name):
        document = self.get_index_document(index_name)
        # logging.info("Document1", document)

        if document is not None:
            file_status = [ x['status'] for x in document['files_uploaded']]

            if 'Ingesting...' in file_status:
                return True, document
            else:
                return False, document

        return False, None

    
    def clear_indexing_in_progress(self, index_name):
        document = self.get_index_document(index_name)
        changed = False

        if document is not None:
            for doc in document['files_uploaded']:
                if doc['status'] == 'Ingesting...':
                    doc['status'] = 'Not ingested'
                    changed = True

        if changed:
            self.upsert_document(document, index_name)



    def update_index_document(self, document, download_directory):
        files_object = []
        ingested_files = [ x['file_name'] for x in document['files_uploaded']]
        logging.info(f"Ingested files: {ingested_files}")

        for root, dirs, files in os.walk(download_directory):
            logging.info(f"Found the following files: {files} in the downloads dir {download_directory}")
            
            for file in files:
                
                ## If file is already in index AND ingested, then update the status
                if file.lower() in ingested_files: 
                    file_index = next((index for index, f in enumerate(document['files_uploaded']) if f['file_name'] == file.lower()), None)
                    if os.path.exists(os.path.join(root, file + '.ingested')):
                        document['files_uploaded'][file_index]['status']  = 'Ingested'
                    continue

                ## If file is new, check for extension, ingested status, and add to the index
                extension = os.path.splitext(os.path.basename(file))[1].strip().lower()
                if extension not in ['.pdf', '.docx', '.xlsx', '.doc', '.xls', '.csv']: 
                    logging.info(f"Discarding {file}. Extension not supported.")
                    continue
                
                logging.info(f"{os.path.join(root, file + '.ingested')}, EXISTS {os.path.exists(os.path.join(root, file + '.ingested'))}")
                if os.path.exists(os.path.join(root, file + '.ingested')):
                    status = 'Ingested'
                else:
                    status = 'Not ingested'

                files_object.append({
                    "file_name": file.lower(),
                    "status": status
                })

        document['files_uploaded'].extend(files_object)
        return document
        

    def create_new_index_document(self, index_name, download_directory):
        files_object = []

        for root, dirs, files in os.walk(download_directory):
            for file in files:
                files_object.append({
                    "file_name": file.lower(),
                    "status": 'Not ingested'
                })

        document = {
            "id": index_name, #using the index name as the id
            "indexId": index_name,
            'categoryId': index_name,
            "files_uploaded": files_object,
            "log_entries": [],
            "job_id": '',
            "job_status": '',
        }

        return document


    def update_aml_job_id(self, index_name, run_id, status = None):
        document = self.get_index_document(index_name)
        document['job_id'] = run_id
        if status is not None: document['job_status'] = status
        logging.info(f"Updating AML Job Run id in Cosmos: {run_id}")
        self.upsert_document(document, index_name)


    def get_aml_job_id(self, index_name):
        document = self.get_index_document(index_name)
        return document['job_id'] 

    def update_aml_job_status(self, index_name, status):
        document = self.get_index_document(index_name)
        document['job_status'] = status
        logging.info(f"Updating AML Job Run Status in Cosmos: {status}")
        self.upsert_document(document, index_name)


    def get_aml_job_status(self, index_name):
        document = self.get_index_document(index_name)
        return document['job_status'] 


    def update_cosmos_with_download_files(self, index_name, download_directory):
        document = self.get_index_document(index_name)

        if document is not None:
            document = self.update_index_document(document, download_directory)
            self.upsert_document(document, index_name)
        else:
            document = self.create_new_index_document(index_name, download_directory)
            try:
                self.create_index_document(document)
            except Exception as e:
                logging.error(f"Error creating new document: {e}")
                raise e

        return document



    def get_file_index_with_cosmos_update(self, file, index_name, download_directory):
        if document is None: document = self.update_cosmos_with_download_files(index_name, download_directory)
        return self.get_file_index(file, document)

    
    def get_file_index(self, file, document):
        return next((index for index, f in enumerate(document['files_uploaded']) if f['file_name'] == file.lower()), None)


    def update_file_status_in_cosmos_index(self, status, file, document):
        file_index = self.get_file_index(file, document)
        document['files_uploaded'][file_index]['status'] = status
        return self.upsert_document(document, document['id'])