FROM python:3.11-slim

LABEL org.opencontainers.image.title="APEMAIA PM10 intra-urban inference"
LABEL org.opencontainers.image.description="Inference-only XGBoost container for daily ~300 m PM10 prediction over the Bari intra-urban domain"
LABEL org.opencontainers.image.source="https://github.com/APEMAIAproject/src"
LABEL org.opencontainers.image.version="1.0.0"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    MPLBACKEND=Agg \
    MODEL_DIR=/opt/pms/models \
    INPUT_PATH=/input/input.csv \
    OUTPUT_DIR=/output

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY inference.py /app/inference.py
COPY models/PM10_XGB_BARI_model.json /opt/pms/models/PM10_XGB_BARI_model.json
COPY models/PM10_XGB_BARI_model_features.joblib /opt/pms/models/PM10_XGB_BARI_model_features.joblib

ENTRYPOINT ["python", "/app/inference.py"]
