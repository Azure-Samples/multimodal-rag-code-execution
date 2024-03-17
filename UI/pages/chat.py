import streamlit as st

import streamlit.components.v1 as components
import os
from dotenv import load_dotenv
import requests
load_dotenv()

CHAINLIT_APP = os.getenv("CHAINLIT_APP")

components.iframe(CHAINLIT_APP, height=1000, width=1300, scrolling=False)

# Call the CHAINLIT_APP endpoint with chatsettings to set the index_name and code execution
index_name = st.sidebar.text_input("Index name:", st.session_state.get('index_name', 'Index undefined'), disabled=True)
code_execution = st.sidebar.selectbox("Code execution:", ["AssistantsAPI", "TaskWeaver"])
top_results = st.sidebar.slider("Top results:",1,10,1 )


payload = {
    "index_name": index_name,
    "code_executor": code_execution,
    "top_results": top_results
}

response = requests.post(f"{CHAINLIT_APP}/settings/", json=payload)
