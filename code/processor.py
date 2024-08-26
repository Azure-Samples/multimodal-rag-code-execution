
import os
import shutil
import copy
import traceback


try:
    import code.doc_utils as doc_utils
    from code.doc_utils import *
except:
    import doc_utils
    from doc_utils import *


class Processor():

    def __init__(self, ingestion_params_dict):

        delete_existing_output_dir = ingestion_params_dict.get('delete_existing_output_dir', False)
        processing_mode_pdf = ingestion_params_dict.get('processing_mode_pdf', 'gpt-4-vision')
        processing_mode_docx = ingestion_params_dict.get('processing_mode_docx', 'document-intelligence')
        processing_mode_xlsx = ingestion_params_dict.get('processing_mode_xlsx', 'openpyxl')

        doc_path = ingestion_params_dict['doc_path'] 
        try:
            os.rename(doc_path, doc_path.replace(" ", "_"))
        except Exception as e:
            logc(f"Error Renaming Document: {doc_path}. Most likely the file already exists\n", e)
            
        ingestion_params_dict['doc_path'] = doc_path

        self.doc_path = ingestion_params_dict['doc_path']
        self.base_name = os.path.splitext(os.path.basename(self.doc_path))[0].strip().replace(" ", "_")
        self.extension = os.path.splitext(os.path.basename(self.doc_path))[1].strip().lower()

        if self.extension == '.pdf':
            self.processing_mode = processing_mode_pdf
            if self.processing_mode not in ['hybrid', 'gpt-4-vision', 'PyMuPDF', 'document-intelligence']:
                logc(f"Processing Mode Not Supported {self.processing_mode}. Defaulting to 'gpt-4-vision'")
                self.processing_mode = 'gpt-4-vision'

        elif self.extension == '.docx':
            self.processing_mode = processing_mode_docx
            if self.processing_mode not in ['py-docx', 'document-intelligence']:
                logc(f"Processing Mode Not Supported {self.processing_mode}. Defaulting to 'document-intelligence'")
                self.processing_mode = 'document-intelligence'

        elif (self.extension == '.xlsx') or (self.extension == '.csv'):
            self.processing_mode = processing_mode_xlsx
            if self.processing_mode not in ['openpyxl']:
                logc(f"Processing Mode Not Supported {self.processing_mode}. Defaulting to 'openpyxl'")
                self.processing_mode = 'openpyxl'                
        else:
            if self.processing_mode not in ['py-docx', 'document-intelligence']:
                logc(f"INFO: Processing Mode Not Supported for this file type.")

        ingestion_params_dict['processing_mode'] = self.processing_mode


        self.ingestion_pipeline_dict = create_ingestion_pipeline_dict(ingestion_params_dict)

        self.doc_path = self.ingestion_pipeline_dict['doc_path'] 
        self.ingestion_directory = self.ingestion_pipeline_dict['ingestion_directory']
        self.download_directory = self.ingestion_pipeline_dict.get('download_directory', os.path.join(self.ingestion_directory, 'downloads'))
        os.makedirs(self.download_directory, exist_ok=True)
        self.index_name = self.ingestion_pipeline_dict['index_name']
        self.num_threads = self.ingestion_pipeline_dict.get('num_threads', len([1 for x in gpt4_models if x['AZURE_OPENAI_RESOURCE'] is not None]))
        self.password = self.ingestion_pipeline_dict.get('password', None)
        self.models = self.ingestion_pipeline_dict.get('models', gpt4_models)
        self.vision_models = self.ingestion_pipeline_dict.get('models', gpt4_models)

        doc_proc_directory = self.ingestion_pipeline_dict['document_processing_directory'] 
        self.doc_proc_directory = self.ingestion_pipeline_dict['document_processing_directory'] 

        dict_path = os.path.join(doc_proc_directory, f'{self.base_name}.dict.txt')

        read_ingestion_dict = read_asset_file(dict_path)[0]

        if (read_ingestion_dict is not None) and (read_asset_file(dict_path)[0] != ''):
            read_ingestion_dict = json.loads(read_ingestion_dict)

            for k in read_ingestion_dict:
                self.ingestion_pipeline_dict[k] = read_ingestion_dict[k]

        processing_plan = read_asset_file(os.path.join(doc_proc_directory, f'{self.base_name}.processing_plan.txt'))[0].split(',')
        processing_plan = [p.strip() for p in processing_plan]

        logc("Found Processing Plan", processing_plan)

        index_processing_plan_path = os.path.join(self.ingestion_directory, f'{self.index_name}.processing_plan.txt')
        index_processing_plan = recover_json(read_asset_file(index_processing_plan_path)[0])

        if (index_processing_plan != ''):
            logc(f"Picking up index processing plan for extension {self.extension} and processing mode {self.processing_mode}", index_processing_plan)
            try:
                self.processing_plan = index_processing_plan[self.extension][self.processing_mode]
                logc(f"Picked up index processing plan from {index_processing_plan_path}\nProcessing Plan: {self.processing_plan}")
            except:
                self.develop_processing_plan()
            
            self.save_processing_plan()

        elif (processing_plan is None) or (processing_plan == ['']):
            logc("Picking up default processing plan")
            self.develop_processing_plan()
            self.save_processing_plan()
        else:
            logc("Picking up saved partial processing plan")
            self.processing_plan = processing_plan
            # self.resume_processing()

        self.initial_processing_plan = self.processing_plan

        if self.processing_mode == 'gpt-4-vision':
            self.ingestion_pipeline_dict['extract_text_mode'] = "GPT"
            self.ingestion_pipeline_dict['extract_images_mode'] = "GPT"
            self.ingestion_pipeline_dict['extract_text_from_images'] = True

        elif self.processing_mode == 'document-intelligence':
            self.ingestion_pipeline_dict['extract_text_mode'] = "PDF" ## this setting is ignored with doc-int
            self.ingestion_pipeline_dict['extract_images_mode'] = "PDF" ## this setting is ignored with doc-int
            self.ingestion_pipeline_dict['extract_text_from_images'] = False
            self.ingestion_pipeline_dict['extract_docint_tables_mode'] = "Markdown"

        elif self.processing_mode == 'hybrid': 
            self.ingestion_pipeline_dict['extract_text_mode'] = "PDF" ## this setting is ignored with doc-int
            self.ingestion_pipeline_dict['extract_images_mode'] = "PDF" ## this setting is ignored with doc-int

        logc("### INGESTING A NEW DOCUMENT")
        logc("doc_path:", self.doc_path)
        logc("ingestion_directory:", self.ingestion_directory)
        logc("index_name:", self.index_name)
        logc("delete_existing_output_dir:", delete_existing_output_dir)
        logc("num_threads:", self.num_threads)
        logc("processing mode", self.processing_mode)
        logc("---")            



    def develop_processing_plan(self):        
        self.processing_plan = ['create_pdf_chunks', 'pdf_extract_high_res_chunk_images', 'pdf_extract_text', 'pdf_extract_images', 'delete_pdf_chunks', 'post_process_images', 'extract_tables_from_images', 'post_process_tables']        



    def save_ingestion_dict_to_pickle(self):
        doc_proc_directory = self.ingestion_pipeline_dict['document_processing_directory'] 
        pkl_path = os.path.join(doc_proc_directory, f'{self.base_name}.pkl')

        if os.path.exists(pkl_path):
            ext = f".{get_current_time()}.pkl"
            shutil.copyfile(pkl_path, pkl_path + ext)

        save_to_pickle(self.ingestion_pipeline_dict, pkl_path)


    def save_ingestion_dict_to_text(self, stage):
        doc_proc_directory = self.ingestion_pipeline_dict['document_processing_directory'] 
        stages_dir = os.path.join(doc_proc_directory, 'stages')
        os.makedirs(stages_dir, exist_ok=True)

        dict_path = os.path.join(doc_proc_directory, f'{self.base_name}.dict.txt')
        dict_path_stage = os.path.join(stages_dir, f'{self.base_name}.{stage}.dict.txt')
        ingestion_dict = {}

        for k in self.ingestion_pipeline_dict:
            if k not in ['pdf_document', 'password', 'models', 'vision_models', 'num_threads']:                
                if k == 'chunks':
                    ingestion_dict[k] = []
                    for chunk_dict in self.ingestion_pipeline_dict[k]:
                        chunk_dict_copy = {}
                        for ck in chunk_dict:
                            if ck not in ['chunk']:
                                chunk_dict_copy[ck] = copy.deepcopy(chunk_dict[ck])
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
            if stage == "Completed": continue
            logc(f"Ingestion Stage {index+1}/{total_stages} of {full_basename}", f"Processing Stage: {stage}", verbose=verbose)
            try:
                self.ingestion_pipeline_dict = getattr(doc_utils, stage)(self.ingestion_pipeline_dict)
            except Exception as e:
                print(f"Exception in the {stage} stage.\nException:{e}\ntraceback_print: {str(traceback.print_exc())}\ntraceback_format: {str(traceback.format_exc())}")                        
                
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
        
        doc_filename = self.ingestion_pipeline_dict['original_document_filename']
        completed = os.path.join(doc_proc_directory, f'{doc_filename}.ingested')
        completed_downloads = os.path.join(self.download_directory, f'{doc_filename}.ingested')

        write_to_file('1', completed, mode='w')
        write_to_file('1', completed_downloads, mode='w')



    def ingest_document(self, verbose=False):
        doc_filename = self.ingestion_pipeline_dict['original_document_filename']
        completed_downloads = os.path.join(self.download_directory, f'{doc_filename}.ingested')

        if os.path.exists(completed_downloads):
            logc(f"Document Already Ingested: {doc_filename}", completed_downloads)
            return

        self.execute_processing_plan(verbose=verbose)
        self.commit_assets_to_vector_store()




class PdfProcessor(Processor):


    def develop_processing_plan(self):
        
        if self.processing_mode == 'gpt-4-vision':
            self.processing_plan = ['create_pdf_chunks', 'pdf_extract_high_res_chunk_images', 'pdf_extract_text', 'pdf_extract_images', 'delete_pdf_chunks', 'post_process_images', 'extract_tables_from_images', 'post_process_tables', 'generate_tags_for_all_chunks', 'generate_document_wide_tags', 'generate_document_wide_summary']

        elif self.processing_mode == 'document-intelligence':
            self.processing_plan = ['create_pdf_chunks', 'pdf_extract_high_res_chunk_images', 'delete_pdf_chunks', 'extract_doc_using_doc_int', 'create_doc_chunks_with_doc_int_markdown', 'post_process_images', 'generate_tags_for_all_chunks', 'generate_document_wide_tags', 'generate_document_wide_summary']

        elif self.processing_mode == 'hybrid': 
            self.processing_plan = ['create_pdf_chunks', 'pdf_extract_high_res_chunk_images', 'delete_pdf_chunks', 'extract_doc_using_doc_int', 'create_doc_chunks_with_doc_int_markdown', 'post_process_images', 'post_process_tables', 'generate_tags_for_all_chunks', 'generate_document_wide_tags', 'generate_document_wide_summary']



    def execute_processing_plan(self, verbose=False):
        super().execute_processing_plan(verbose=verbose)

        try:
            # Close the PDF document
            self.ingestion_pipeline_dict['pdf_document'].close()
        except:
            pass




class DocxProcessor(Processor):

    def develop_processing_plan(self):

        if self.processing_mode == 'py-docx':
            self.processing_plan = ['extract_docx_using_py_docx', 'create_doc_chunks_with_doc_int_markdown','post_process_images', 'generate_tags_for_all_chunks', 'generate_document_wide_tags', 'generate_document_wide_summary']

        elif self.processing_mode == 'document-intelligence':
            self.processing_plan = ['extract_doc_using_doc_int', 'create_doc_chunks_with_doc_int_markdown',  'post_process_images', 'generate_tags_for_all_chunks', 'generate_document_wide_tags', 'generate_document_wide_summary']
        else:
            logc("Processing Mode Not Supported - defaulting to 'py-docx'")
            self.processing_plan = ['extract_docx_using_py_docx', 'create_doc_chunks_with_doc_int_markdown', 'post_process_images', 'generate_tags_for_all_chunks', 'generate_document_wide_tags', 'generate_document_wide_summary']
            
            

        

class XlsxProcessor(Processor):

    def develop_processing_plan(self):
        self.processing_plan = ['extract_xlsx_using_openpyxl', 'create_table_doc_chunks_markdown', 'create_image_doc_chunks', 'generate_tags_for_all_chunks', 'generate_document_wide_tags', 'generate_document_wide_summary']




class AudioProcessor(Processor):

    def develop_processing_plan(self):
        self.processing_plan = ['extract_audio_using_whisper', 'create_doc_chunks_with_doc_int_markdown',  'generate_tags_for_all_chunks', 'generate_document_wide_tags', 'generate_document_wide_summary']




def ingest_doc_using_processors(ingestion_params_dict):
    doc_path = ingestion_params_dict['doc_path']
    verbose = ingestion_params_dict.get('verbose', False)

    extension = os.path.splitext(os.path.basename(doc_path))[1].strip()

    if extension == '.pdf':
        processor = PdfProcessor(ingestion_params_dict)

    elif extension == '.docx':
        processor = DocxProcessor(ingestion_params_dict)

    elif (extension == '.xlsx') or (extension == '.csv'):
        processor = XlsxProcessor(ingestion_params_dict)

    else:
        logc("Document Type Not Supported", extension)
        return

    processor.ingest_document(verbose=verbose)

    return processor.ingestion_pipeline_dict



def ingest_docs_directory_using_processors(ingestion_params_dict):
    assets = []

    directory = ingestion_params_dict['download_directory']

    # Walk through the directory
    for root, dirs, files in os.walk(directory):
        for file in files:
            # Check if the file is already ingested
            ingested = os.path.join(root, f"{file}.ingested")
            if not os.path.exists(ingested):
                logc(f"Ingesting Document: {file}")
                # Construct the full file path
                os.rename(file, file.replace(" ", "_"))
                file_path = os.path.join(root, file)

                ingestion_params_dict['doc_path'] = file_path

                # Call ingest_doc on the file
                assets.append(ingest_doc_using_processors(ingestion_params_dict))
            else:
                logc(f"Skipping file. Document Already Ingested: {file}")

    return assets 