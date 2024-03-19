import streamlit as st
import os
import shutil
import sys
sys.path.append("../code")
from doc_utils import generate_section
import utils.cosmos_helpers as cs

# Base directory for categories

cosmos = cs.SCCosmosClient()

if "Prompts" not in st.session_state:
    st.session_state.Prompts = cosmos.get_all_documents()


if 'show_cancel_warning' not in st.session_state:
    st.session_state.show_cancel_warning = False

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
   

# Sidebar UI for category selection
st.sidebar.title("Options")
categories = get_prompts_category()
category_name = st.sidebar.selectbox("Select a category:", [""] + categories)

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
   
    edited_content = st.text_area("Main prompt:", value=content, height=dynamic_height, key="mainContentText")   

    sections_container = st.container()
    edited_sections = []
    if 'Sections' in prompt:
        for section in prompt['Sections']:
           edited_sections.append(sections_container.text_area(section['Title'], value=section['Content'], height=dynamic_height, key="extraSections"+section['Title']))
    else:
        prompt['Sections'] = []
    
    new_section = st.text_input("New section title:", key="newSectionTitle")
    if st.button("Generate new section"):
        st.session_state.processing = True  # Flag to indicate processing
        new_prompt = generate_new_section(new_section)
        edited_new_prompt = sections_container.text_area(new_section, value=new_prompt, height=dynamic_height, key="newSectionContent")
        prompt['Sections'].append({"Title": new_section, "Content": edited_new_prompt}) 
        st.session_state.processing = False  # Reset processing flag

    # Include buttons for saving new version and handling cancellation
    if st.button("Save changes"):
        index = 0
        for section in prompt['Sections']:
            section['Content'] = edited_sections[index]
            index += 1

        st.session_state.processing = True  # Flag to indicate processing
        save(category_name, {"Content": edited_content, "Sections": prompt['Sections']})
        st.session_state.processing = False  # Reset processing flag

    # if st.button("Cancel"):
    #     # Set the flag to show the cancellation warning
    #     st.session_state.show_cancel_warning = True
    
    # if st.session_state.show_cancel_warning:
    #     # Display the warning and provide an option to confirm cancellation
    #     st.warning("Are you sure you want to cancel? Unsaved changes will be lost.", icon="🚨")
    #     if st.button("Yes, discard changes"):
    #         # Reload the latest version by rerunning the app to reset the text area
    #         st.session_state.show_cancel_warning = False  # Reset the warning flag
    #         st.experimental_rerun()

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