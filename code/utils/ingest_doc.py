import argparse
import logging
import os
import sys
sys.path.append("../code")
from doc_utils import ingest_doc

#Cosmos will be used to store the indexing process
import utils.cosmos_helpers as cs
cosmos = cs.SCCosmosClient(container_name="indexing_logs")

LOG_CONTAINER_NAME = os.getenv("COSMOS_LOG_CONTAINER")
# Create an argument parser
parser = argparse.ArgumentParser(description='Ingest documents.')

# Add the required arguments
parser.add_argument('--download_directory', type=str, help='Path to the download directory')
parser.add_argument('--ingestion_directory', type=str, help='Path to the ingestion directory')
parser.add_argument('--text_extraction', type=str, help='Text extraction mode')
parser.add_argument('--image_extraction', type=str, help='Image extraction mode')
parser.add_argument('--text_from_images', type=str, help='Text extraction from images mode')
parser.add_argument('--index_name', type=str, help='Name of the index')
parser.add_argument('--number_threads', type=int, help='Number of threads')
parser.add_argument('--pdf_password', type=str, help='Password for PDF files')
parser.add_argument('--delete_ingestion_folder', type=str, help='Delete existing ingestion folder')

# Parse the command-line arguments
args = parser.parse_args()

# Access the arguments
download_directory = args.download_directory
ingestion_directory = args.ingestion_directory
text_extraction = args.text_extraction
image_extraction = args.image_extraction
text_from_images = bool(args.text_from_images)
index_name = args.index_name
number_threads = int(args.number_threads)
pdf_password = args.pdf_password
delete_ingestion_folder = bool(args.delete_ingestion_folder)

def create_indexing_logs(index_name):
     
    files_object = []
    for root, dirs, files in os.walk(download_directory):
        for file in files:
            files_object.append({
                "file_name": file.lower(),
                "status": 'Not ingested'
            })

    progress_object = {
        "id": index_name, #using the index name as the id
        "indexId": index_name,
        "files_uploaded": files_object
    }
    try:
        cosmos.create_document(progress_object)
    except Exception as e:
        logging.error(f"Error creating log document: {e}")

try:
    indexing_document = create_indexing_logs(index_name)      
except Exception as e:
    logging.error(f"Failed to get the document by ID {index_name}")
    raise e

for root, dirs, files in os.walk(download_directory):

        for file in files:
            # Check if the file is a PDF
            if file.lower().endswith('.pdf'):
                try:
                    indexing_document['files_uploaded'][file.lower()].status = 'Ingesting...'
                    cosmos.upsert_document(indexing_document, category_name="indexing_logs")
                    file_path = os.path.join(root, file)
                    # Call ingest_doc on the file
                    ingest_doc(
                        file_path, ingestion_directory=ingestion_directory, 
                        extract_text_mode=text_extraction,
                        extract_images_mode=image_extraction,
                        extract_text_from_images=text_from_images,
                        index_name=index_name,
                        num_threads=number_threads,
                        password=pdf_password,
                        delete_existing_output_dir=delete_ingestion_folder)
                    indexing_document['files_uploaded'][file.lower()].status = 'Ingested' 
                    cosmos.upsert_document(indexing_document, category_name="indexing_logs")
                except Exception as e:
                    #delete the indexing_document from Cosmos DB
                    cosmos.delete_document(index_name, index_name)


