import streamlit as st
import sys
sys.path.append("../code")
from doc_utils import *
from utils.cogsearch_rest import CogSearchHttpRequest
import pyperclip as pc
import utils.cosmos_helpers as cs

# Base directory for categories

cosmos = cs.SCCosmosClient()

if "Prompts" not in st.session_state:
    st.session_state.Prompts = cosmos.get_all_documents()

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

def get_indexes():
    cogrequest = CogSearchHttpRequest()
    indexes = cogrequest.get_indexes()
    return [index["name"] for index in indexes["value"]] 
        

if "Indexes" not in st.session_state:
    st.session_state.Indexes = get_indexes()

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
        cosmos.upsert_document(prompt)
        st.sidebar.success(f"Category '{category_name}' updated.")
    else:
        # Create a new category
        cosmos.create_document(body)
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
  

# Function to delete a category
def delete_prompt(category_name):
    prompt = get_prompt(category_name)
    cosmos.delete_document(doc_id=prompt['id'])


def generate_new_section(section):
    section_prompt = generate_section(section)
    return section_prompt


def generate_consolidated_content(content, sections):
    section_contents = [c for c in sections if isinstance(c, str)]
    return content + "\n\n" + "\n\n".join(section_contents)

def generate_content(content):
    final_answer, references, output_excel, search_results, files  = search(content, index_name=st.session_state.prompt_index, computation_approach= "AssistantsAPI", computation_decision="LLM")
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
    st.session_state.Prompts = cosmos.get_all_documents()
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
    consolidated_prompt = secondCol.text_area("Consolidated prompt:", value=consolidated_content, height=1200, key="consolidatedContentText", disabled=True)

    copy_col, test_prompt_col  = secondCol.columns([1, 1])

    test_prompt = test_prompt_col.button("Test prompt")
    copy_prompt = copy_col.button("Copy Prompt")
 
    answer = ''

    if test_prompt:
        if (st.session_state.prompt_index == ""):
            outputCol.warning("Please select an Index to test the prompt.")
        else:
            # outputCol.title("prompt result...")
            with st.spinner('Generating results...'):
                answer = generate_content(consolidated_content)
            
    if copy_prompt:
        pc.copy(consolidated_content)
        st.success("Prompt copied to clipboard.")

    
    test_output = outputCol.text_area("Test Output:", value=answer, height=1200, key="promptTestOutput", disabled=True)

    outputCol.button("Copy Output", key="copy_consolidated_prompt", on_click=pc.copy, args=[st.session_state.promptTestOutput])


        
    
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
            delete_prompt(delete_category_name)
    else:
        st.sidebar.warning("Please select a prompt to delete.")



    