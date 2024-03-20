# Contents of ~/my_app/main_page.py
import streamlit as st

if "page_config" not in st.session_state:

    st.set_page_config(
        page_title="Multi RAG application",
        page_icon="🧊",
        layout="wide",
    )
    st.session_state.page_config = True

st.markdown("# Multi Modal advanced RAG application")

st.markdown("## Ingestion")

st.markdown("""#### This section of the application is the place to ingest your documents. You need to select the extraction modes and indexing options before uploading the files. In addition, you can choose to delete the ingestion folder and start the ingestion process. Moreover the most important part is the Index name that will be subsequently for the search and retrieval of the results and documents. 
            """)

st.markdown("## Prompt Management")
st.markdown("""#### This section of the application is the place to create and manage the prompts. You can create a new prompt, delete an existing prompt, and generate the content for the prompt.To test the prompts, please select the index name and the prompt category.""")

st.markdown("## Chat")
st.markdown(""" #### This section of the application is the place to interact with the chatbot. You can select the index name and the code execution type. In addition, you can set the top results and test the chatbot with the selected settings.""")
