import streamlit as st
import sys
sys.path.append("../code")
from doc_utils import *
from utils.cogsearch_rest import CogSearchHttpRequest

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
    body = {
        "id": category_name,
        "Category": category_name,
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
   return content + "\n\n" + "\n\n".join(sections)

def generate_content(content):
    final_answer, references, output_excel, search_results, files  = search(content, index_name=st.session_state.prompt_index)
    return final_answer



# Sidebar UI for category selection
st.sidebar.title("Options")
categories = get_prompts_category()
category_name = st.sidebar.selectbox("Select a category:", [""] + categories)

mainCol, secondCol = st.columns([1, 1])
# Main UI
if category_name:   
    max_text_area_height_lines = 15 # Placeholder for the maximum height of the text area
    prompt = get_prompt(category_name)
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
    if 'Sections' in prompt:
        for section in prompt['Sections']:
           edited_sections.append(sections_container.text_area(section['Title'], value=section['Content'], height=dynamic_height, key="extraSections"+section['Title']))
    else:
        prompt['Sections'] = []
    
    new_section = mainCol.text_input("New section title:", key="newSectionTitle")
    if mainCol.button("Generate new section"):
        st.session_state.processing = True  # Flag to indicate processing
        new_prompt = generate_new_section(new_section)
        edited_new_prompt = sections_container.text_area(new_section, value=new_prompt, height=dynamic_height, key="newSectionContent")
        prompt['Sections'].append({"Title": new_section, "Content": edited_new_prompt}) 
        st.session_state.processing = False  # Reset processing flag

   

    if mainCol.button("Save changes"):
        index = 0
        for section in prompt['Sections']:
            section['Content'] = edited_sections[index]
            index += 1

        st.session_state.processing = True  # Flag to indicate processing
        save(category_name, {"Content": edited_content, "Sections": prompt['Sections']})
        st.session_state.processing = False  # Reset processing flag

    consolidated_content = generate_consolidated_content(edited_content, edited_sections)
    consolidated_prompt = secondCol.text_area("Consolidated prompt:", value=consolidated_content, height=1200, key="consolidatedContentText", disabled=True)
    test_prompt = secondCol.button("Test prompt")

    if test_prompt:
        if (st.session_state.prompt_index == ""):
            st.warning("Please select an index to test the prompt.")
        else:
            st.title("prompt result...")
            answer = generate_content(consolidated_content)
            st.write(answer)
else:
    st.markdown("## Please select a category to view or edit the prompt.")  

# Creating new category handled in the sidebar
new_category_name = st.sidebar.text_input("Create new category:")
if st.sidebar.button("Create"):
    create_new_prompt(new_category_name)


# UI for deleting a category
st.sidebar.title("Delete a Category")
delete_category_name = st.sidebar.selectbox("Select a category to delete:", [""] + categories)
if st.sidebar.button("Delete Category"):
    if delete_category_name:
        # Confirmation dialog to prevent accidental deletion
        if st.sidebar.checkbox("I understand this action cannot be undone and all data in the category will be lost."):
            delete_prompt(delete_category_name)
    else:
        st.sidebar.warning("Please select a category to delete.")


st.sidebar.markdown("""---""")
select_index = st.sidebar.selectbox("Select an index:", [""] + st.session_state.Indexes)
if select_index:
    st.session_state.prompt_index = select_index
    