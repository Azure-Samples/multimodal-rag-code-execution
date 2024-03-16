import streamlit as st

import streamlit.components.v1 as components
import os
from dotenv import load_dotenv
load_dotenv()

CHAINLIT_APP = os.getenv("CHAINLIT_APP")
components.iframe(CHAINLIT_APP, height=1000, width=1300, scrolling=False)