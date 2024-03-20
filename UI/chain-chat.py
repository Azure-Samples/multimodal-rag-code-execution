
import os
import logging
from typing import Optional
import os
from dotenv import load_dotenv
from pydantic import BaseModel
load_dotenv()

import chainlit as cl
from chainlit.playground.providers import ChatOpenAI
from chainlit import run_sync
from time import sleep

import sys
sys.path.append("../code")
sys.path.append("C:\\Users\\selhousseini\\Documents\\GitHub\\mm-doc-analysis-rag-ce\\code\\")

from env_vars import *
import doc_utils
from doc_utils import *
import utils.cosmos_helpers as cs


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


from chainlit.server import app
from fastapi import Query, Request
from chainlit.context import init_http_context
from fastapi.responses import (
    HTMLResponse,
)

# Define a Pydantic model for your request body
class Settings(BaseModel):
    index_name: str = None
    code_executor: str = None
    top_result: int = 5

@app.post("/settings/")
async def get_chat_settings(settings: Settings):
    for key in index_names.keys():
        index_names[key] = settings.index_name

    for key in code_interpreters.keys():
        code_interpreters[key] = settings.code_executor
    
    for key in top_results.keys():
        top_results[key] = settings.top_result
    
    return HTMLResponse("message Chat settings updated.")


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



init_code_interpreter = "AssistantsAPI"
init_index_name = "doc_ingestion_project_minions_v5"
index_names = {}
conversations = {}
code_interpreters = {}
top_results = {}


async def post_message(label, message):
    async with cl.Step(name=label) as step:
        step.output = message

def post_message_sync(label, message):
    run_sync(post_message(label, message))

doc_utils.log_ui_func_hook = post_message_sync


@cl.on_chat_start
async def start():
    code_interpreters[cl.user_session.get("id")] = init_code_interpreter
    index_names[cl.user_session.get("id")] = init_index_name
    top_results[cl.user_session.get("id")] = 5

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
    cosmos = cs.SCCosmosClient()
    prompts = cosmos.get_all_documents()
    prompt= next((item for item in prompts if item['Category'] == prompt_name), None)
    if (prompt is None):
        await cl.Message(content=f"Prompt {prompt_name} not found").send()
        return

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

        if cmd == 'gen':
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
            await cl.Message(content="Please choose a correct command").send()

    else:
        await app_search(message.content)

async def app_search(query: str):       
    final_answer, references, output_excel, search_results, files = await cl.make_async(search)(
        query, 
        top=top_results[cl.user_session.get("id")], 
        conversation_history = conversations[cl.user_session.get("id")],
        user_id = cl.user_session.get("id"),
        computation_approach = code_interpreters[cl.user_session.get("id")], 
        computation_decision = "LLM", 
        vision_support = False, 
        include_master_py=True, 
        index_name=index_names[cl.user_session.get("id")],
        vector_directory = os.path.join(ROOT_PATH_INGESTION , index_names[cl.user_session.get("id")] ), 
        vector_type = "AISearch", 
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
            



        