import os
import sys
import logging
import openai
from openai import AzureOpenAI, OpenAI
import base64
import requests
import json
from typing import List
from PIL import Image

from tenacity import (
    retry,
    stop_after_attempt,
    wait_random_exponential,
    stop_after_delay,
    after_log
)

from utils.logc import logc
from utils.bcolors import bcolors as bc
from env_vars import TENACITY_STOP_AFTER_DELAY, TENACITY_TIMEOUT, AZURE_OPENAI_VISION_API_VERSION, AZURE_VISION_ENDPOINT, AZURE_VISION_KEY
from utils.text_utils import recover_json

# https://techcommunity.microsoft.com/t5/ai-azure-ai-services-blog/gpt-4-turbo-with-vision-is-now-available-on-azure-openai-service/ba-p/4008456#:~:text=GPT%2D4%20Turbo%20with%20Vision%20can%20be%20accessed%20in%20the,Switzerland%20North%2C%20and%20West%20US.
# 
#  GPT-4 Turbo with Vision can be accessed in the following Azure regions: Australia East, Sweden Central, Switzerland North, and West US.

AZURE_OPENAI_KEY = os.environ.get('AZURE_OPENAI_KEY')
AZURE_OPENAI_API_VERSION = os.environ.get('AZURE_OPENAI_API_VERSION')
AZURE_OPENAI_MODEL_VISION = os.environ.get('AZURE_OPENAI_MODEL_VISION')
OPENAI_API_BASE = f"https://{os.getenv('AZURE_OPENAI_RESOURCE')}.openai.azure.com/"
AZURE_OPENAI_MODEL = os.environ.get('AZURE_OPENAI_MODEL')

AZURE_OPENAI_EMBEDDING_MODEL= os.environ.get('AZURE_OPENAI_EMBEDDING_MODEL')
AZURE_OPENAI_EMBEDDING_API_BASE = f"https://{os.getenv('AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE')}.openai.azure.com"
AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE_KEY = os.environ.get('AZURE_OPENAI_EMBEDDING_MODEL_RESOURCE_KEY')
AZURE_OPENAI_EMBEDDING_MODEL_API_VERSION = os.environ.get('AZURE_OPENAI_EMBEDDING_MODEL_API_VERSION')

openai.log = "error"
logging.basicConfig(stream=sys.stderr, level=logging.ERROR)
logger = logging.getLogger(__name__)

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

gpt4_models_init = [
    {
        'AZURE_OPENAI_RESOURCE': os.environ.get('AZURE_OPENAI_RESOURCE'),
        'AZURE_OPENAI_KEY': os.environ.get('AZURE_OPENAI_KEY'),
        'AZURE_OPENAI_MODEL_VISION': os.environ.get('AZURE_OPENAI_MODEL_VISION'),
        'AZURE_OPENAI_MODEL': os.environ.get('AZURE_OPENAI_MODEL'),
    }
]
    
addtnl_gpt4_models = [
    {
        'AZURE_OPENAI_RESOURCE': os.environ.get(f'AZURE_OPENAI_RESOURCE_{x}'),
        'AZURE_OPENAI_KEY': os.environ.get(f'AZURE_OPENAI_KEY_{x}'),
        'AZURE_OPENAI_MODEL_VISION': os.environ.get('AZURE_OPENAI_MODEL_VISION'),
        'AZURE_OPENAI_MODEL': os.environ.get('AZURE_OPENAI_MODEL'),
    } 
    for x in range(1, 20)
]

gpt4_models = gpt4_models_init + addtnl_gpt4_models

gpt4_models = [m for m in gpt4_models if (m['AZURE_OPENAI_RESOURCE'] is not None) and (m['AZURE_OPENAI_RESOURCE'] != '')]


@retry(wait=wait_random_exponential(min=1, max=30), stop=stop_after_delay(TENACITY_STOP_AFTER_DELAY), after=after_log(logger, logging.ERROR))             
def get_chat_completion(messages: List[dict], model = AZURE_OPENAI_MODEL, client = oai_client, temperature = 0.2):
    print(f"\nCalling OpenAI APIs with {len(messages)} messages - Model: {model} - Endpoint: {oai_client._base_url}\n")
    return client.chat.completions.create(model = model, temperature = temperature, messages = messages, timeout=TENACITY_TIMEOUT)

@retry(wait=wait_random_exponential(min=1, max=30), stop=stop_after_attempt(5), retry_error_callback=lambda e: isinstance(e, requests.exceptions.HTTPError) and e.response.status_code == 429, after=after_log(logger, logging.ERROR))
def get_chat_completion_with_json(messages: List[dict], model=AZURE_OPENAI_MODEL, client=oai_client, temperature=0.2):
    try:
        print(f"\nCalling OpenAI APIs with {len(messages)} messages - Model: {model} - Endpoint: {oai_client._base_url}\n{bc.ENDC}")
        print(f"Messages: {messages}")
        return client.chat.completions.create(model=model, temperature=temperature, messages=messages, response_format={"type": "json_object"}, timeout=TENACITY_TIMEOUT)
    except Exception as e:
        print(f"Error in get_chat_completion_with_json: {e}")
        raise e

@retry(wait=wait_random_exponential(min=1, max=30), stop=stop_after_delay(TENACITY_STOP_AFTER_DELAY), after=after_log(logger, logging.ERROR))     
def get_embeddings(text, embedding_model = AZURE_OPENAI_EMBEDDING_MODEL, client = oai_emb_client):
    return client.embeddings.create(input=[text], model=embedding_model,timeout=TENACITY_TIMEOUT).data[0].embedding

def ask_LLM(prompt, temperature = 0.2, model_info = None):

    if model_info is not None:
        client = AzureOpenAI(
                azure_endpoint =  f"https://{model_info['AZURE_OPENAI_RESOURCE']}.openai.azure.com" , 
                api_key= model_info['AZURE_OPENAI_KEY'],  
                api_version= AZURE_OPENAI_API_VERSION,
            )
    else:
        client = oai_client

    messages = []
    messages.append({"role": "system", "content": "You are a helpful assistant, who helps the user with their query."})     
    messages.append({"role": "user", "content": prompt})     

    result = get_chat_completion(messages, temperature = temperature, client=client)

    return result.choices[0].message.content

def ask_LLM_with_JSON(prompt, temperature = 0.2, model_info = None):

    if model_info is not None:
        client = AzureOpenAI(
                azure_endpoint =  f"https://{model_info['AZURE_OPENAI_RESOURCE']}.openai.azure.com" , 
                api_key= model_info['AZURE_OPENAI_KEY'],  
                api_version= AZURE_OPENAI_API_VERSION,
            )
    else:
        client = oai_client

    messages = []
    messages.append({"role": "system", "content": "You are a helpful assistant, who helps the user with their query. You are designed to output JSON."})     
    messages.append({"role": "user", "content": prompt})     

    result = get_chat_completion_with_json(messages, temperature = temperature, client=client)

    return result.choices[0].message.content

# Function to encode an image file in base64
def get_image_base64(image_path):
    with open(image_path, "rb") as image_file: 
        # Read the file and encode it in base64
        encoded_string = base64.b64encode(image_file.read())
        # Decode the base64 bytes into a string
        return encoded_string.decode('ascii')
    
def convert_png_to_jpg(image_path):
    if os.path.splitext(image_path)[1].lower() == '.png':
        # Open the image file
        with Image.open(image_path) as img:
            # Convert the image to RGB mode if it is in RGBA mode (transparency)
            if img.mode == 'RGBA':
                img = img.convert('RGB')
            # Define the new filename with .jpg extension
            new_image_path = os.path.splitext(image_path)[0] + '.jpg'
            # Save the image with the new filename and format
            img.save(new_image_path, 'JPEG')
            return new_image_path
    else:
        return None


@retry(wait=wait_random_exponential(min=1, max=30), stop=stop_after_attempt(10), after=after_log(logger, logging.DEBUG))
def call_gpt4v(imgs, gpt4v_prompt = "describe the attached image", prompt_extension = "", temperature = 0.2, model_info=None, enable_ai_enhancements=False):

    if model_info is None:
        api_base = OPENAI_API_BASE
        deployment_name = AZURE_OPENAI_MODEL_VISION
        api_key = AZURE_OPENAI_KEY
    else:
        api_base = f"https://{model_info['AZURE_OPENAI_RESOURCE']}.openai.azure.com/" 
        deployment_name = model_info['AZURE_OPENAI_MODEL_VISION']
        api_key = model_info['AZURE_OPENAI_KEY']

    base_url = f"{api_base}openai/deployments/{deployment_name}" 
    headers = {   
        "Content-Type": "application/json",   
        "api-key": api_key 
    } 

    img_arr = []
    img_msgs = []

    if isinstance(imgs, str): 
        img_arr = [imgs]
        image_path_or_url = imgs
    else: 
        img_arr = imgs
        image_path_or_url = imgs[0]

    logc(f"Start of GPT4V Call to process file(s) {img_arr} with model: {api_base}")        

    for image_path_or_url in img_arr:
        image_path_or_url = os.path.abspath(image_path_or_url)
        try:
            if os.path.splitext(image_path_or_url)[1] == ".png":
                image_path_or_url = convert_png_to_jpg(image_path_or_url)

            image = f"data:image/jpeg;base64,{get_image_base64(image_path_or_url)}"
        except:
            image = image_path_or_url

        img_msgs.append({ 
            "type": "image_url",
            "image_url": {
                "url": image
            }
        })

    if prompt_extension != "":
        final_prompt = gpt4v_prompt +'\n' + prompt_extension +'\n'
    else:
        final_prompt = gpt4v_prompt

    content = [
        { 
            "type": "text", 
            "text": final_prompt
        }
    ]

    content = content + img_msgs
    

    
    data = { 
        "temperature": temperature,
        "messages": [ 
            { "role": "system", "content": vision_system_prompt}, 
            { "role": "user",   "content": content } 
        ], 
        "max_tokens": 4095 
    }   

    if enable_ai_enhancements:
        endpoint = f"{base_url}/extensions/chat/completions?api-version={AZURE_OPENAI_VISION_API_VERSION}" 

        data['dataSources'] = [
            {
                "type": "AzureComputerVision",
                "parameters": {
                    "endpoint": AZURE_VISION_ENDPOINT,
                    "key": AZURE_VISION_KEY
                }
            }]
        
        data['enhancements'] = {
            "ocr": {
                "enabled": True
            },
            "grounding": {
                "enabled": True
            }
        }
    else:
        endpoint = f"{base_url}/chat/completions?api-version={AZURE_OPENAI_VISION_API_VERSION}" 
    
    print("endpoint", endpoint)
    # print("Data", data)
   
    response = requests.post(endpoint, headers=headers, data=json.dumps(data), timeout=300)   
    # print(json.dumps(recover_json(response.text), indent=4))
    result = recover_json(response.text)['choices'][0]['message']['content']
    description = f"Image was successfully explained, with Status Code: {response.status_code}"
    logc(f"End of GPT4V Call to process file(s) {img_arr} with model: {api_base}")   

    return result, description


vision_system_prompt = """You are a helpful assistant that uses its vision capabilities to process images, and answer questions around them. 
"""
