import logging
from azure.cosmos import CosmosClient, PartitionKey
import copy

from env_vars import *

logging.getLogger("azure.core.pipeline.policies.http_logging_policy").setLevel(logging.WARNING)


def init_container(containerId, partitionKeyPath, indexing_policy, **kwargs):

    container = None

    try:
        container = database.create_container_if_not_exists(id=containerId, partition_key=partitionKeyPath, indexing_policy=indexing_policy, **kwargs)
    except:
        try:
            container = database.create_container_if_not_exists(id=containerId, partition_key=partitionKeyPath, indexing_policy=indexing_policy, **kwargs)
        except Exception as e:
            logging.error(f"Encountered error {e} while creating the container")

    return container


client = None
partitionKeyPath = None
database = None
container = None

try:
    client = CosmosClient(url=COSMOS_URI, credential=COSMOS_KEY)
    partitionKeyPath = PartitionKey(path=f"/categoryId")
    database = client.create_database_if_not_exists(id=COSMOS_DB_NAME)

except Exception as e:
    logging.error(f"Failed to initialize Cosmos DB container: {e}")



class SCCosmosClient():

    def __init__(self, url=COSMOS_URI, credential=COSMOS_KEY, db_name=COSMOS_DB_NAME, container_name=COSMOS_CONTAINER_NAME):
    
        # try:
        indexing_policy={ "includedPaths":[{ "path":"/*"}], "excludedPaths":[{ "path":"/\"_etag\"/?"}]}

        self.client = client
        self.partitionKeyPath = partitionKeyPath
        self.database = database
        self.container = init_container(container_name, partitionKeyPath, indexing_policy)
        


    def get_all_documents(self):
        # NOTE: Use MaxItemCount on Options to control how many items come back per trip to the server
        #       Important to handle throttles whenever you are doing operations such as this that might
        #       result in a 429 (throttled request)
        item_list = list(self.container.read_all_items(max_item_count=10))
        return item_list


    def read_document(self, doc_id, partition_key = None):
        # We can do an efficient point read lookup on partition key and id
        if partition_key is None: partition_key = self.partitionKeyPath
        try:
            return self.container.read_item(item=doc_id, partition_key=partition_key)
        except Exception as e:
            logging.error(f"Cosmos Read Document Exception: {e}")
            return None
       

    def get_document_by_id(self, doc_id, category_id = COSMOS_CATEGORYID):
        query = "SELECT * FROM documents p WHERE p.categoryId = @categoryId AND p.id = @id"
        params = [dict(name="@categoryId", value=category_id), dict(name="@id", value=doc_id)]

        results = self.container.query_items(query=query, parameters=params, enable_cross_partition_query=True)

        try:
            document = results.next()
            return document

        except Exception as e:
            logging.warn(f"Cosmos Get Document by ID Exception: {e}")
            return None


    def delete_document(self, doc_id, partition_key = None):
        try:
            if partition_key is None: partition_key = self.partitionKeyPath
            return self.container.delete_item(doc_id, partition_key=partition_key)
        except Exception as e:
            logging.error(f"Cosmos Delete Document Exception: {e}")


    def clean_document(self, document):
        document = copy.deepcopy(document)
        for k in list(document.keys()):
            if k not in self.all_fields:
                del document[k]

        return document


    def create_document(self, item):
        # As your app evolves, let's say your object has a new schema. You can insert SalesOrderV2 objects without any
        # changes to the database tier.
        return self.container.create_item(body=item)


    def upsert_document(self, document, category_id = COSMOS_CATEGORYID):

        try:
            #document["categoryId"] = category_id
            return self.container.upsert_item(document)
        except Exception as e:
            logging.error(f"Upsert Document Exception: {e}")
            return None
