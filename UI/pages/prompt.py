import streamlit as st

st.markdown("# Page Promt ❄️")
import os
import shutil

# Base directory for categories
base_dir = "../code/prompts"



# Ensure the base directory exists
if not os.path.exists(base_dir):
    os.makedirs(base_dir)

if 'show_cancel_warning' not in st.session_state:
    st.session_state.show_cancel_warning = False

def get_categories():
    """Return a list of category names found in the base directory."""
    if os.path.exists(base_dir):
        return [d for d in os.listdir(base_dir) if os.path.isdir(os.path.join(base_dir, d))]
    return []

def create_new_category(category_name):
    """Creates a new category directory and an initial empty text file."""
    new_path = os.path.join(base_dir, category_name)
    if not os.path.exists(new_path):
        os.makedirs(new_path)
        with open(os.path.join(new_path, "system_prompt_ver_1.txt"), 'w') as f:
            f.write("")  # Create an initial empty file
        st.sidebar.success(f"Category '{category_name}' created with initial version.")
    else:
        st.sidebar.error("Category already exists.")
# Function to delete a category
def delete_category(category_name):
    """Deletes the specified category and all its contents."""
    category_path = os.path.join(base_dir, category_name)
    if os.path.exists(category_path):
        shutil.rmtree(category_path)  # This removes the directory and all its contents
        st.success(f"Category '{category_name}' deleted.")
    else:
        st.error("Category does not exist.")

def get_latest_file_version(category_name):
    """Returns the path and version number of the latest version of the prompt file."""
    category_path = os.path.join(base_dir, category_name)
    files = [f for f in os.listdir(category_path) if os.path.isfile(os.path.join(category_path, f))]
    if files:
        latest_file = max(files, key=lambda x: int(x.replace("system_prompt_ver_", "").replace(".txt", "")))
        version_number = int(latest_file.split('_')[-1].split('.')[0])
        return os.path.join(category_path, latest_file), version_number
    return None, 0


def create_new_prompt_version(category_name, content):
    """Creates a new prompt version file in the selected category with the given content."""
    latest_file_path, version_number = get_latest_file_version(category_name)  # Unpack the tuple
    if latest_file_path:
        version_number += 1
    else:
        version_number = 1  # In case there are no files yet
    new_file_path = os.path.join(base_dir, category_name, f"system_prompt_ver_{version_number}.txt")
    with open(new_file_path, 'w') as f:
        f.write(content)
    st.success(f"New version saved: {os.path.basename(new_file_path)}")


# Sidebar UI for category selection
st.sidebar.title("Options")
categories = get_categories()
category_name = st.sidebar.selectbox("Select a category:", [""] + categories)

# Main UI
if category_name:
    latest_file_path, current_version = get_latest_file_version(category_name)
    if latest_file_path:
        with open(latest_file_path, 'r') as f:
            content = f.read()
        st.write(f"Current Version of the prompt: {current_version}")  # Display current version
    else:
        content = ""
        st.write("This category has no prompts yet.")
    
    # Dynamically adjust the height of the text area as before
    lines = content.count('\n') + 1
    min_height = 300
    dynamic_height = max(min_height, lines * 20)
    edited_content = st.text_area("Edit the prompt:", value=content, height=dynamic_height)
    
    if st.button("Save to a New Version"):
        create_new_prompt_version(category_name, edited_content)
    if st.button("Cancel"):
        st.session_state.show_cancel_warning = True  # Set the flag to show the warning
    
    if st.session_state.show_cancel_warning:
        # Display the warning and provide an option to confirm cancellation
        st.warning("Are you sure you want to cancel? Unsaved changes will be lost.", icon="🚨")
        if st.button("Yes, discard changes"):
            # Reload the latest version by rerunning the app to reset the text area
            st.session_state.show_cancel_warning = False  # Reset the warning flag
            st.experimental_rerun()


# Creating new category handled in the sidebar
new_category_name = st.sidebar.text_input("Create new category:")
if st.sidebar.button("Create"):
    create_new_category(new_category_name)


# UI for deleting a category
st.sidebar.title("Delete a Category")
delete_category_name = st.sidebar.selectbox("Select a category to delete:", [""] + categories)
if st.sidebar.button("Delete Category"):
    if delete_category_name:
        # Confirmation dialog to prevent accidental deletion
        if st.sidebar.checkbox("I understand this action cannot be undone and all data in the category will be lost."):
            delete_category(delete_category_name)
    else:
        st.sidebar.warning("Please select a category to delete.")
