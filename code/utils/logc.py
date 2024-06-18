import logging
from utils.bcolors import bcolors as bc
from datetime import datetime

log_ui_func_hook = None

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

    if log_ui_func_hook is not None:
        try:
            log_ui_func_hook(label, text)
        except Exception as e:
            logging.error(f"Error in log_ui_func_hook")
    else:
        pass
        # print("log_ui_func_hook is None")