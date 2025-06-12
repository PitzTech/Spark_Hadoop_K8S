from fastapi import FastAPI

app = FastAPI()

@app.get("/")
async def root():
    return {"message": "Hello World"}

@app.get("/micro_servico")
async def micro_servico():
    return {"message": "rodou o microserviço com sucesso!"}
