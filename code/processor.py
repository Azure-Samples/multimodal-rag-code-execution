
import os
import shutil
import copy
import doc_utils
from doc_utils import *


class Processor():

    def __init__(   
                self, 
                doc_path, 
                ingestion_directory = None, 
                index_name = 'mm_doc_analysis', 
                delete_existing_output_dir = False,
                password = None, 
                extract_text_mode="GPT", 
                extract_images_mode="GPT", 
                extract_text_from_images=True, 
                models = gpt4_models, 
                vision_models = gpt4_models, 
                num_threads=7
            ):
        
        self.valid_processing_stages = ['pdf_extract_high_res_chunk_images', 'pdf_extract_text', 'harvest_code', 'pdf_extract_images', 'delete_pdf_chunks', 'post_process_images', 'extract_tables_from_images', 'post_process_tables']

        self.base_name = os.path.splitext(os.path.basename(doc_path))[0].strip()
        self.extension = os.path.splitext(os.path.basename(doc_path))[1].strip()

        self.doc_path = doc_path
        self.ingestion_directory = ingestion_directory
        self.index_name = index_name
        self.models = models
        self.vision_models = vision_models
        self.num_threads = num_threads
        self.extract_text_mode = extract_text_mode
        self.extract_images_mode = extract_images_mode
        self.extract_text_from_images = extract_text_from_images
        self.password = password

        self.ingestion_pipeline_dict = create_ingestion_pipeline_dict(doc_path, ingestion_directory = ingestion_directory, index_name = 
        index_name, delete_existing_output_dir = delete_existing_output_dir, password = password, extract_text_mode=extract_text_mode, extract_images_mode=extract_images_mode, extract_text_from_images=extract_text_from_images, models = models, vision_models = vision_models, num_threads=num_threads)

        doc_proc_directory = self.ingestion_pipeline_dict['document_processing_directory'] 

        dict_path = os.path.join(doc_proc_directory, f'{self.base_name}.dict.txt')

        read_ingestion_dict = read_asset_file(dict_path)[0]

        if (read_ingestion_dict is not None) and (read_asset_file(dict_path)[0] != ''):
            read_ingestion_dict = json.loads(read_ingestion_dict)

            for k in read_ingestion_dict:
                self.ingestion_pipeline_dict[k] = read_ingestion_dict[k]

        processing_plan = read_asset_file(os.path.join(doc_proc_directory, f'{self.base_name}.processing_plan.txt'))[0].split(',')
        processing_plan = [p.strip() for p in processing_plan]

        logc("Found Processing Plan", processing_plan)

        if (processing_plan is None) or (processing_plan == ['']):
            self.develop_processing_plan()
            self.save_processing_plan()
        else:
            self.processing_plan = processing_plan
            # self.resume_processing()


    def develop_processing_plan(self):
        self.processing_plan = ['create_pdf_chunks', 'pdf_extract_high_res_chunk_images', 'pdf_extract_text', 'harvest_code', 'pdf_extract_images', 'delete_pdf_chunks', 'post_process_images', 'extract_tables_from_images', 'post_process_tables']



    def save_ingestion_dict_to_pickle(self):
        doc_proc_directory = self.ingestion_pipeline_dict['document_processing_directory'] 
        pkl_path = os.path.join(doc_proc_directory, f'{self.base_name}.pkl')

        if os.path.exists(pkl_path):
            ext = f".{get_current_time()}.pkl"
            shutil.copyfile(pkl_path, pkl_path + ext)

        save_to_pickle(self.ingestion_pipeline_dict, pkl_path)


    def save_ingestion_dict_to_text(self, stage):
        doc_proc_directory = self.ingestion_pipeline_dict['document_processing_directory'] 
        dict_path = os.path.join(doc_proc_directory, f'{self.base_name}.dict.txt')
        dict_path_stage = os.path.join(doc_proc_directory, f'{self.base_name}.{stage}.dict.txt')
        ingestion_dict = {}

        for k in self.ingestion_pipeline_dict:
            if k not in ['pdf_document', 'password', 'models', 'vision_models', 'num_threads']:                
                if k == 'chunks':
                    ingestion_dict[k] = []
                    for chunk_dict in self.ingestion_pipeline_dict[k]:
                        chunk_dict_copy = {}
                        for ck in chunk_dict:
                            if ck not in ['chunk']:
                                chunk_dict_copy[ck] = chunk_dict[ck]
                        ingestion_dict[k].append(chunk_dict_copy)
                else:
                    ingestion_dict[k] = self.ingestion_pipeline_dict[k]

        write_to_file(json.dumps(ingestion_dict, indent=4), dict_path_stage, mode='w')        
        write_to_file(json.dumps(ingestion_dict, indent=4), dict_path, mode='w')



    def save_processing_plan(self, save_proc_plan=None):
        doc_proc_directory = self.ingestion_pipeline_dict['document_processing_directory']
        processing_plan_path = os.path.join(doc_proc_directory, f'{self.base_name}.processing_plan.txt')
        
        if save_proc_plan is not None:
            logc("Saving Processing Plan", save_proc_plan)
            write_to_file(','.join(save_proc_plan), processing_plan_path, mode='w')
        else:
            logc("Saving Processing Plan", self.processing_plan)
            write_to_file(','.join(self.processing_plan), processing_plan_path, mode='w')        


    def execute_processing_plan(self, verbose=False):

        full_basename = os.path.basename(self.doc_path)
        total_stages = len(self.processing_plan)
        save_proc_plan = copy.deepcopy(self.processing_plan)

        for index, stage in enumerate(self.processing_plan):
            logc(f"Ingestion Stage {index+1}/{total_stages} of {full_basename}", f"Processing Stage: {stage}", verbose=verbose)
            self.ingestion_pipeline_dict = getattr(doc_utils, stage)(self.ingestion_pipeline_dict)
            save_proc_plan.remove(stage)
            if len(save_proc_plan) == 0: save_proc_plan = ['Completed']
            self.save_processing_plan(save_proc_plan=save_proc_plan)
            self.save_ingestion_dict_to_text(stage)
        
        vec_entries = len(self.ingestion_pipeline_dict['text_files'] + self.ingestion_pipeline_dict['image_text_files'] + self.ingestion_pipeline_dict['table_text_files'])

        logc(f"Ingestion Stage of {self.base_name} Complete", f"{get_current_time()}: Ingestion of document {self.base_name} resulted in {vec_entries} entries in the Vector Store", verbose=verbose)

        self.save_ingestion_dict_to_pickle()


    def commit_assets_to_vector_store(self):
        self.ingestion_pipeline_dict['index_ids'], self.ingestion_pipeline_dict['vecstore_metadatas'] = commit_assets_to_vector_index(self.ingestion_pipeline_dict, self.ingestion_directory, self.index_name)

        metadatas = copy.deepcopy(self.ingestion_pipeline_dict['vecstore_metadatas'])
        for p in metadatas: del p['vector']

        doc_proc_directory = self.ingestion_pipeline_dict['document_processing_directory'] 
        vecstore_items_path = os.path.join(doc_proc_directory, f'{self.base_name}.vecstore.txt')
        write_to_file(json.dumps(metadatas, indent=4), vecstore_items_path, mode='w')



    def ingest_document(self, verbose=False):
        self.execute_processing_plan(verbose=verbose)
        self.commit_assets_to_vector_store()




class PdfProcessor(Processor):

    def develop_processing_plan(self):
        self.processing_plan = ['create_pdf_chunks', 'pdf_extract_high_res_chunk_images', 'pdf_extract_text', 'harvest_code', 'pdf_extract_images', 'delete_pdf_chunks', 'post_process_images', 'extract_tables_from_images', 'post_process_tables']


    def execute_processing_plan(self, verbose=False):
        super().execute_processing_plan(verbose=verbose)

        # Close the PDF document
        self.ingestion_pipeline_dict['pdf_document'].close()




class DocxProcessor(Processor):

    def develop_processing_plan(self):
        self.processing_plan = ['extract_docx_using_py_docx', 'create_docx_chunks', 'harvest_code', 'post_process_images']


        

