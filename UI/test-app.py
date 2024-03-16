
import os
import logging
from typing import Optional
import shutil
import csv 
import os
from dotenv import load_dotenv
load_dotenv()

import random
import json

import traceback
import uuid
import asyncio
import chainlit as cl
from chainlit.playground.providers import ChatOpenAI
from chainlit import run_sync
from time import sleep

import fitz  # PyMuPDF
import shutil
import sys
sys.path.append("../code")
sys.path.append("C:\\Users\\selhousseini\\Documents\\GitHub\\mm-doc-analysis-rag-ce\\code\\")

import doc_utils

from env_vars import *
import doc_utils
from doc_utils import *
from bcolors import bcolors as bc  

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



######################  TEST INSTALLATION  ######################
## pip install chainlit
## chainlit run test-app.py -w --port 8050
######################  TEST INSTALLATION  ######################


#we will be using the index name to look for the path of folders in the container.
# init_index_name = 'openai_faq'
# init_ingestion_directory = init_ingestion_directory + '/'+ init_index_name
# init_ingestion_directory=ROOT_PATH_INGESTION

init_ingestion_directory = 'doc_ingestion_project_minions_v5'
init_index_name = 'doc_ingestion_project_minions_v5'


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



init_code_interpreter = "NoComputationTextOnly"
init_code_interpreter = "Taskweaver"
init_code_interpreter = "AssistantsAPI"

init_password = ''
init_extract_text_mode = 'GPT'
init_extract_images_mode = 'PDF'
init_extract_text_from_images = True
init_number_of_threads = 4
init_delete_existing_output_directory = False


init_index_name = 'blackrock_index_v1'
init_ingestion_directory = init_index_name
init_extract_images_mode = 'GPT'



user_sessions = {}
# ingestion_directories = {}
index_names = {}
passwords = {}
extract_text_modes = {}
extract_images_modes = {}
extract_text_from_images = {}
number_of_threads = {}
delete_existing_output_directory = {}
code_interpreters = {}
conversations = {}




async def post_message(label, message):
    async with cl.Step(name=label) as step:
        step.output = message

def post_message_sync(label, message):
    run_sync(post_message(label, message))

doc_utils.log_ui_func_hook = post_message_sync



async def update_task_list():
    # ingestion_directory = ingestion_directories[cl.user_session.get("id")]
    index_name = index_names[cl.user_session.get("id")]
    password = passwords[cl.user_session.get("id")]
    extract_text_mode = extract_text_modes[cl.user_session.get("id")]
    extract_images_mode = extract_images_modes[cl.user_session.get("id")]
    extract_text_from_image = extract_text_from_images[cl.user_session.get("id")]
    number_of_thread = number_of_threads[cl.user_session.get("id")]
    delete_existing_output_directories = delete_existing_output_directory[cl.user_session.get("id")]
    code_interpreter = code_interpreters[cl.user_session.get("id")]

    # Create the TaskList
    task_list = cl.TaskList()
    task_list.status = "Test Configuration"

    # Add tasks to the task list
    # task_ingestion_directory = cl.Task(title=f"Ingestion Directory: {ingestion_directory}", status=cl.TaskStatus.DONE)
    task_index_name = cl.Task(title=f"Index Name: {index_name}", status=cl.TaskStatus.DONE)
    task_password = cl.Task(title=f"PDF Password: {password}", status=cl.TaskStatus.DONE)
    task_extract_text_mode = cl.Task(title=f"Extract Text Mode: {extract_text_mode}", status=cl.TaskStatus.DONE)
    task_extract_images_mode = cl.Task(title=f"Extract Images Mode: {extract_images_mode}", status=cl.TaskStatus.DONE)
    task_extract_text_from_image = cl.Task(title=f"Extract Text from Images: {extract_text_from_image}", status=cl.TaskStatus.DONE)
    task_number_of_thread = cl.Task(title=f"Number of Threads: {number_of_thread}", status=cl.TaskStatus.DONE)
    task_delete_existing_output_directories = cl.Task(title=f"Delete Existing Ingestion Directory: {delete_existing_output_directories}", status=cl.TaskStatus.DONE)
    task_code_interpreter = cl.Task(title=f"Code Interpreter: {code_interpreter}", status=cl.TaskStatus.DONE)

    # Add tasks to the task list
    # await task_list.add_task(task_ingestion_directory)
    await task_list.add_task(task_index_name)
    await task_list.add_task(task_password)
    await task_list.add_task(task_extract_text_mode)
    await task_list.add_task(task_extract_images_mode)
    await task_list.add_task(task_extract_text_from_image)
    await task_list.add_task(task_number_of_thread)
    await task_list.add_task(task_delete_existing_output_directories)
    await task_list.add_task(task_code_interpreter)

    # Update the task list in the interface
    await task_list.send()



@cl.on_chat_start
async def start():
    user_sessions[cl.user_session.get("id")] = {}
    # ingestion_directories[cl.user_session.get("id")] = init_ingestion_directory
    index_names[cl.user_session.get("id")] = init_index_name
    passwords[cl.user_session.get("id")] = init_password
    extract_text_modes[cl.user_session.get("id")] = init_extract_text_mode
    extract_images_modes[cl.user_session.get("id")] = init_extract_images_mode
    extract_text_from_images[cl.user_session.get("id")] = init_extract_text_from_images
    number_of_threads[cl.user_session.get("id")] = init_number_of_threads
    delete_existing_output_directory[cl.user_session.get("id")] = init_delete_existing_output_directory
    code_interpreters[cl.user_session.get("id")] = init_code_interpreter
    
    await update_task_list()



file_pattern = re.compile(r'system_prompt_ver_(\d+)\.txt')

def get_latest_file_version(directory, file_pattern):
    max_version = -1
    latest_file = None

    for filename in os.listdir(directory):
        match = file_pattern.match(filename)
        if match:
            version = int(match.group(1))
            if version > max_version:
                max_version = version
                latest_file = filename

    return os.path.join(directory, latest_file) if latest_file else None


async def generate_prompt(prompt_name):
    prompts_path = os.environ.get("PROMPTS_PATH")
    if not prompts_path:
        #if it is empty it means the user does not have the environment variable set, 
        #so we assume its a local developer and will not populate paths from file share
        prompts_path = "../code/prompts"

    prompt_dir = os.path.join(prompts_path, prompt_name)
    prompt_file = get_latest_file_version(prompt_dir, file_pattern)
    prompt = read_asset_file(prompt_file)[0]
    logc("Generating the contents for the prompt: {prompt}")
    await app_search(prompt)


@cl.action_callback('Business Overview')
async def on_action(action):
    await generate_prompt(action.value)

@cl.action_callback('Executive Summary')
async def on_executive_summary(action):
    await generate_prompt(action.value)

@cl.action_callback('Historical Financials')
async def on_historical_financials(action):
    await generate_prompt(action.value)

@cl.action_callback('Industry Overview')
async def on_industry_overview(action):
    await generate_prompt(action.value)

@cl.action_callback('Preliminary Return Analysis')
async def on_preliminary_return_analysis(action):
    await generate_prompt(action.value)

@cl.action_callback('Products Overview')
async def on_products_overview(action):
    await generate_prompt(action.value)

    
@cl.on_message
async def main(message: cl.Message):
    message_content = message.content.strip().lower()

    if conversations.get(cl.user_session.get("id")) is None:
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

        elif cmd == 'text_processing':
            res = await cl.AskUserMessage(content="What is the text post-processing mode?", timeout=1000).send()
            if res:
                extract_text_mode = res['output'].strip().upper()
                if extract_text_mode in ['GPT', 'PDF']:
                    extract_text_modes[cl.user_session.get("id")] = extract_text_mode
                    await update_task_list()
                else:
                    await cl.Message(content="Invalid text post-processing mode. Please choose from 'GPT' or 'PDF'.").send()


        elif cmd == 'image_detection':
            res = await cl.AskUserMessage(content="What is the images detection and extraction mode?", timeout=1000).send()
            if res:
                extract_images_mode = res['output'].strip().upper()
                if extract_images_mode in ['GPT', 'PDF']:
                    extract_images_modes[cl.user_session.get("id")] = extract_images_mode
                    await update_task_list()
                else:
                    await cl.Message(content="Invalid images detection and extraction mode. Please choose from 'GPT' or 'PDF'.").send()

        elif cmd == 'OCR':
            res = await cl.AskUserMessage(content="Extract text from images?", timeout=1000).send()
            if res:
                extract_text_from_image = res['output'].strip().lower()
                if extract_text_from_image in ['yes', 'true']: 
                    extract_text_from_image = True
                else: 
                    extract_text_from_image = False
                extract_text_from_images[cl.user_session.get("id")] = extract_text_from_image
                await update_task_list()
        
        elif cmd == 'threads':
            res = await cl.AskUserMessage(content="Number of threads?", timeout=1000).send()
            if res:
                print(res)
                number_of_thread = res['output'].strip()
                try:
                    number_of_thread = int(number_of_thread)
                    if number_of_thread < 1: number_of_thread = 1
                    number_of_threads[cl.user_session.get("id")] = number_of_thread
                    await update_task_list()
                except:
                    pass

        elif cmd == 'code_interpreter':
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
                                            accept=["application/pdf"], 
                                            max_size_mb = 100,
                                            max_files = 100,
                                            timeout=1000).send()
            if files:
                filenames = [file.name for file in files]
                for file in files:
                    print(file)
                    index_name = index_names[cl.user_session.get("id")]            
                    ingestion_directory = os.path.join(ROOT_PATH_INGESTION , index_name) 
                    # ingestion_directory = os.path.join(ROOT_PATH_INGESTION, ingestion_directories[cl.user_session.get("id")])
                    os.makedirs(ingestion_directory, exist_ok=True)
                    download_directory = os.path.join(ingestion_directory, 'downloads')
                    os.makedirs(download_directory, exist_ok=True)
                    shutil.copy(file.path, os.path.join(download_directory, file.name))
                
                fns = ', '.join(filenames)
                await cl.Message(content=f"File(s) '{fns}' have been uploaded to '{download_directory}'.").send()


        elif cmd == "ingest":
            # ingestion_directory = os.path.join(ROOT_PATH_INGESTION, ingestion_directories[cl.user_session.get("id")])        
            index_name = index_names[cl.user_session.get("id")]            
            ingestion_directory = os.path.join(ROOT_PATH_INGESTION , index_name)     
            download_directory = os.path.join(ingestion_directory, 'downloads')
            
            await cl.Message(content=f"Starting ingestion of '{ingestion_directory}' into '{index_name}'.").send()

            print("\n\nIngestion Variables:")
            print("ROOT_PATH_INGESTION:", ROOT_PATH_INGESTION)
            print("ingestion_directory:", ingestion_directory, type(ingestion_directory))
            print("download_directory:", download_directory, type(download_directory))
            print("index_name:", index_names[cl.user_session.get("id")], type(index_names[cl.user_session.get("id")]))
            print("password:", passwords[cl.user_session.get("id")], type(passwords[cl.user_session.get("id")]))
            print("extract_text_mode:", extract_text_modes[cl.user_session.get("id")], type(extract_text_modes[cl.user_session.get("id")]))
            print("extract_images_mode:", extract_images_modes[cl.user_session.get("id")], type(extract_images_modes[cl.user_session.get("id")]))
            print("extract_text_from_image:", extract_text_from_images[cl.user_session.get("id")], type(extract_text_from_images[cl.user_session.get("id")]))
            print("number_of_threads:", number_of_threads[cl.user_session.get("id")], type(number_of_threads[cl.user_session.get("id")]))
            print("delete_existing_output_directory:", delete_existing_output_directory[cl.user_session.get("id")], type(delete_existing_output_directory[cl.user_session.get("id")]))

            await cl.make_async(ingest_docs_directory)(
                directory=download_directory, 
                ingestion_directory=ingestion_directory, 
                index_name=index_names[cl.user_session.get("id")], 
                password=passwords[cl.user_session.get("id")], 
                extract_text_mode=extract_text_modes[cl.user_session.get("id")], 
                extract_images_mode=extract_images_modes[cl.user_session.get("id")], 
                extract_text_from_images=extract_text_from_images[cl.user_session.get("id")], 
                num_threads=number_of_threads[cl.user_session.get("id")], 
                delete_existing_output_dir=delete_existing_output_directory[cl.user_session.get("id")], 
                processing_stages=None, 
                verbose=False
            )

            await cl.Message(content=f"Ingestion of '{ingestion_directory}' into '{index_name}' complete.").send()


        elif cmd == "gen":

            dirs = ['business_overview', 'executive_summary', 'historical_financials', 'Industry_overview', 'preliminary_return_analysis', 'Products_overview']
            descs = [
                'Description of the business and its operations',
                'Summary of key points and highlights',
                'Financial information from previous years',
                'Overview of the industry and market',
                'Analysis of potential returns on investment',
                'Overview of the company\'s products'
            ]

            button_names = ['Business Overview', 'Executive Summary', 'Historical Financials', 'Industry Overview', 'Preliminary Return Analysis', 'Products Overview']

            actions = [
                cl.Action(name=button_names[index], value=d, description=descs[index]) for index, d in enumerate(dirs)
            ]

            await cl.Message(content="Please choose which prompt to generate:", actions=actions).send()

    else:
        await app_search(message.content)











async def app_search(query: str):        
    final_answer, references, output_excel, search_results, files = await cl.make_async(search)(
        query, 
        top=5, 
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

    pdfs = [p['pdf_path'] for p in references]
    pdfs = list(set(pdfs))

    if (output_excel != "")  and (output_excel is not None):
        try:
            output_excel = change_to_container_path(output_excel, ROOT_PATH_INGESTION)
            async with cl.Step(name=f"Search Results",  elements = [cl.File(name="Results Excel", path=output_excel, display="inline")]) as step:
                step.output = f"Excel Document '{os.path.basename(output_excel)}'\nThe below has been taken from **{os.path.basename(output_excel)}**."
        except Exception as e:
            print("Error in output_excel message", output_excel, "\n", e)


    for index, r in enumerate(files + references):
        try:
            if r['type'] == 'text':
                e = [cl.Text(name=f"Text below:", content=read_asset_file(r['asset'])[0], display="inline")]
            elif r['type'] == 'image':
                e = [cl.Image(name=os.path.basename(r['asset']), path=replace_extension(r['asset'], '.jpg'), size='large', display="inline"),
                        cl.Text(name=f"Text below:", content=read_asset_file(r['asset'])[0], display="inline")]
            elif r['type'] == 'table':
                e = [cl.Image(name=os.path.basename(r['asset']), path=replace_extension(r['asset'], '.png'), size='large', display="inline"),
                        cl.Text(name=f"Text below:", content=read_asset_file(r['asset'])[0], display="inline")]
            elif r['type'] == 'file':
                e = [cl.File(name="Results File", path=r['asset'], display="inline")]
            elif r['type'] == 'assistant_image':
                e = [cl.Image(name=os.path.basename(r['asset']), path=replace_extension(r['asset'], '.jpg'), size='large', display="inline")]                

            async with cl.Step(name=f"Search References",  elements = e) as step:
                try:
                    step.output = f"Reference {index + 1}\nThe below has been taken from **{r['pdf_document']}** page **{r['page']}**."
                except:
                    step.output = f"File Generated by Code Interpreter."

        except Exception as e:
            print("Error in file message", index, "\n", r, "\n", e)


    for pdf in pdfs:
        try:
            pdf=change_to_container_path(pdf, ROOT_PATH_INGESTION)
            print("Current Dir", os.getcwd())
            async with cl.Step(name=f"Search PDF References",  elements = [cl.Pdf(name="PDF", path=pdf, display="inline")]) as step:
                step.output = f"PDF Document '{os.path.basename(pdf)}'\nThe below has been taken from **{os.path.basename(pdf)}**."
        except Exception as e:
            print("Error in pdf message", pdf, "\n", e)
            



        