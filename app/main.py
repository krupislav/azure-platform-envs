# Platform test app: the smallest thing that proves the platform works end to end.
# Later it runs on AKS, reads a secret from Key Vault, and sits behind App Gateway.
from flask import Flask

app = Flask(__name__)


@app.get("/")
def hello():
    return {"message": "hello from the platform test app"}


# Kubernetes probes call this to decide if the container is alive and ready.
@app.get("/health")
def health():
    return {"status": "ok"}
