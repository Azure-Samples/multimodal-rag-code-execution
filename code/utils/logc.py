import logging
import contextvars
from utils.bcolors import bcolors as bc
from datetime import datetime

# Define a context variable for the log hook
# This is required to specialize the logc function for the API to stream logs to the UI
# and must be differently for each request
log_hook_var = contextvars.ContextVar('log_hook', default=None)

def get_current_time():
    return datetime.now().strftime("%d.%m.%Y_%H.%M.%S")

def logc(label, text = None, newline=False, timestamp=False, verbose=True):
    if newline: nls = "\n" 
    else: nls = " "

    out_s = ""
    out_n = ""

    if timestamp:
        if text is not None:
            out_s = f"\n{get_current_time()} :: {bc.OKGREEN}{label}:{nls}{bc.OKBLUE}{text}{bc.ENDC}"
            out_n = f"\n{get_current_time()} :: {label}:{nls}{text}"
            if verbose: logging.info(out_s)
        else:
            out_s = f"\n{get_current_time()} :: {bc.OKGREEN}{label}{nls}{bc.ENDC}"
            out_n = f"\n{get_current_time()} :: {label}{nls}"
            if verbose: logging.info(out_s)
    else:
        if text is not None:
            out_s = f"\n{bc.OKGREEN}{label}:{nls}{bc.OKBLUE}{text}{bc.ENDC}"
            out_n = f"\n{label}:{nls}{text}"
            if verbose: logging.info(out_s)
        else:
            out_s = f"\n{bc.OKGREEN}{label}{nls}{bc.ENDC}"
            out_n = f"\n{label}{nls}"
            if verbose: logging.info(out_s)

    log_ui_func_hook = log_hook_var.get()
    if log_ui_func_hook is not None:
        try:
            log_ui_func_hook(label, text)
        except Exception as e:
            logging.error(f"Error in log_ui_func_hook")
    else:
        logging.warning(f"Log hook not set. No logs will be streamed to the UI or stored on filesystem.")
