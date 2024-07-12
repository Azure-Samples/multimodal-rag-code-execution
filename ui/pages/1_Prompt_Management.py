import streamlit as st
import os
import uuid
import requests
import pyperclip as pc
from dotenv import load_dotenv

load_dotenv()


# Set up logging format
import logging
from colorlog import ColoredFormatter
import requests
from requests.exceptions import HTTPError
formatter = ColoredFormatter(
    "%(log_color)s%(levelname)s%(reset)s:\t%(message)s",
    log_colors={
        'DEBUG': 'blue',
        'INFO': 'green',
        'WARNING': 'yellow',
        'ERROR': 'red',
        'CRITICAL': 'red,bg_white',
    }
)

# Create a logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Create a console handler and set the formatter
console_handler = logging.StreamHandler()
console_handler.setFormatter(formatter)

# Add the console handler to the logger
logger.addHandler(console_handler)

class APIClient:
    def __init__(self):
        self.base_url = os.getenv("API_BASE_URL").strip("/")

    def get_prompts(self):
        try:
            logging.info("Getting prompts from API")
            response = requests.get(f"{self.base_url}/prompt")
            response.raise_for_status()
            return response.json()
        except HTTPError as e:
            logging.error(f"Failed to get prompts: {e}")
            raise

    def get_indexes(self):
        try:
            logging.info("Getting indexes from API")
            response = requests.get(f"{self.base_url}/index")
            response.raise_for_status()
            return response.json()
        except HTTPError as e:
            logging.error(f"Failed to get indexes: {e}")
            raise

    def update_prompt(self, prompt):
        try:
            logging.info(f"Updating prompt with ID: {prompt['id']}")
            response = requests.patch(f"{self.base_url}/prompt", json=prompt)
            response.raise_for_status()
        except HTTPError as e:
            logging.error(f"Failed to update prompt: {e}")
            raise

    def create_prompt(self, prompt):
        try:
            logging.info(f"Creating new prompt with ID: {prompt['id']}")
            response = requests.post(f"{self.base_url}/prompt", json=prompt)
            response.raise_for_status()
        except HTTPError as e:
            logging.error(f"Failed to create prompt: {e}")
            raise

    def delete_prompt(self, category_name):
        prompt = self.get_prompt_by_category(category_name)
        if prompt:
            try:
                logging.info(f"Deleting prompt with ID: {prompt['id']}")
                response = requests.delete(f"{self.base_url}/prompt/{prompt['id']}")
                response.raise_for_status()
            except HTTPError as e:
                logging.error(f"Failed to delete prompt: {e}")
                raise
        else:
            logging.warning(f"Prompt with category name '{category_name}' not found.")

    def generate_new_section(self, section):
        try:
            logging.info("Generating new section")
            response = requests.post(f"{self.base_url}/generate_section", json=section)
            response.raise_for_status()
            return response.json()
        except HTTPError as e:
            logging.error(f"Failed to generate new section: {e}")
            raise

    def generate_content(self, content, index_name, learnings = None, top=5, approx_tag_limit=5, conversation_history = [], user_id = "null", computation_approach = "AssistantsAPI", computation_decision = "LLM", vision_support = False, include_master_py=True, vector_directory = None, vector_type = "AISearch", full_search_output = True, count=False, token_limit = 100000, temperature = 0.2, verbose = False):
        try:
            logging.info("Generating content")
            response = requests.post(f"{self.base_url}/search", 
                                     json={
                                        "query": content,
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
            
            print(response)
            response.raise_for_status()
            return response.json()
        except HTTPError as e:
            logging.error(f"Failed to generate content: {e}")
            raise

    def get_prompt_by_category(self, category_name):
        prompts = self.get_prompts()
        return next((item for item in prompts if item['Category'] == category_name), None)

api_client = APIClient()

if "Prompts" not in st.session_state:
    st.session_state.Prompts = api_client.get_prompts()

if "prompt_index" not in st.session_state:
    st.session_state.prompt_index = ""

if 'show_cancel_warning' not in st.session_state:
    st.session_state.show_cancel_warning = False

if "page_config" not in st.session_state:

    st.set_page_config(
        page_title="Multi RAG application",
        page_icon="🧊",
        layout="wide",
    )
    st.session_state.page_config = True

if 'processing' not in st.session_state:
    st.session_state.processing = False

if "Indexes" not in st.session_state:
    indexes = api_client.get_indexes()
    st.session_state.Indexes = [index["name"] for index in indexes["value"]]

def get_prompts_category():
    return [item['Category'] for item in st.session_state.Prompts]

def get_prompt(category_name):
    return next((item for item in st.session_state.Prompts if item['Category'] == category_name), None)

def save(category_name, body):
    """Saves the new prompt to the Cosmos DB."""
    # Check if the category already exists
    prompt = get_prompt(category_name)
    if prompt:
        # Update the existing category
        prompt['Content'] = body['Content']
        api_client.update_prompt(prompt)
        st.sidebar.success(f"Category '{category_name}' updated.")
    else:
        # Create a new category
        api_client.create_prompt(body)
        st.sidebar.success(f"Category '{category_name}' created with initial version.")

def create_new_prompt(category_name):
    """Creates a new category directory and an initial empty text file."""
    #create new category in Cosmod DB
    if (not category_name) or (category_name == ''):
        st.sidebar.warning("Please enter a category name.")
        return

    body = {
        "id": category_name,
        "Category": category_name,
        "categoryId": "main_prompts",
        "Content": ""
    }
    save(category_name, body)

def generate_new_section(section):
    section_prompt = api_client.generate_new_section(section)
    return section_prompt

def generate_consolidated_content(content, sections):
    section_contents = [c for c in sections if isinstance(c, str)]
    return content + "\n\n" + "\n\n".join(section_contents)

def generate_content(content):
    final_answer, references, output_excel, search_results, files, steps  = api_client.generate_content(content, st.session_state.prompt_index)
    return final_answer

def save_prompt(prompt, edited_sections, edited_content):
    index = 0
    for section in prompt['Sections']:
        section['Content'] = edited_sections[index]
        index += 1

    save(category_name, {"Content": edited_content, "Sections": prompt['Sections']})

def delete_section(prompt, edited_sections, text_area):
    prompt['Sections'].remove(section)
    edited_sections.remove(text_area)

def clear_inputs():
    st.session_state.newSectionTitle = ""
    st.session_state.newSectionPrompt = ""

# st.text_input("Type something", key="user_input")
# st.text_area("Please provide a description of a new sub-section:", height=150, key="newSectionPrompt2222")
# st.button("Clear", on_click=on_click)


# Sidebar UI for category selection
st.sidebar.title("Indexes")
select_index = st.sidebar.selectbox("Select an Index:", st.session_state.Indexes)
if select_index:
    st.session_state.prompt_index = select_index

st.sidebar.markdown("""---""")

st.sidebar.title("Available Prompts")
categories = get_prompts_category()
st.session_state['categories'] = categories
category_name = st.sidebar.selectbox("Select a prompt:", st.session_state['categories'])


refresh_col, save_col  = st.sidebar.columns([1, 1])

refresh = refresh_col.button("Reload Prompts")
if refresh:
    st.session_state.Prompts = api_client.get_prompts()
    st.session_state['categories'] = get_prompts_category()

save_action = save_col.button("Save Prompt")
prompt = get_prompt(category_name)

def text_area_edited(section, new_key):
    section['Content'] = st.session_state[new_key]
    


mainCol, secondCol, outputCol = st.columns([1, 1, 1])


# Main UI
if category_name:   
    max_text_area_height_lines = 15 # Placeholder for the maximum height of the text area
    
    if prompt:
        content = prompt['Content']
    else:
        content = ""
    
    # Dynamically adjust the height of the text area based on content
    lines = content.count('\n') + 1
    min_height = 300
    dynamic_height = max(min_height, lines * max_text_area_height_lines)  # Example dynamic height calculation
    edited_content = mainCol.text_area("Main prompt:", value=content, height=dynamic_height, key="mainContentText")   


    sections_container = mainCol.container()
    edited_sections = []


    ## Rendering existing sub-sections from Cosmos in UI
    if 'Sections' in prompt:
        for section in prompt['Sections']:
            new_key = "extraSections_"+section['Title']+f"_{str(uuid.uuid4())[:16]}"
            text_area = sections_container.text_area(
                    section['Title'], 
                    value=section['Content'], 
                    height=dynamic_height, 
                    key=new_key,
                    on_change = text_area_edited,
                    args = [section, new_key]
                )

            edited_sections.append(text_area)
            sections_container.button('Delete Sub-Section', on_click=delete_section, key = f"delete_{str(uuid.uuid4())[:16]}", args = [prompt, edited_sections, text_area])
    
    else:
        prompt['Sections'] = []
    

    if save_action:
        st.session_state.processing = True
        save_prompt(prompt, edited_sections, edited_content)
        st.session_state.processing = False

    ## Adding a new Section
    new_title = mainCol.text_input("Please provide a title for a new sub-section:", key="newSectionTitle")
    new_section = mainCol.text_area("Please provide a description of a new sub-section:", height=150, key="newSectionPrompt")

    if mainCol.button("Generate new sub-section", disabled=st.session_state.processing):
        st.session_state.processing = True  # Flag to indicate processing

        with st.spinner("Generating new sub-section..."):
            new_prompt = generate_new_section(new_section + f"\n\nPlease use {new_title} as the title for this section")
            edited_new_prompt = sections_container.text_area(new_title, value=new_prompt, height=dynamic_height, key="newSectionContent")
            new_prompt_section = {"Title": new_title, "Content": edited_new_prompt}
            prompt['Sections'].append(new_prompt_section) 
            edited_sections.append(edited_new_prompt)
            sections_container.button('Delete Sub-Section', on_click=delete_section, key = f"delete_{str(uuid.uuid4())[:16]}", args = [prompt, edited_sections, edited_new_prompt])

        st.session_state.processing = False  # Reset processing flag
   

    if mainCol.button("Save", disabled=st.session_state.processing):
        st.session_state.processing = True
        save_prompt(prompt, edited_sections, edited_content)
        st.session_state.processing = False

    consolidated_content = generate_consolidated_content(edited_content, edited_sections)
    consolidated_prompt = secondCol.text_area("Consolidated prompt:", value=consolidated_content, height=1200, key="consolidatedContentText", disabled=False)

    # copy_col, test_prompt_col  = secondCol.columns([1, 1])

    test_prompt = secondCol.button("Test prompt")
    # copy_prompt = copy_col.button("Copy Prompt")
 
    answer = ''

    if test_prompt:
        if (st.session_state.prompt_index == ""):
            outputCol.warning("Please select an Index to test the prompt.")
        else:
            # outputCol.title("prompt result...")
            with st.spinner('Generating results...'):
                answer = generate_content(consolidated_content)
            
    # if copy_prompt:
    #     pc.copy(consolidated_content)
    #     st.success("Prompt copied to clipboard.")

    
    test_output = outputCol.text_area("Test Output:", value=answer, height=1200, key="promptTestOutput", disabled=False)

    # outputCol.button("Copy Output", key="copy_consolidated_prompt", on_click=pc.copy, args=[st.session_state.promptTestOutput])
else:
    st.markdown("## Please select a section to view or edit the prompt.")  

# Creating new category handled in the sidebar
st.sidebar.title("New Prompts")
new_category_name = st.sidebar.text_input("Create new prompt:")
if st.sidebar.button("Create"):
    create_new_prompt(new_category_name)
    categories = get_prompts_category()
    st.session_state['categories'] = categories
    # category_name = st.sidebar.selectbox("Select a section:", [""] + categories)

# UI for deleting a category
st.sidebar.title("Delete Prompt")
delete_category_name = st.sidebar.selectbox("Select a prompt to delete:", [""] + categories)
if st.sidebar.button("Delete Prompt"):
    if delete_category_name:
        # Confirmation dialog to prevent accidental deletion
        if st.sidebar.checkbox("I understand this action cannot be undone and all data in the category will be lost."):
            logging.info(f"Deleting prompt with category name '{delete_category_name}'")
            api_client.delete_prompt(delete_category_name)
    else:
        st.sidebar.warning("Please select a prompt to delete.")
