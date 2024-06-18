import fitz  # PyMuPDF
import os
from env_vars import ROOT_PATH_INGESTION

def read_pdf(pdf_doc):
    doc = fitz.open(pdf_doc)
    print(f"PDF File {os.path.basename(pdf_doc)} has {len(doc)} chunks.")
    return doc


def extract_chunks_as_png_files(doc, work_dir = os.path.join(ROOT_PATH_INGESTION, 'downloads')):
    os.makedirs(work_dir, exist_ok=True)
    png_files = []

    for chunk in doc:
        chunk_num = chunk.number
        img_path = f"{work_dir}/chunk_{chunk_num}.png"
        chunk_pix = chunk.get_pixmap(dpi=300)
        chunk_pix.save(img_path)
        print(f"Chunk {chunk_num} saved as {img_path}")
        png_files.append(img_path)
    
    return png_files