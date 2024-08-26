import uuid
import os
import logging
import json
import copy
import re


from utils import http_helpers
from utils import cogsearch_rest
from env_vars import *



class IndexSync():

    def __init__(self, staging_cs=None, prod_cs=None, staging_api_key=COG_SEARCH_ADMIN_KEY, staging_search_service_name=COG_SEARCH_ENDPOINT, staging_index_name=KB_INDEX_NAME, prod_api_key=COG_SEARCH_ADMIN_KEY_PROD, prod_search_service_name=COG_SEARCH_ENDPOINT_PROD, prod_index_name=KB_SEM_INDEX_NAME):
        
        if staging_cs is None:
            staging_cs = cogsearch_rest.CogSearchRestAPI(api_key=staging_api_key, search_service_name=staging_search_service_name, index_name=staging_index_name)
        if prod_cs is None:
            prod_cs = cogsearch_rest.CogSearchRestAPI(api_key=prod_api_key, search_service_name=prod_search_service_name, index_name=prod_index_name)
        
        self.staging_cs = staging_cs
        self.prod_cs = prod_cs

    def duplicate_index(self):
        top = 100
        page = 0
        num_docs = 0
        res = {}
        up_res = []

        while True:
            docs = self.staging_cs.get_documents_by_page(top, page)
            if len(docs) == 0: break
            num_docs += len(docs)
            res = self.prod_cs.upload_documents(docs)
            up_res += res['value']
            page += 1

        return up_res



    def sync_docs(self, doc_ids):
        
        filt = ""

        if len(doc_ids) == 0: return 0

        for doc_id in doc_ids:
            filt += f"(id eq '{doc_id}') or "

        filt = filt[:-4]

        docs = self.staging_cs.get_documents(filt=filt)
        res = self.prod_cs.upload_documents(docs)

        return res['value']


    def get_document_by_id(self, doc_id, system="staging"):
        if system == 'production':
            return self.prod_cs.get_document_by_id(doc_id)
        else:
            return self.staging_cs.get_document_by_id(doc_id)



    def upload_documents(self, documents, system="staging"):
        if system == 'production':
            return self.prod_cs.upload_documents(documents)
        else:
            return self.staging_cs.upload_documents(documents)