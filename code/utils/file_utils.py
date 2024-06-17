import requests
import urllib
import os
import pickle

from utils.logc import logc
from utils.bcolors import bcolors as bc
from azure.storage.fileshare import ShareFileClient, generate_file_sas, FileSasPermissions
from datetime import datetime, timedelta

from env_vars import ROOT_PATH_INGESTION, AZURE_FILE_SHARE_ACCOUNT, AZURE_FILE_SHARE_KEY, AZURE_FILE_SHARE_NAME

def download_file(url, folder_path):
    # Extract the filename from the URL
    filename = url.split('/')[-1]

    # Create the full save path
    save_path = os.path.join(folder_path, filename)

    # Send a GET request to the URL
    response = requests.get(url)

    # Check if the request was successful
    if response.status_code == 200:
        # Make sure the directory exists
        os.makedirs(folder_path, exist_ok=True)

        # Write the content to a file
        with open(save_path, 'wb') as f:
            f.write(response.content)
        print(f"File saved to {save_path}")
        return save_path
    else:
        print(f"Failed to retrieve the File from the url: {url}")
        return None

def is_file_or_url(s):
    # Check if the string is a URL
    parsed = urllib.parse.urlparse(s)
    is_url = bool(parsed.scheme and parsed.netloc)

    # Check if the string is a local file path
    is_file = os.path.isfile(s)

    return 'url' if is_url else 'file' if is_file else 'unknown'


def save_to_pickle(a, filename):
    with open(filename, 'wb') as handle:
        pickle.dump(a, handle, protocol=pickle.HIGHEST_PROTOCOL)


def load_from_pickle(filename):
    with open(filename, 'rb') as handle:
        b = pickle.load(handle)
    return b

def check_replace_extension(asset_file, new_extension):
    if os.path.exists(replace_extension(asset_file, new_extension)):
        new_file = replace_extension(asset_file, new_extension)
        return new_file
    return ""

def replace_extension(asset_path, new_extension):
    base_name = os.path.splitext(asset_path)[0].strip()
    extension = os.path.splitext(asset_path)[1].strip()

    return f"{base_name}{new_extension}"

### IMPORTANT FOR WINDOWS USERS TO SUPPORT LONG FILENAME PATHS 
### IN CASE YOU"RE USING LONG FILENAMES, AND THIS IS CAUSING AN EXCEPTION, FOLLOW THESE 2 STEPS:
# 1. change a registry setting to allow long path names on this particular Windows system (use regedit.exe): under HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem, set LongPathsEnabled to DWORD value 1
# 2. Check if the group policy setting is configured to enable long path names. Open the Group Policy Editor (gpedit.msc) and navigate to Local Computer Policy > Computer Configuration > Administrative Templates > System > Filesystem. Look for the "Enable Win32 long paths" policy and make sure it is set to "Enabled".
def write_to_file(text, text_filename, mode = 'a'):
    try:
        text_filename = text_filename.replace("\\", "/")
        with open(text_filename, mode, encoding='utf-8') as file:
            file.write(text)

        print(f"Writing file to full path: {os.path.abspath(text_filename)}")
    except Exception as e:
        logc(f"SERIOUS ERROR: {bc.RED}Error writing text to file: {e}{bc.ENDC}")

def read_asset_file(text_filename):
    try:
        text_filename = text_filename.replace("\\", "/")
        with open(text_filename, 'r', encoding='utf-8') as file:
            text = file.read()
        status = True
    except Exception as e:
        text = ""
        print(f"WARNING ONLY - reading text file: {e}")
        status = False

    return text, status

def find_certain_files(directory, extension = '.xlsx'):
    xlsx_files = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".xlsx"):
                xlsx_files.append(os.path.join(root, file))
    return xlsx_files

def generate_file_sas_full_link(p):
    try:
        p = os.path.normpath(os.path.join(ROOT_PATH_INGESTION, p)).replace("\\", "/")
        logc(f"Generate SAS Token for {p}")
        if p.startswith('/'): p = p[1:]
        service = ShareFileClient(account_url=f"https://{AZURE_FILE_SHARE_ACCOUNT}.file.core.windows.net", credential=AZURE_FILE_SHARE_KEY, share_name=AZURE_FILE_SHARE_NAME, file_path=p)

        token = generate_file_sas(AZURE_FILE_SHARE_ACCOUNT, AZURE_FILE_SHARE_NAME, p.split('/'), AZURE_FILE_SHARE_KEY, expiry=datetime.utcnow() + timedelta(hours=20*365*24), permission=FileSasPermissions(read=True))
        full_path = service.url + '?' + token
        return full_path
    except:
        return ""
