import os
import uuid
import time

from env_vars import ROOT_PATH_INGESTION, AZURE_OPENAI_MODEL
from utils.logc import logc
from utils.code_exec_utils import prepare_prompt_for_code_interpreter
from utils.openai_utils import oai_client

threads = {}

def process_assistants_api_response(messages, client=oai_client):
    files = []
    full_path = ""

    download_dir = os.path.join(ROOT_PATH_INGESTION, "downloads")
    os.makedirs(download_dir, exist_ok=True)

    md = messages.model_dump()["data"]
    for j in range(len(md[0]["content"])):
        if md[0]["content"][j]['type'] == 'text':
            response = md[0]["content"][j]["text"]["value"]
            break
    
    for i in range(len(md)):
        msg_id = md[i]["id"]
        for j in range(len(md[i]["content"])):
            if md[i]["content"][j]["type"] == 'text':
                if md[i]["content"][j]["text"].get("annotations", None) is not None:
                        for annotation in md[i]["content"][j]["text"]["annotations"]:
                            if annotation.get("type", None) is not None:
                                if annotation["type"] == "file_path":
                                    file_data = client.files.content(annotation["file_path"]["file_id"])
                                    data_bytes = file_data.read()
                                    full_path = os.path.join(download_dir, os.path.basename(annotation["text"]))
                                    with open(full_path, "wb") as file:
                                        file.write(data_bytes)
                                    response = response.replace(annotation["text"], full_path)
                                    files.append({'type':'file', 'asset':full_path})
            elif md[i]["content"][j]["type"] == 'image_file':
                file_data = client.files.content(md[i]["content"][j]["image_file"]["file_id"])
                data_bytes = file_data.read()
                full_path = os.path.join(download_dir, os.path.basename(f'{md[i]["content"][j]["image_file"]["file_id"]}.jpg'))
                with open(full_path, "wb") as file:
                    file.write(data_bytes)
                files.append({'type':'assistant_image', 'asset':full_path})

    return response, files

def create_assistant(user_id, client=oai_client, model = AZURE_OPENAI_MODEL, name="Math Assistant", instructions="You are an AI assistant that can write code to help answer math questions."):
    # Create an assistant
    assistant = client.beta.assistants.create(
        name=name,
        instructions=instructions,
        tools=[{"type": "code_interpreter"}],
        model=model
    )

    try:
        if user_id is None: user_id = str(uuid.uuid4())[:8]
        if threads.get(user_id, None) is None:
            thread = client.beta.threads.create()
            threads[user_id] = thread
        else:
            thread = threads[user_id]
    except:
        thread = client.beta.threads.create()

    return assistant, thread

def retrieve_assistant(assistant_id, client=oai_client):
    assistant = client.beta.assistants.retrieve(assistant_id)
    return assistant

def retrieve_thread(thread_id, client=oai_client):
    thread = client.beta.threads.retrieve(thread_id)
    return thread

def query_assistant(query, assistant, thread, client=oai_client):
    # Add a user question to the thread
    message = client.beta.threads.messages.create(
        thread_id=thread.id,
        role="user",
        content = query
    )

    run = client.beta.threads.runs.create(thread_id=thread.id, assistant_id=assistant.id)
    run = client.beta.threads.runs.retrieve(thread_id=thread.id, run_id=run.id)
    status = run.status

    while status not in ["completed", "cancelled", "expired", "failed"]:
        time.sleep(5)
        run = client.beta.threads.runs.retrieve(thread_id=thread.id,run_id=run.id)
        status = run.status

    messages = client.beta.threads.messages.list(thread_id=thread.id)
    return messages

def try_code_interpreter_for_tables_using_assistants_api(assets, query, user_id = None, include_master_py=True,  model = AZURE_OPENAI_MODEL, client=oai_client, verbose = False):

    assistant, thread = create_assistant(user_id, client)    
    user_query_prompt = prepare_prompt_for_code_interpreter(assets, query, include_master_py=include_master_py, limit=True, verbose=verbose)
    messages = query_assistant(user_query_prompt, assistant, thread, client)
    response, files = process_assistants_api_response(messages, client)

    logc("Response from Assistants API", response)
    logc("Files from Assistants API", files)

    return response, files
