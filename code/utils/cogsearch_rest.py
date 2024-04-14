import uuid
import os
import logging
import json
import copy
import re
import requests
from openai import AzureOpenAI
from utils.http_helpers import *
# from utils import cogsearch_helpers
from env_vars import *

from tenacity import (
    retry,
    stop_after_attempt,
    wait_random_exponential,
)

import os
from dotenv import load_dotenv
from azure.search.documents.indexes import SearchIndexClient

# os.environ['USE_PTU'] = '0'

# if os.getenv('USE_PTU') == '1':
#     load_dotenv('.env')
# else:
#     load_dotenv('.env')

load_dotenv()

## Reference https://learn.microsoft.com/en-us/rest/api/searchservice/operation-groups?view=rest-searchservice-2023-11-01


AZURE_OPENAI_KEY = os.environ.get('AZURE_OPENAI_KEY')
AZURE_OPENAI_API_VERSION = os.environ.get('AZURE_OPENAI_API_VERSION')
AZURE_OPENAI_MODEL_VISION = os.environ.get('AZURE_OPENAI_MODEL_VISION')
OPENAI_API_BASE = f"https://{os.getenv('AZURE_OPENAI_RESOURCE')}.openai.azure.com/"
AZURE_OPENAI_MODEL = os.environ.get('AZURE_OPENAI_MODEL')

COG_SEARCH_ADMIN_KEY = os.environ.get('COG_SEARCH_ADMIN_KEY')
COG_SEARCH_ENDPOINT = os.environ.get('COG_SEARCH_ENDPOINT')
COG_VEC_SEARCH_API_VERSION = os.environ.get('COG_VEC_SEARCH_API_VERSION')

AZURE_OPENAI_EMBEDDING_API_BASE = f"https://{os.getenv('AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE')}.openai.azure.com/"
AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE_KEY = os.environ.get('AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE_KEY')
AZURE_OPENAI_EMBEDDING_MODEL_API_VERSION = os.environ.get('AZURE_OPENAI_EMBEDDING_MODEL_API_VERSION')
AZURE_OPENAI_EMBEDDING_MODEL= os.environ.get('AZURE_OPENAI_EMBEDDING_MODEL')



oai_client = AzureOpenAI(
    azure_endpoint = OPENAI_API_BASE, 
    api_key= AZURE_OPENAI_KEY,  
    api_version= AZURE_OPENAI_API_VERSION,
)


oai_emb_client = AzureOpenAI(
    azure_endpoint = AZURE_OPENAI_EMBEDDING_API_BASE, 
    api_key= AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE_KEY,  
    api_version= AZURE_OPENAI_EMBEDDING_MODEL_API_VERSION,
)


@retry(wait=wait_random_exponential(min=1, max=18), stop=stop_after_attempt(8))      
def get_embeddings(text, embedding_model = AZURE_OPENAI_EMBEDDING_MODEL, client = oai_emb_client):
    return client.embeddings.create(input=[text], model=embedding_model).data[0].embedding


upload_docs_json = {
    "value": [
    ]
}

upload_doc_json = {
    "asset_id": "",
    "@search.action": "upload"
}



class CogSearchHttpRequest(HTTPRequest):

    def __init__(self, api_key = COG_SEARCH_ADMIN_KEY, search_service_name=COG_SEARCH_ENDPOINT, index_name="", api_version=COG_VEC_SEARCH_API_VERSION):
        self.api_key = api_key
        self.search_service_name = search_service_name
        self.index_name = index_name
        self.api_version = api_version
        self.url        = f"{search_service_name}/indexes/{index_name}?api-version={api_version}"
        self.post_url   = f"{search_service_name}/indexes/{index_name}/docs/index?api-version={api_version}"
        self.search_url = f"{search_service_name}/indexes/{index_name}/docs/search?api-version={self.api_version}"
        self.index_url = f"{search_service_name}/indexes?api-version={self.api_version}"
        self.stats_url = f"{search_service_name}/indexes/{index_name}/stats?api-version={self.api_version}"
        
        
        self.default_headers = {'Content-Type': 'application/json', 'api-key': self.api_key}
        # print("CogSearchHttpRequest URL: ", self.url)


    def get_url(self, op = None):
        if op == 'index':
            url = self.post_url
        elif op == 'search':
            url = self.search_url
        elif op == 'indexes':
            url = self.index_url
        elif op == 'stats':
            url = self.stats_url
        else:
            url = self.url

        return url
    
    def get_indexes(self):
        return self.get(op='indexes')





class CogSearchRestAPI(CogSearchHttpRequest):


    def __init__(self, index_name, 
                    fields = None,
                    api_key = COG_SEARCH_ADMIN_KEY, 
                    search_service_name = COG_SEARCH_ENDPOINT, 
                    api_version  = COG_VEC_SEARCH_API_VERSION):

        super().__init__(api_key, search_service_name, index_name, api_version)
        
        if AZURE_OPENAI_EMBEDDING_MODEL == 'text-embedding-ada-002':
            dimensions = 1536
        elif AZURE_OPENAI_EMBEDDING_MODEL == 'text-embedding-3-large':
            dimensions = 3072
        elif AZURE_OPENAI_EMBEDDING_MODEL == 'text-embedding-3-small':
            dimensions = 1536
        else:
            dimensions = 1536

        if fields is None:
            self.fields = [
                    {"name": "asset_id", "type": "Edm.String", "key": True, "searchable": True, "filterable": True, "retrievable": True, "sortable": True},
                    {"name": "asset_path", "type": "Edm.String", "searchable": True, "filterable": True, "retrievable": True, "sortable": True},
                    {"name": "document_path", "type": "Edm.String", "searchable": True, "filterable": True, "retrievable": True, "sortable": True},
                    {"name": "filename", "type": "Edm.String", "searchable": True, "filterable": True, "retrievable": True, "sortable": True},
                    {"name": "image_file", "type": "Edm.String", "searchable": True, "filterable": True, "retrievable": True, "sortable": True},
                    {"name": "asset_filename", "type": "Edm.String", "searchable": True, "filterable": True, "retrievable": True, "sortable": True},
                    {"name": "chunk_number", "type": "Edm.String", "searchable": True, "filterable": True, "retrievable": True, "sortable": True},
                    {"name": "type", "type": "Edm.String", "searchable": True, "filterable": True, "retrievable": True, "sortable": True},
                    {"name": "document_id", "type": "Edm.String", "searchable": True, "filterable": True, "retrievable": True, "sortable": True},
                    {"name": "python_block", "type": "Edm.String", "searchable": True, "filterable": True, "retrievable": True, "sortable": True},
                    {"name": "python_code", "type": "Edm.String", "searchable": True, "filterable": True, "retrievable": True, "sortable": True},
                    {"name": "markdown", "type": "Edm.String", "searchable": True, "filterable": True, "retrievable": True, "sortable": True},
                    {"name": "mermaid", "type": "Edm.String", "searchable": True, "filterable": True, "retrievable": True, "sortable": True},
                    {"name": "vector", "type": "Collection(Edm.Single)", "searchable": True,"retrievable": True, "dimensions": dimensions,"vectorSearchProfile": "my-vector-profile"},
                    {"name": "tags", "type": "Edm.String","searchable": True, "filterable": False, "retrievable": True, "sortable": False, "facetable": False},
                    {"name": "text", "type": "Edm.String","searchable": True, "filterable": False, "retrievable": True, "sortable": False, "facetable": False},
            ]
        else:
            self.fields = fields

        self.all_fields = [f['name'] for f in self.fields]



    def create_index(self):
        index_schema = {
            "name": self.index_name,  # Replace with your index name
            "fields": self.fields,
            "vectorSearch": {
                "algorithms": [
                    {
                        "name": "my-hnsw-vector-config-1",
                        "kind": "hnsw",
                        "hnswParameters": 
                        {
                            "m": 4,
                            "efConstruction": 400,
                            "efSearch": 500,
                            "metric": "cosine"
                        }
                    },
                    {
                        "name": "my-hnsw-vector-config-2",
                        "kind": "hnsw",
                        "hnswParameters": 
                        {
                            "m": 4,
                            "metric": "euclidean"
                        }
                    },
                    {
                        "name": "my-eknn-vector-config",
                        "kind": "exhaustiveKnn",
                        "exhaustiveKnnParameters": 
                        {
                            "metric": "cosine"
                        }
                    }
                ],
                "profiles": [      
                    {
                        "name": "my-vector-profile",
                        "algorithm": "my-hnsw-vector-config-1"
                    }
            ]
            },
            "semantic": {
                "configurations": [
                    {
                        "name": "my-semantic-config",
                        "prioritizedFields": {
                            "prioritizedContentFields": [
                                { "fieldName": "text" }
                            ],
                            "prioritizedKeywordsFields": [
                                {
                                    "fieldName": "tags"
                                }
                            ]
                        }
                    }
                ]
            }
        }
        

        return self.put(body=index_schema)


    def delete_index(self):
        headers = {'Content-Type': 'application/json', 'api-key': self.api_key}
        delete_url = f"{self.search_service_name}/indexes/{self.index_name}?api-version={self.api_version}"
        response = requests.delete(delete_url, headers=headers)
        print("Status Code for Delete Index: ", response.status_code)
        return response.status_code == 204


    def get_index(self):
        try:
            return self.get()
        except Exception as e:
            print("Get Index Error: ", e)
            return None


    def get_document_by_id(self, doc_id):
        try:
            get_by_id = f"{self.search_service_name}/indexes/{self.index_name}/docs/{doc_id}?api-version={self.api_version}"
            res = self.get(input_url = get_by_id)
            return res
        except Exception as e:
            print("Get Document Error: ", e)
            return None


    def get_stats(self):
        res = self.get(op ='stats')
        return res


    def get_documents_by_page(self, top = 100, page = 0, select = '*', filt=""):

        docs_dict = {  
            "search": "*",  
            "skip": page * top,  
            "top": top, 
            "select": select,
            "filter": filt
        } 

        res = self.post(op ='search', body = docs_dict)

        return res['value']


    def get_documents(self, select = '*', filt=""):
        top = 5
        page = 0

        documents = []

        while True:
            docs = self.get_documents_by_page(top = top, page = page, select = select, filt=filt)
            if len(docs) == 0: break
            documents += docs
            page += 1

        return documents



    def upload_documents(self, documents):

        docs_dict = copy.deepcopy(upload_docs_json)

        for doc in documents:
            doc_dict = {}
                        
            for k in self.all_fields:
                doc_dict[k] = doc.get(k, '')

            doc_dict["@search.action"] = "mergeOrUpload"
            docs_dict['value'].append(doc_dict)
        
        return self.post(op ='index', body = docs_dict)



    def delete_documents(self, op='index', ids = []):
        docs_dict = copy.deepcopy(upload_docs_json)

        for i in ids:
            doc_dict = {}
            doc_dict['asset_id'] = i
            doc_dict["@search.action"] = "delete"
            docs_dict['value'].append(doc_dict)

        self.post(op ='index', body = docs_dict)


    def search_documents(self, search_query = "*", select_fields = "*", filter_query = "", top=7, count=False):
        search_body = {
            "count": count,
            "search": search_query,
            "select": select_fields,
            "filter": filter_query,
            "top": top,
            "queryType": "semantic",
            "answers": "extractive|count-3",
            "captions": "extractive|highlight-true",
            "semanticConfiguration": "my-semantic-config",
            "vectorQueries": [
                {
                    "vector": get_embeddings(search_query),
                    "k": top,
                    "fields": "vector",
                    "kind": "vector",
                    "exhaustive": True
                }
            ]
        }

        headers = {'Content-Type': 'application/json', 'api-key': self.api_key}
        response = self.post(op='search', headers=headers, body=search_body)
        return response