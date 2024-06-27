import os
import sys
import logging

from inspect import getsourcefile

from utils.logc import logc
from utils.file_utils import read_asset_file, replace_extension
from utils.text_utils import get_token_count, recover_json, extract_code, extract_chunk_number
from utils.openai_utils import get_chat_completion

exec_path = os.path.dirname(getsourcefile(lambda:0))
exec_path = ''
test_project_path = os.path.join(exec_path, "../test_project/")
default_vector_directory = os.path.join(exec_path, "../doc_ingestion_cases/")

if os.path.exists("../prompts"):
    prompt_dir = "../prompts"
elif os.path.exists("./prompts"):
    prompt_dir = "./prompts"
else:
    prompt_dir = "../code/prompts"

user_query = read_asset_file(f'{prompt_dir}/user_query.txt')[0]
user_query = read_asset_file(f'{prompt_dir}/user_query.txt')[0]
direct_user_query = read_asset_file(f'{prompt_dir}/direct_user_query.txt')[0]
table_info = read_asset_file(f'{prompt_dir}/table_info.txt')[0]


# print("Code file: ", os.path.relpath(getsourcefile(lambda:0)))
# print("\n\nPython Version: ", sys.version)
# print("Current Path: ", os.getcwd())
# print("Execution Path: ", exec_path)
# print("Test Project Path: ", exec_path)
# print("Default Vector Directory: ", default_vector_directory)
# print("Taskweaver Path: ", taskweaver_path, '\n\n')
taskweaver_path = os.path.join(exec_path, "../TaskWeaver/")
sys.path.append(taskweaver_path)
sys.path.append("../TaskWeaver/") 

taskweaver_logger = logging.getLogger('taskweaver.logging')
taskweaver_logger.setLevel(logging.ERROR)

try:
    from taskweaver.app.app import TaskWeaverApp
except:
    pass

max_python_exec_retries = 7

class TWHandler():

    role: str = "Planner"
    buffer: str = ""

    def __init__(self, verbose = False):
        self.verbose = verbose

    def process_buffer(self, event):
        if (self.buffer == '') and (event.msg == ''): return   

        if hasattr(event, "extra"):
            if event.extra is not None: 
                is_end = event.extra.get("is_end", True)
            else:
                is_end = True

        else: 
            is_end = True

        if not is_end:
            if isinstance(event.msg, list):
                self.buffer = "\n".join(event.msg)
            else:
                self.buffer += event.msg
        else:
            if isinstance(event.msg, list):
                self.buffer = "\n".join(event.msg)
            else:
                self.buffer += event.msg

            if self.buffer not in ["NONE", "No code verification is performed.", "verifying code", "composing prompt", 
                                   "calling LLM endpoint", "receiving LLM response", "Post created"]:
                if self.verbose: logc("Taskweaver", f">>> Agent: {self.role}\n>>> Message:\n{self.buffer}")
            self.buffer = ""

    def handle(self, event):
        if event.extra is not None: 
            if event.extra.get('role', None) is not None:
                self.role = event.extra['role']
        
        self.process_buffer(event)

        return event

py_files_import = """ 
Do **NOT** forget to import the below py modules in every new code block you generate:
# Import the list of Python files specified by the user
List of Python Files:
## START OF LIST OF PYTHON FILES TO IMPORT
{run_py_files}
## END OF LIST OF PYTHON FILES TO IMPORT
"""

def prepare_prompt_for_code_interpreter(assets, query, include_master_py=True, limit=False, chars_limit = 32768, verbose = True):
    global user_query, table_info
    codeblocks = []
    added = []
    # py_code = [os.path.abspath(asset) for asset in assets['python_code']]
    py_code = []

    if include_master_py:
        master_files = []
        for document_path in assets['document_paths']: 
            master_py = os.path.abspath(replace_extension(document_path, ".py")).replace(' ', '_')
            if os.path.exists(master_py):
                master_files.append(master_py)
        master_files = list(set(master_files))
        py_code.extend(master_files)

    if verbose: logc("Taskweaver", py_code)
    run_py_files = ""

    for p in py_code:
        run_py_files += f"%run {p}\n"

    if verbose: logc("assets", assets)
    if verbose: logc("run_py_files", run_py_files)
    if verbose: logc("py_code", py_code)
    if verbose: logc("codeblocks", codeblocks)

    infoblocks_num = 0
    for index, asset in enumerate(assets['python_block']):
        if asset not in added:
            filename = replace_extension(asset, ".py")
            filename_field = f"Py Filename: {filename}" if os.path.exists(filename) else ""
            proc_filename = assets['filenames'][index]
            chunk_number = extract_chunk_number(assets['asset_filenames'][index])
            codeblock = read_asset_file(asset)[0]
            codeblock = f"Here's information in Python format:\n{codeblock}" if codeblock != "" else ""
            text = read_asset_file(asset)[0]
            text = f"Here's information in text format:\n{text}" if text != "" else ""
            markdown = read_asset_file(replace_extension(asset, ".md"))[0]  
            markdown = f"Here's information in Markdown format:\n{markdown}" if markdown != "" else ""
            mermaid = read_asset_file(replace_extension(asset, ".mermaid"))[0]
            mermaid = f"Here's information in Mermaid format:\n{mermaid}" if mermaid != "" else ""
            added.append(asset)

            if limit and (len('\n'.join(codeblocks)) > (chars_limit - 3000 - len(user_query) - len(run_py_files) - len("\n".join(py_code)))):                          
                print(f"Limit Reached: {len(codeblocks)} > {chars_limit - len(user_query) - len(run_py_files) - len(py_code) - 3000} | breakdown: {chars_limit} - 3000 - {len(user_query)} - {len(run_py_files)} - {len(py_code)}")
                break

            codeblocks.append(table_info.format(
                number = infoblocks_num,
                filename=filename_field, 
                proc_filename=proc_filename, 
                chunk_number=chunk_number, 
                codeblock=codeblock, 
                text = text,
                markdown=markdown, 
                mermaid=mermaid
                )
            )    

            infoblocks_num += 1  
            if index > limit: break  

    if verbose: logc("Taskweaver", f"Added Codeblocks\n{added}")

    py_code = "\n".join(py_code)
    py_files_field = f"Refer to the following files. Make sure to import the below modules in every code block you generate:\n{py_code}" if len(py_code) > 0 else ""

    py_files_import_prompt = py_files_import.format(run_py_files=run_py_files) if len(py_code) > 0 else ""

    user_query_prompt = user_query.format(query=query, run_py_files=py_files_import_prompt, py_files = py_files_field, py_code = "\n\n".join(codeblocks))

    if verbose: logc("User Query Token Count", get_token_count(user_query_prompt))    
    if verbose: logc("User Query: ", user_query_prompt)

    return user_query_prompt

def try_code_interpreter_for_tables_using_taskweaver(assets, query, include_master_py=True, verbose = False):
    
    app = TaskWeaverApp(app_dir=test_project_path)
    session = app.get_session()
    taskweaver_logger = logging.getLogger('taskweaver.logging')
    taskweaver_logger.setLevel(logging.ERROR)

    if verbose: logc("Taskweaver", f"Taskweaver Processing Started ...")

    if len(assets['python_code']) == 0: return "No computation results."
    
    user_query_prompt = prepare_prompt_for_code_interpreter(assets, query, include_master_py=include_master_py, verbose=verbose)
    response_round = session.send_message(user_query_prompt, event_handler=TWHandler(verbose=verbose)) 
    if verbose: logc("Taskweaver", f"Taskweaver Processing Completed ...")

    return response_round.to_dict()['post_list'][-1]['message'], []

def try_code_interpreter_for_tables_using_python_exec(assets, query, include_master_py=True, verbose = False):
    global direct_user_query, table_info

    if len(assets['python_code'])  == 0: return "No computation results."

    output = ""
    exception = ""
    previous_code = ""
    previous_error = ""

    retries = 0
    result = False

    while (not result):
        text_codeblocks = [table_info.format(filename = os.path.abspath(replace_extension(asset, ".py")), proc_filename=assets['filenames'][index], chunk_number = extract_chunk_number(assets['asset_filenames'][index]), codeblock=read_asset_file(asset)[0], markdown = read_asset_file(replace_extension(asset, ".txt"))[0]) for index, asset in enumerate(assets['python_block'])]
        
        py_code = [os.path.abspath(asset) for asset in assets['python_code']]

        if include_master_py:
            master_files = []
            for document_path in assets['document_paths']: 
                master_py = os.path.abspath(replace_extension(document_path, ".py"))
                if os.path.exists(master_py):
                    master_files.append(master_py)
            master_files = list(set(master_files))
            py_code.extend(master_files)

        user_query = direct_user_query.format(query=query, py_files = "\n".join(py_code), py_code = "\n\n".join(text_codeblocks), previous_code = previous_code, previous_error = previous_error)
        print("User Query: ", user_query)

        system_prompt = "You are a helpful assistant that helps the user by generating high quality code to answer the user's questions."
        messages = []
        messages.append({"role": "system", "content": system_prompt})     
        messages.append({"role": "user", "content": user_query})     

        result = get_chat_completion(messages)
        answer_codeblock = extract_code(recover_json(result.choices[0].message.content))
        print("Answer Codeblock: ", answer_codeblock)

        codeblocks = '\n\n'.join([read_asset_file(asset)[0] for asset in assets['python_code']])
        result, exception, output = execute_python_code_block(codeblocks, answer_codeblock + "\n" + "final_answer = foo()")
        previous_code = answer_codeblock
        previous_error = exception
        retries += 1

        if retries >= max_python_exec_retries:
            break

    if result:
        return output, []
    else:
        return exception, []
def execute_python_code_block_old(file_path):
    exception = ""

    try:
        with open(file_path, 'r') as file:
            code_block = file.read()
        output = exec(code_block)
        result = True
    except Exception as e:
        exception = e
        result = False

    return result, exception, output

def execute_python_code_block(file_path, additional_code = ""):
    exception = ""
    output = ""
    ret_dict = {}    
    result = False

    try:
        with open(file_path, 'r') as file:
            code_block = file.read()

        code = code_block + "\n" + additional_code
        exec(code, globals(), ret_dict)
        result = True
    
        print("Final Answer:", ret_dict.get('final_answer', ""))
        output = ret_dict.get('final_answer', "")
    except Exception as e:
        exception = e
        

    return result, exception, output
