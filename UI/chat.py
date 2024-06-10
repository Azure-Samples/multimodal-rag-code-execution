import os
import logging
import os
from dotenv import load_dotenv
load_dotenv()

import chainlit as cl
from chainlit.playground.providers import ChatOpenAI
from chainlit import run_sync
from time import sleep

import sys
import requests

sys.path.append("../code")

from env_vars import ROOT_PATH_INGESTION, INITIAL_INDEX, SEARCH_TOP_N, BUILD_ID

from utils.bcolors import bcolors as bc  


def log_message(message, level):
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

class APIClient:
    def __init__(self):
        self.base_url = os.getenv('API_BASE_URL')

    def get_models(self):
        endpoint = '/models'
        response = requests.get(self.base_url + endpoint)
        return response.json()

    def get_prompts(self):
        endpoint = '/prompts'
        response = requests.get(self.base_url + endpoint)
        return response.json()

    def get_prompt(self, p):
        endpoint = f'/prompts/{p}'
        response = requests.get(self.base_url + endpoint)
        return response.json()

    def ingest_docs(self, ingestion_params):
        endpoint = '/ingest'
        response = requests.post(self.base_url + endpoint, json=ingestion_params)
        return response.json()

    def get_file(self, asset):
        endpoint = '/file'
        payload = {'asset': asset}
        response = requests.get(self.base_url + endpoint, json=payload)
        return response.json()

    def search(self, query_params):
        response = requests.post(f"{self.base_url}/search", json=query_params)
        return response.json()
    
    def upload_files(self, index_name, files):
        response = requests.post(f"{self.base_url}/{index_name}/upload_files", files=files)
        return response.json()

api_client = APIClient()

### FIXING THE CURRENT WORKING DIRECTORY

log_message("ROOT_PATH_INGESTION:", ROOT_PATH_INGESTION)
log_message("Current working directory:", os.path.abspath(os.getcwd()))
log_message("Full path", os.path.abspath(ROOT_PATH_INGESTION))

try: 
    init_index_name = INITIAL_INDEX
except:
    init_index_name = 'rag-data'

cwd = os.path.join(ROOT_PATH_INGESTION, init_index_name)
log_message("Changing to NEW Current Directory", cwd)
os.makedirs(cwd, exist_ok=True)
os.chdir(cwd)

log_message("Current working directory:", os.path.abspath(os.getcwd()))



######################  TEST INSTALLATION  ######################
## pip install chainlit
## chainlit run chat.py -w --port 8050
######################  TEST INSTALLATION  ######################


#we will be using the index name to look for the path of folders in the container.
# init_index_name = 'openai_faq'
# init_ingestion_directory = init_ingestion_directory + '/'+ init_index_name
# init_ingestion_directory=ROOT_PATH_INGESTION



init_ingestion_directory = cwd

print ("*******init_ingestion_directory:", init_ingestion_directory)
# logging.basicConfig(level=logging.INFO)
log_message('*******init_ingestion_directory:'+ init_ingestion_directory, 'info')

def unify_path(path):
    return path.replace('\\', '/')

def change_to_container_path(path, root_path):
    # we remove reference to the relative path:
    return_path = unify_path(root_path + path.replace('..', '')) 

    #check if the folder exists
    if not os.path.exists(return_path):
        error_message = f"The path {return_path} does not exist."
        log_message(error_message, 'error')
        raise FileNotFoundError(error_message)
    else:
        log_message(f"The path {return_path} exists.", 'info')
    return return_path

# test: # change_to_container_path('/openai_faq', ROOT_PATH_INGESTION)

gpt4_models = api_client.get_models()
available_models = len([1 for x in gpt4_models if x['AZURE_OPENAI_RESOURCE'] is not None])
# logc("available_models", available_models) #FIXME

init_code_interpreter = "NoComputationTextOnly"
init_code_interpreter = "Taskweaver"
init_code_interpreter = "AssistantsAPI"

init_password = ''
init_approx_tag_limit = '15'
init_pdf_extraction_mode = 'hybrid'
init_docx_extraction_modes = 'document-intelligence'
init_number_of_threads = available_models
init_delete_existing_output_directory = False
init_top_n = SEARCH_TOP_N # FIXME
init_ingestion_directory = init_index_name


user_sessions = {}
# ingestion_directories = {}
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
    # task_ingestion_directory = cl.Task(title=f"Ingestion Directory: {ingestion_directory}", status=cl.TaskStatus.DONE)
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
    # await task_list.add_task(task_ingestion_directory)
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
    # ingestion_directories[cl.user_session.get("id")] = init_ingestion_directory
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

def ingest_docs_directory_using_processors(ingestion_params):
    try:
        api_client.ingest_docs(ingestion_params)
    except Exception as e:
        log_message(f"Error ingesting documents: {e}", 'error')
    
@cl.on_message
async def main(message: cl.Message):
    message_content = message.content.strip().lower()

    if conversations.get(cl.user_session.get("id")) is None:
        log_message("########################## INITIALIZING HISTORY")
        conversations[cl.user_session.get("id")] = []
    

    if message_content.startswith('cmd'):
        cmd = message_content[4:]
        
        if cmd == 'index':
            res = await cl.AskUserMessage(content="What is the index name?", timeout=1000).send()
            if res:
                index_name = res['output'].strip()
                index_names[cl.user_session.get("id")] = index_name
                await update_task_list()

        # elif cmd == 'ingestion_dir':
        #     res = await cl.AskUserMessage(content="What is the ingestion directory?", timeout=1000).send()
        #     if res:
        #         ingestion_directory = res['output'].strip()
        #         ingestion_directories[cl.user_session.get("id")] = ingestion_directory
        #         await update_task_list()

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
                files_upload = {}
                for file in files:
                    files_upload[file.name] = open(file.path, 'rb')
                api_client.upload_files(index_name, files_upload)
                
                filenames = [file.name for file in files]
                fns = ', '.join(filenames)
                await cl.Message(content=f"File(s) '{fns}' have been uploaded'.").send()


        elif cmd == "ingest":      
            index_name = index_names[cl.user_session.get("id")]
            
            await cl.Message(content=f"Starting ingestion into '{index_name}'.").send()

            log_message("\n\nIngestion Variables:")
            log_message("index_name:", index_names[cl.user_session.get("id")], type(index_names[cl.user_session.get("id")]))
            log_message("password:", passwords[cl.user_session.get("id")], type(passwords[cl.user_session.get("id")]))
            log_message("approx_tag_limit:", approx_tag_limits[cl.user_session.get("id")], type(approx_tag_limits[cl.user_session.get("id")]))
            log_message("pdf_extraction_mode:", pdf_extraction_modes[cl.user_session.get("id")], type(pdf_extraction_modes[cl.user_session.get("id")]))
            log_message("docx_extraction_mode:", docx_extraction_modes[cl.user_session.get("id")], type(docx_extraction_modes[cl.user_session.get("id")]))
            log_message("number_of_threads:", number_of_threads[cl.user_session.get("id")], type(number_of_threads[cl.user_session.get("id")]))
            log_message("delete_existing_output_directory:", delete_existing_output_directory[cl.user_session.get("id")], type(delete_existing_output_directory[cl.user_session.get("id")]))

            ingestion_params_dict = {
                "index_name" : index_name,
                'num_threads' : available_models,
                "password" : passwords[cl.user_session.get("id")],
                "delete_existing_output_dir" : delete_existing_output_directory[cl.user_session.get("id")],
                "processing_mode_pdf" : pdf_extraction_modes[cl.user_session.get("id")],
                "processing_mode_docx" : docx_extraction_modes[cl.user_session.get("id")],
                'models': gpt4_models, # FIXME
                'vision_models': gpt4_models, # FIXME
                'verbose': True
            }

            await cl.make_async(ingest_docs_directory_using_processors)(ingestion_params_dict)

            await cl.Message(content=f"Ingestion into '{index_name}' complete.").send()

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

def search(query, learnings = None, top=7, approx_tag_limit=15, conversation_history = [], user_id = None, computation_approach = "AssistantsAPI", computation_decision = "LLM", vision_support = False, include_master_py=True, vector_directory = None, vector_type = "AISearch", index_name = 'mm_doc_analysis', full_search_output = True, count=False, token_limit = 100000, temperature = 0.2, verbose = False):
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
    log_message("Conversation History", conversations[cl.user_session.get("id")])     

    final_answer, references, output_excel, search_results, files = await cl.make_async(search)(
        query, 
        top=top_ns[cl.user_session.get("id")], 
        approx_tag_limit = approx_tag_limits[cl.user_session.get("id")],
        conversation_history = conversations[cl.user_session.get("id")],
        user_id = cl.user_session.get("id"),
        computation_approach = code_interpreters[cl.user_session.get("id")], 
        computation_decision = "LLM", 
        vision_support = False, 
        include_master_py=True, 
        vector_directory = os.path.join(ROOT_PATH_INGESTION , index_names[cl.user_session.get("id")] ), 
        vector_type = "AISearch", 
        index_name = index_names[cl.user_session.get("id")], 
        count=False, 
        verbose = False)

    final_elements = []

    conversations[cl.user_session.get("id")].append({"role": "user", "content": query})
    conversations[cl.user_session.get("id")].append({"role": "assistant", "content": final_answer})
    log_message("Conversation History1", conversations[cl.user_session.get("id")])
    conversations[cl.user_session.get("id")] = conversations[cl.user_session.get("id")][-6:]
    log_message("Conversation History2", conversations[cl.user_session.get("id")])

    for f in files:
        if f['type'] == 'assistant_image':
            final_elements.append(cl.Image(name=os.path.basename(f['asset']), path=f['asset'], size='large', display="inline"))
        elif f['type'] == 'file':
            if f['asset'].endswith('.jpg') or f['asset'].endswith('.png'):
                final_elements.append(cl.Image(name=os.path.basename(f['asset']), path=f['asset'], size='large', display="inline"))
            elif f['asset'].endswith('.pdf'):
                final_elements.append(cl.Pdf(name="Results PDF", path=f['asset'], display="inline"))
            else:
                final_elements.append(cl.File(name="Results File", path=f['asset'], display="inline"))
        
    id_m = await cl.Message(content=final_answer, elements = final_elements).send()

    pdfs = [p['document_path'] for p in references]
    pdfs = list(set(pdfs))

    if (output_excel != "")  and (output_excel is not None):
        try:
            output_excel = change_to_container_path(output_excel, ROOT_PATH_INGESTION)
            async with cl.Step(name=f"Search Results",  elements = [cl.File(name="Results Excel", path=output_excel, display="inline")]) as step:
                step.output = f"Excel Document '{os.path.basename(output_excel)}'\nThe below has been taken from **{os.path.basename(output_excel)}**."
        except Exception as e:
            log_message("Error in output_excel message", output_excel, "\n", e)


    for index, r in enumerate(files + references):
        try:
            text = get_asset_file(r['asset'])
            if text == '':
                text = f"Current working directory {os.path.abspath(os.getcwd())}\nFile Abs Path: {os.path.abspath(r['asset'])}"

            if r['type'] == 'text':
                e = [cl.Text(name=f"Text below:", content=text, display="inline")]
            elif r['type'] == 'image':
                e = [cl.Image(name=os.path.basename(r['asset']), path=replace_extension(r['asset'], '.jpg'), size='large', display="inline"), # FIXME
                        cl.Text(name=f"Text below:", content=text, display="inline")]
            elif r['type'] == 'table':
                e = []
                if os.path.exists(replace_extension(r['asset'], '.png')): # FIXME
                    e.append(cl.Image(name=os.path.basename(r['asset']), path=replace_extension(r['asset'], '.png'), size='large', display="inline"),
                        cl.Text(name=f"Text below:", content=text, display="inline"))
                if os.path.exists(r['asset']):
                    e.append(cl.Text(name=f"Text below:", content=text, display="inline"))
            elif r['type'] == 'file':
                e = [cl.File(name="Results File", path=r['asset'], display="inline")]
            elif r['type'] == 'assistant_image':
                e = [cl.Image(name=os.path.basename(r['asset']), path=replace_extension(r['asset'], '.jpg'), size='large', display="inline")] # FIXME           

            async with cl.Step(name=f"Search References",  elements = e) as step:
                try:
                    step.output = f"### Search Result #{r['search_result_number']}\nThe below has been taken from **{r['original_document']}**.\n[Open Document]({r['sas_link']})"
                except:
                    step.output = f"File Generated by Code Interpreter."

        except Exception as e:
            log_message("Error in file message", index, "\n", r, "\n", e)


    for pdf in pdfs:
        if pdf.endswith('.pdf'):
            try:
                pdf=change_to_container_path(pdf, ROOT_PATH_INGESTION)
                log_message("Current Dir", os.getcwd())
                async with cl.Step(name=f"Search References",  elements = [cl.Pdf(name="PDF", path=pdf, display="inline")]) as step:
                    step.output = f"Document '{os.path.basename(pdf)}'\nThe below has been taken from **{os.path.basename(pdf)}**."
            except Exception as e:
                log_message("Error in pdf message", pdf, "\n", e)
