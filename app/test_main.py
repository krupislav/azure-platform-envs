# CI runs this before building the image: a broken app never becomes an image.
from main import app


def test_health():
    client = app.test_client()
    response = client.get("/health")

    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}
