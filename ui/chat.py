import os
import requests

from dotenv import load_dotenv
load_dotenv()

import logging
from ui_log_utils import setup_logger
setup_logger()

import chainlit as cl
from chainlit import run_sync

INITIAL_INDEX = os.environ.get('INITIAL_INDEX', 'rag-data')
SEARCH_TOP_N = os.environ.get('SEARCH_TOP_N', '5')
BUILD_ID = os.environ.get('BUILD_ID', '1.0.0')

def log_message(message, level = 'info'):
    if level == 'debug':
        logging.debug(message)
    elif level == 'info':
        logging.info(message)
    elif level == 'warning':
        logging.warning(message)
    elif level == 'error':
        logging.error(message)
    elif level == 'critical':
        logging.critical(message)
    else:
        logging.info('Invalid log level, defaulting to info')
        logging.info(message)
        

def replace_extension(asset_path, new_extension):
    base_name = os.path.splitext(asset_path)[0].strip()

    return f"{base_name}{new_extension}"

class APIClient:
    def __init__(self):
        self.base_url = os.getenv('API_BASE_URL').strip("/")

    def get_models(self):
        try:
            response = requests.get(f"{self.base_url}/models")
            response.raise_for_status()
            return response.json()
        except requests.exceptions.HTTPError as e:
            logging.error(f"Error retrieving models: {e}")
            raise

    def get_prompts(self):
        try:
            response = requests.get(f"{self.base_url}/prompt")
            response.raise_for_status()
            return response.json()
        except requests.exceptions.HTTPError as e:
            logging.error(f"Error retrieving prompts: {e}")
            raise

    def get_prompt(self, p):
        try:
            response = requests.get(f'{self.base_url}/prompt/{p}')
            response.raise_for_status()
            return response.json()
        except requests.exceptions.HTTPError as e:
            logging.error(f"Error retrieving prompt {p}: {e}")
            raise

    # def ingest_docs(self, ingestion_params):
    #     try:
    #         response = requests.post(f"{self.base_url}/ingest", json=ingestion_params)
    #         response.raise_for_status()
    #         return response.json()
    #     except requests.exceptions.HTTPError as e:
    #         logging.error(f"Error ingesting documents: {e}")
    #         raise

    def get_file(self, asset_path):
        try:
            response = requests.get(f"{self.base_url}/file", params={'asset_path': asset_path})
            response.raise_for_status()
            return response.text
        except requests.exceptions.HTTPError as e:
            logging.error(f"Error retrieving file {asset_path}: {e}")
            raise
        
    def get_file_url(self, asset_path, format = "text"):
        return f"{self.base_url}/file?asset_path={asset_path}&format={format}"

    def check_file_exists(self, asset_path):
        try:
            response = requests.get(f"{self.base_url}/file_exists", params={'asset_path': asset_path})
            response.raise_for_status()
            return response.json()
        except requests.exceptions.HTTPError as e:
            logging.error(f"Error checking file {asset_path}: {e}")
            raise

    def search(self, query_params):
        try:
            response = requests.post(f"{self.base_url}/search", json=query_params)
            response.raise_for_status()            
            return response.json()
        except requests.exceptions.HTTPError as e:
            logging.error(f"Error searching: {e}")
            raise

    def upload_files(self, index_name, files):
        try:
            response = requests.post(f"{self.base_url}/index/{index_name}/files", files=files)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.HTTPError as e:
            logging.error(f"Error uploading files: {e}")
            raise

api_client = APIClient()

init_index_name = INITIAL_INDEX

gpt4_models = api_client.get_models()
available_models = len([1 for x in gpt4_models if x['AZURE_OPENAI_RESOURCE'] is not None])

init_code_interpreter = "NoComputationTextOnly"
init_code_interpreter = "Taskweaver"
init_code_interpreter = "AssistantsAPI"

init_password = ''
init_approx_tag_limit = '5'
init_pdf_extraction_mode = 'hybrid'
init_docx_extraction_modes = 'document-intelligence'
init_number_of_threads = available_models
init_delete_existing_output_directory = False
init_top_n = int(SEARCH_TOP_N)


user_sessions = {}
index_names = {}
passwords = {}
approx_tag_limits = {}
pdf_extraction_modes = {}
docx_extraction_modes = {}
number_of_threads = {}
delete_existing_output_directory = {}
code_interpreters = {}
conversations = {}
top_ns = {}

async def post_message(label, message):
    async with cl.Step(name=label) as step:
        step.output = message

    # log_message(f"{str(label)}: {str(message)}")

def post_message_sync(label, message):
    run_sync(post_message(label, message))

# FIXME
# doc_utils.log_ui_func_hook = post_message_sync

def get_prompts():
    prompts = {}
    prompts_json = api_client.get_prompts()

    for prompt in prompts_json:
        section_contents = ''
        if 'Sections' in prompt: section_contents = [c for c in prompt['Sections'] if isinstance(c, str)]
        prompts[prompt['Category']] = prompt['Content'] + "\n\n" + "\n\n".join(section_contents)

    return prompts

try:
    prompts = get_prompts()
except Exception as e:
    log_message(f"Error getting prompts from Cosmos: {e}", 'error')
    prompts = []

async def update_task_list():
    index_name = index_names[cl.user_session.get("id")]
    password = passwords[cl.user_session.get("id")]
    approx_tag_limit = approx_tag_limits[cl.user_session.get("id")]
    pdf_extraction_mode = pdf_extraction_modes[cl.user_session.get("id")]
    docx_extraction_mode = docx_extraction_modes[cl.user_session.get("id")]
    number_of_thread = number_of_threads[cl.user_session.get("id")]
    delete_existing_output_directories = delete_existing_output_directory[cl.user_session.get("id")]
    code_interpreter = code_interpreters[cl.user_session.get("id")]
    top_n = top_ns[cl.user_session.get("id")]

    # Create the TaskList
    task_list = cl.TaskList()
    task_list.status = "Test Configuration"

    # Add tasks to the task list
    task_build_id = cl.Task(title=f"Build ID: {BUILD_ID}", status=cl.TaskStatus.DONE)
    task_index_name = cl.Task(title=f"Index Name: {index_name}", status=cl.TaskStatus.DONE)
    task_password = cl.Task(title=f"PDF Password: {password}", status=cl.TaskStatus.DONE)
    task_approx_tag_limit = cl.Task(title=f"Search Tags Limit: {approx_tag_limit}", status=cl.TaskStatus.DONE)
    task_pdf_extraction_mode = cl.Task(title=f"PDF Extraction Mode: {pdf_extraction_mode}", status=cl.TaskStatus.DONE)
    task_docx_extraction_mode = cl.Task(title=f"Docx Extractoin Mode: {docx_extraction_mode}", status=cl.TaskStatus.DONE)
    task_number_of_thread = cl.Task(title=f"Number of Threads: {number_of_thread}", status=cl.TaskStatus.DONE)
    task_delete_existing_output_directories = cl.Task(title=f"Delete Existing Ingestion Directory: {delete_existing_output_directories}", status=cl.TaskStatus.DONE)
    task_code_interpreter = cl.Task(title=f"Code Interpreter: {code_interpreter}", status=cl.TaskStatus.DONE)
    task_top_n = cl.Task(title=f"Top N Search Results: {top_n}", status=cl.TaskStatus.DONE)


    # Add tasks to the task list
    await task_list.add_task(task_build_id)
    await task_list.add_task(task_index_name)
    await task_list.add_task(task_password)
    await task_list.add_task(task_pdf_extraction_mode)
    await task_list.add_task(task_docx_extraction_mode)
    await task_list.add_task(task_number_of_thread)
    await task_list.add_task(task_delete_existing_output_directories)
    await task_list.add_task(task_code_interpreter)
    await task_list.add_task(task_approx_tag_limit)
    await task_list.add_task(task_top_n)

    # Update the task list in the interface
    await task_list.send()

@cl.on_chat_start
async def start():
    user_sessions[cl.user_session.get("id")] = {}
    index_names[cl.user_session.get("id")] = init_index_name
    passwords[cl.user_session.get("id")] = init_password
    approx_tag_limits[cl.user_session.get("id")] = init_approx_tag_limit
    pdf_extraction_modes[cl.user_session.get("id")] = init_pdf_extraction_mode
    docx_extraction_modes[cl.user_session.get("id")] = init_docx_extraction_modes
    number_of_threads[cl.user_session.get("id")] = init_number_of_threads
    delete_existing_output_directory[cl.user_session.get("id")] = init_delete_existing_output_directory
    code_interpreters[cl.user_session.get("id")] = init_code_interpreter
    top_ns[cl.user_session.get("id")] = init_top_n
    await update_task_list()

async def generate_prompt(p):
    try:
        prompt = api_client.get_prompt(p)
        log_message(f"Generating the contents for the prompt: {prompt}")
        await app_search(prompt)
    except:
        await app_search(p)


# @cl.action_callback('Business Overview')
# async def on_action(action):
#     await generate_prompt(action.value)

# @cl.action_callback('Executive Summary')
# async def on_executive_summary(action):
#     await generate_prompt(action.value)

# @cl.action_callback('Historical Financials')
# async def on_historical_financials(action):
#     await generate_prompt(action.value)

# @cl.action_callback('Industry Overview')
# async def on_industry_overview(action):
#     await generate_prompt(action.value)

# @cl.action_callback('Preliminary Return Analysis')
# async def on_preliminary_return_analysis(action):
#     await generate_prompt(action.value)

# @cl.action_callback('Products Overview')
# async def on_products_overview(action):
#     await generate_prompt(action.value)

# def ingest_docs_directory_using_processors(ingestion_params):
#     try:
#         api_client.ingest_docs(ingestion_params)
#     except Exception as e:
#         log_message(f"Error ingesting documents: {e}", 'error')
    
@cl.on_message
async def main(message: cl.Message):
    message_content = message.content.strip().lower()

    if conversations.get(cl.user_session.get("id")) is None:
        log_message("INITIALIZING HISTORY")
        conversations[cl.user_session.get("id")] = []
    

    if message_content.startswith('cmd'):
        cmd = message_content[4:]
        
        if cmd == 'index':
            res = await cl.AskUserMessage(content="What is the index name?", timeout=1000).send()
            if res:
                index_name = res['output'].strip()
                index_names[cl.user_session.get("id")] = index_name
                await update_task_list()

        elif cmd == 'password':
            res = await cl.AskUserMessage(content="What is the PDF password?", timeout=1000).send()
            if res:
                password = res['output'].strip()
                passwords[cl.user_session.get("id")] = password
                await update_task_list()

        elif cmd == 'tag_limit':
            res = await cl.AskUserMessage(content="What is tag limit for Search?", timeout=1000).send()
            if res:
                approx_tag_limit = res['output'].strip().upper()
                try:
                    approx_tag_limit = int(approx_tag_limit)
                    if approx_tag_limit < 1: approx_tag_limit = 1
                    approx_tag_limits[cl.user_session.get("id")] = approx_tag_limit
                    await update_task_list()
                except:
                    approx_tag_limits[cl.user_session.get("id")] = 15
                    await update_task_list()
                    await cl.Message(content="Invalid tags limit. Please choose a valid integer value.").send()


        elif cmd == 'pdf_mode':
            res = await cl.AskUserMessage(content="What is the PDF extraction mode?", timeout=1000).send()
            if res:
                pdf_extraction_mode = res['output'].strip().upper()
                if pdf_extraction_mode in ['gpt-4-vision', 'document-intelligence']:
                    pdf_extraction_modes[cl.user_session.get("id")] = pdf_extraction_mode
                    await update_task_list()
                else:
                    await cl.Message(content="Invalid images detection and extraction mode. Please choose from 'GPT' or 'PDF'.").send()

        elif cmd == 'docx_mode':
            res = await cl.AskUserMessage(content="What is the Docx extraction mode?", timeout=1000).send()
            if res:
                docx_extraction_mode = res['output'].strip().lower()
                if docx_extraction_mode in ['document-intelligence', 'py-docx']: 
                    docx_extraction_mode = True
                else: 
                    docx_extraction_mode = False
                docx_extraction_modes[cl.user_session.get("id")] = docx_extraction_mode
                await update_task_list()
        
        elif cmd == 'threads': 
            res = await cl.AskUserMessage(content="Number of threads?", timeout=1000).send()
            if res:
                log_message(res)
                number_of_thread = res['output'].strip()
                try:
                    number_of_thread = int(number_of_thread)
                    if number_of_thread < 1: number_of_thread = 1
                    number_of_threads[cl.user_session.get("id")] = number_of_thread
                    await update_task_list()
                except:
                    pass

        elif cmd == 'topN': 
            res = await cl.AskUserMessage(content="What is the Top N for the Search Results?", timeout=1000).send()
            if res:
                log_message(res)
                new_topn = res['output'].strip()
                try:
                    new_topn = int(new_topn)
                    if new_topn < 1: new_topn = 3
                    top_ns[cl.user_session.get("id")] = new_topn
                    await update_task_list()
                except:
                    pass
                
        elif cmd == 'ci':
            res = await cl.AskUserMessage(content="What is the code interpreter?", timeout=1000).send()
            if res:
                code_interpreter = res['output'].strip()
                if code_interpreter in ["NoComputationTextOnly", "Taskweaver", "AssistantsAPI",  "LocalPythonExec"]:
                    code_interpreters[cl.user_session.get("id")] = code_interpreter
                    await update_task_list()
                else:
                    await cl.Message(content="Invalid code interpreter. Please choose from 'NoComputationTextOnly', 'Taskweaver', 'AssistantsAPI', or 'LocalPythonExec'. The name is case-sensitive.").send()

        elif cmd == 'delete_dir':
            res = await cl.AskUserMessage(content="Delete existing output directory?", timeout=1000).send()
            if res:
                delete_existing_output_directories = res['output'].strip()
                if delete_existing_output_directories in ['yes', 'true']: 
                    delete_existing_output_directories = True
                else:
                    delete_existing_output_directories = False
                delete_existing_output_directory[cl.user_session.get("id")] = delete_existing_output_directories
                await update_task_list()


        elif cmd == "upload":
            index_name = index_names[cl.user_session.get("id")]

            # while files == None:
            files = await cl.AskFileMessage(content="Please upload the file.", 
                                            accept=["text/csv",
                                                    "application/pdf", 
                                                    "application/msword",
                                                    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                                                    "application/vnd.ms-excel",
                                                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"], 
                                            max_size_mb = 100,
                                            max_files = 100,
                                            timeout=1000).send()
            if files:
                files_to_upload = []
                for file in files:          
                    files_to_upload.append(('files', (file.name, open(file.path, 'rb'), file.type)))
                api_client.upload_files(index_name, files_to_upload)
                
                filenames = [file.name for file in files]
                fns = ', '.join(filenames)
                await cl.Message(content=f"File(s) '{fns}' have been uploaded'.").send()


        # elif cmd == "ingest":      
        #     index_name = index_names[cl.user_session.get("id")]
            
        #     await cl.Message(content=f"Starting ingestion into '{index_name}'.").send()

        #     log_message("\n\nIngestion Variables:")
        #     log_message(f"index_name: {index_names[cl.user_session.get('id')]}")
        #     log_message(f"password: {passwords[cl.user_session.get('id')]}")
        #     log_message(f"approx_tag_limit: {approx_tag_limits[cl.user_session.get('id')]}")
        #     log_message(f"pdf_extraction_mode: {pdf_extraction_modes[cl.user_session.get('id')]}")
        #     log_message(f"docx_extraction_mode: {docx_extraction_modes[cl.user_session.get('id')]}")
        #     log_message(f"number_of_threads: {number_of_threads[cl.user_session.get('id')]}")
        #     log_message(f"delete_existing_output_directory: {delete_existing_output_directory[cl.user_session.get('id')]}")

        #     ingestion_params_dict = {
        #         "index_name" : index_name,
        #         'num_threads' : available_models,
        #         "password" : passwords[cl.user_session.get("id")],
        #         "delete_existing_output_dir" : delete_existing_output_directory[cl.user_session.get("id")],
        #         "processing_mode_pdf" : pdf_extraction_modes[cl.user_session.get("id")],
        #         "processing_mode_docx" : docx_extraction_modes[cl.user_session.get("id")],
        #         'verbose': True
        #     }
        #     # FIXME: param required but not passed
        #     # ingestion_params_dict['doc_path']

        #     await cl.make_async(ingest_docs_directory_using_processors)(ingestion_params_dict)

        #     await cl.Message(content=f"Ingestion into '{index_name}' complete.").send()

        elif cmd == "gen":
            try:
                prompts = get_prompts()
            except Exception as e:
                log_message(f"Error getting prompts from Cosmos: {e}")
                prompts = []

            for title, prompt in prompts.items():            
                @cl.action_callback(title)
                async def on_action(action):
                    await generate_prompt(action.value)

            actions = [
                cl.Action(name=k, value=v, description=v) for k, v in prompts.items()
            ]

            await cl.Message(content="Please choose which prompt to generate:", actions=actions).send()

    else:
        await app_search(message.content)

# Get a file from API
def get_asset_file(asset):
    try:
        return api_client.get_file(asset)
    except Exception as e:
        log_message(f"Error reading asset file: {e}", 'error')    

def search(query, learnings = None, top=3, approx_tag_limit=3, conversation_history = [], user_id = None, computation_approach = "AssistantsAPI", computation_decision = "LLM", vision_support = False, include_master_py=True, vector_directory = None, vector_type = "AISearch", index_name = 'mm_doc_analysis', full_search_output = True, count=False, token_limit = 100000, temperature = 0.2, verbose = False):
    try:
        return api_client.search({
            "query": query,
            "top": top,
            "approx_tag_limit": approx_tag_limit,
            "conversation_history": conversation_history,
            "user_id": user_id,
            "computation_approach": computation_approach,
            "computation_decision": computation_decision,
            "vision_support": vision_support,
            "include_master_py": include_master_py,
            "vector_directory": vector_directory,
            "vector_type": vector_type,
            "index_name": index_name,
            "full_search_output": full_search_output,
            "count": count,
            "token_limit": token_limit,
            "temperature": temperature,
            "verbose": verbose
        })
    except Exception as e:
        log_message(f"Error searching documents: {e}", 'error')


async def app_search(query: str):   
    session_id = conversations[cl.user_session.get("id")]
    log_message(f"Conversation History {session_id}")

    final_answer, references, output_excel, search_results, files, steps = await cl.make_async(search)(
        query, 
        top=top_ns[cl.user_session.get("id")], 
        approx_tag_limit = approx_tag_limits[cl.user_session.get("id")],
        conversation_history = conversations[cl.user_session.get("id")],
        user_id = cl.user_session.get("id"),
        computation_approach = code_interpreters[cl.user_session.get("id")], 
        computation_decision = "LLM", 
        vision_support = False, 
        include_master_py=True, 
        vector_type = "AISearch", 
        index_name = index_names[cl.user_session.get("id")], 
        count=False, 
        verbose = False)
    
    if steps:
        for [message, text] in steps:
            post_message_sync(message, text)

    final_elements = []

    session_id = conversations[cl.user_session.get("id")]
    conversations[cl.user_session.get("id")].append({"role": "user", "content": query})
    conversations[cl.user_session.get("id")].append({"role": "assistant", "content": final_answer})
    log_message(f"Conversation History1: {session_id}")
    conversations[cl.user_session.get("id")] = conversations[cl.user_session.get("id")][-6:]
    log_message(f"Conversation History2: {session_id}")

    for f in files:
        url = api_client.get_file_url(replace_extension(f['asset'], '.jpg'), format="binary")
        if f['type'] == 'assistant_image':
            final_elements.append(cl.Image(name=os.path.basename(f['asset']), url=url, size='large', display="inline"))
        elif f['type'] == 'file':
            if f['asset'].endswith('.jpg') or f['asset'].endswith('.png'):
                final_elements.append(cl.Image(name=os.path.basename(f['asset']), url=url, size='large', display="inline"))
            elif f['asset'].endswith('.pdf'):
                final_elements.append(cl.Pdf(name="Results PDF", url=url, display="inline"))
            else:
                final_elements.append(cl.File(name="Results File", url=url, display="inline"))
        
    id_m = await cl.Message(content=final_answer, elements = final_elements).send()

    pdfs = [p['document_path'] for p in references]
    pdfs = list(set(pdfs))

    if (output_excel != "")  and (output_excel is not None):
        try:
            url = api_client.get_file_url(output_excel, format="binary")
            async with cl.Step(name=f"Search Results",  elements = [cl.File(name="Results Excel", url=url, display="inline")]) as step:
                step.output = f"Excel Document '{os.path.basename(output_excel)}'\nThe below has been taken from **{os.path.basename(output_excel)}**."
        except Exception as e:
            log_message(f"Error in output_excel message{output_excel}\n{e}", 'error')


    for index, ref in enumerate(files + references):
        try:
            text = get_asset_file(ref['asset'])
            if text == '':
                text = f"Current working directory {os.path.abspath(os.getcwd())}\nFile Abs Path: {os.path.abspath(ref['asset'])}"

            if ref['type'] == 'text':
                e = [cl.Text(name=f"Text below:", content=text, display="inline")]
            elif ref['type'] == 'image':
                url = api_client.get_file_url(replace_extension(ref['asset'], '.jpg'), format="binary")
                e = [cl.Image(name=os.path.basename(ref['asset']), url=url, size='large', display="inline"), # FIXME
                        cl.Text(name=f"Text below:", content=text, display="inline")]
            elif ref['type'] == 'table':
                e = []
                pngExists = api_client.check_file_exists(replace_extension(ref['asset'], '.png'))                
                if pngExists:
                    url = api_client.get_file_url(replace_extension(ref['asset'], '.png'), format="binary")
                    e.append(cl.Image(name=os.path.basename(ref['asset']), url=url, size='large', display="inline"))
                    e.append(cl.Text(name=f"Text below:", content=text, display="inline"))
                if api_client.check_file_exists(ref['asset']):
                    e.append(cl.Text(name=f"Text below:", content=text, display="inline"))
            elif ref['type'] == 'file':
                url = api_client.get_file_url(ref['asset'], format="binary")
                e = [cl.File(name="Results File", url=url, display="inline")]
            elif ref['type'] == 'assistant_image':
                url = api_client.get_file_url(replace_extension(ref['asset'], '.jpg'), format="binary")
                e = [cl.Image(name=os.path.basename(ref['asset']), url=url, size='large', display="inline")]           

            async with cl.Step(name=f"Search References",  elements = e) as step:
                try:
                    step.output = f"### Search Result #{ref['search_result_number']}\nThe below has been taken from **{ref['original_document']}**.\n[Open Document]({ref['sas_link']})"
                except:
                    step.output = f"File Generated by Code Interpreter."

        except Exception as e:
            log_message(f"Error in file message {index} - {ref['asset']}\n{e}", 'error')


    for pdf in pdfs:
        if pdf.endswith('.pdf'):
            try:
                url = api_client.get_file_url(pdf, format="binary")
                log_message(f"PDF URL: {url}")
                async with cl.Step(name=f"Search References",  elements = [cl.Pdf(name="PDF", url=url, display="inline")]) as step:
                    step.output = f"Document '{os.path.basename(pdf)}'\nThe below has been taken from **{os.path.basename(pdf)}**."
            except Exception as e:
                log_message(f"Error in pdf message: {pdf}\n{e}", 'error')
