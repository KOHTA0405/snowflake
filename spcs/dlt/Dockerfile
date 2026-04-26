FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir "dlt[snowflake]" requests

COPY pipeline.py .

CMD ["python", "pipeline.py"]
