# Small base image: fewer packages = fewer vulnerabilities for the scan to find.
FROM python:3.12-slim

WORKDIR /app

# Dependencies first: Docker caches this layer until requirements.txt changes.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

# Never run as root inside the container.
RUN useradd --create-home appuser
USER appuser

# TODO: which port does the app listen on? Same number in both lines.
EXPOSE 8080
# gunicorn = a real web server; Flask's own server is for development only.
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "main:app"]
