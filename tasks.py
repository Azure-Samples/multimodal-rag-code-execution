from invoke import task, run

@task
def start_main(c):
    c.run("cd ui & python -m streamlit run main.py")

@task
def start_chat(c):
    c.run("cd ui & python -m chainlit run -w chat.py")

@task
def start_api(c, port=9000):
    c.run(f"cd code && python -m uvicorn api:app --host 0.0.0.0 --port {port}")