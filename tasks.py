from invoke import task, run

@task
def start_main(c):
    c.run("cd UI")
    c.run("python -m streamlit run main.py")

@task
def start_chat(c):
    c.run("cd UI")
    c.run("python -m chainlit run chat.py")

@task
def start_api(c, port=9000):
    c.run("cd code")
    c.run(f"python -m uvicorn api:app --host 0.0.0.0 --port {port}")