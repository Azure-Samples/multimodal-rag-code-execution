# Contents of ~/my_app/main_page.py
import streamlit as st
import os

print("Current working directory:", os.path.abspath(os.getcwd()))

if "page_config" not in st.session_state:

    st.set_page_config(
        page_title="Research CoPilot",
        page_icon="🧊",
        layout="wide",
    )
    st.session_state.page_config = True

build_id = os.getenv('BUILD_ID')
st.markdown(f"# Research CoPilot")
st.markdown(f"""#### Version: {build_id}""")
st.markdown("## Prompt Management")
st.markdown("""#### This section of the application is the place to create and manage the prompts. You can create a new prompt, delete an existing prompt, and generate the content for the prompt.To test the prompts, please select the index name and the prompt category.""")

st.markdown("## Ingestion")

st.markdown("""#### This section of the application is the place to ingest your documents. You need to select the extraction modes and indexing options before uploading the files. In addition, you can choose to delete the ingestion folder and start the ingestion process. Moreover the most important part is the Index name that will be subsequently for the search and retrieval of the results and documents. 
            """)


