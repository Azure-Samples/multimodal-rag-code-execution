import logging
from azure.cosmos import CosmosClient, PartitionKey
import copy

from env_vars import *

class SCCosmosClient():

    def __init__(self, url=COSMOS_URI, credential=COSMOS_KEY, db_name=COSMOS_DB_NAME, container_name=COSMOS_CONTAINER_NAME):
        

        try:
            self.client = CosmosClient(url=url, credential=credential)
            self.partitionKeyPath = PartitionKey(path="/categoryId")
            self.database = self.client.create_database_if_not_exists(id=db_name)

            indexing_policy={ "includedPaths":[{ "path":"/*"}], "excludedPaths":[{ "path":"/\"_etag\"/?"}]}
            
            try:
                self.container = self.database.create_container_if_not_exists(id=container_name, partition_key=self.partitionKeyPath,indexing_policy=indexing_policy)
            except:
                try:
                    self.container = self.database.create_container_if_not_exists(id=container_name, partition_key=self.partitionKeyPath,indexing_policy=indexing_policy)

                except Exception as e:
                    logging.error(f"Encountered error {e} while creating the container")
                    print(f"Encountered error {e} while creating the container")
            
        except:
            print("Failed to initialize Cosmos DB container")
            logging.error("Failed to initialize Cosmos DB container")


    def get_all_documents(self):
        # NOTE: Use MaxItemCount on Options to control how many items come back per trip to the server
        #       Important to handle throttles whenever you are doing operations such as this that might
        #       result in a 429 (throttled request)
        item_list = list(self.container.read_all_items(max_item_count=10))
        return item_list


    def read_document(self, doc_id, partion_key):
       
        # We can do an efficient point read lookup on partition key and id
        try:
            return self.container.read_item(item=doc_id, partition_key=partion_key)
        except Exception as e:
            return None
       

    def get_document_by_id(self, doc_id, category_id = COSMOS_CATEGORYID):
        query = "SELECT * FROM documents p WHERE p.categoryId = @categoryId AND p.id = @id"
        params = [dict(name="@categoryId", value=category_id), dict(name="@id", value=doc_id)]

        results = self.container.query_items(query=query, parameters=params, enable_cross_partition_query=False)

        try:
            document = results.next()
            return self.clean_document(document)

        except Exception as e:
            print(f"Cosmos Get Documnet by ID Exception: ID not found {e}")
            logging.warning(f"Cosmos Get Documnet by ID Exception: ID not found {e}")
            return None


    def delete_document(self, doc_id, partion_key = COSMOS_CATEGORYID):
        try:
            return self.container.delete_item(doc_id, partition_key=partion_key)
        except Exception as e:
            logging.error(f"Cosmos Delete Document Exception: {e}")
            print(f"CosmosDelete Document Exception: {e}")


    def clean_document(self, document):
        document = copy.deepcopy(document)
        for k in list(document.keys()):
            if k not in self.all_fields:
                del document[k]

        return document

    def create_document(self, item):
        # As your app evolves, let's say your object has a new schema. You can insert SalesOrderV2 objects without any
        # changes to the database tier.
        self.container.create_item(body=item)

    def upsert_document(self, document, category_id = COSMOS_CATEGORYID):

        try:
            document["categoryId"] = category_id
            return self.container.upsert_item(document)
        except Exception as e:
            logging.error(f"Upsert Document Exception: {e}")
            print(f"Upsert Document Exception: {e}")
            return None

