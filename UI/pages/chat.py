import streamlit as st

import streamlit.components.v1 as components
import os
from dotenv import load_dotenv
import requests
import sys
sys.path.append("../code")
from utils.cogsearch_rest import CogSearchHttpRequest

load_dotenv()

if "page_config" not in st.session_state:

    st.set_page_config(
        page_title="Multi RAG application",
        page_icon="🧊",
        layout="wide",
    )
    st.session_state.page_config = True

CHAINLIT_APP = os.getenv("CHAINLIT_APP")

def get_indexes():
    cogrequest = CogSearchHttpRequest()
    indexes = cogrequest.get_indexes()
    return [index["name"] for index in indexes["value"]] 
   

if "Indexes" not in st.session_state:
    st.session_state.Indexes = get_indexes()

components.iframe(CHAINLIT_APP, height=1000, width=1300, scrolling=False)

# Call the CHAINLIT_APP endpoint with chatsettings to set the index_name and code execution


index_name = st.sidebar.selectbox("Index name:",[""] + st.session_state.Indexes)
code_execution = st.sidebar.selectbox("Code execution:", ["AssistantsAPI", "TaskWeaver"])
top_results = st.sidebar.slider("Top results:",1,10,1 )

value = ""
if index_name:
    value = index_name

payload = {
    "index_name":  value,
    "code_executor": code_execution,
    "top_results": top_results
}

response = requests.post(f"{CHAINLIT_APP}/settings/", json=payload)
