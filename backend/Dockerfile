FROM python:3.11-slim
ARG INSTALL_ML=false
WORKDIR /app
COPY requirements.txt requirements-ml.txt requirements-postgres.txt ./
RUN pip install --no-cache-dir -r requirements.txt -r requirements-postgres.txt onnxruntime \
 && if [ "$INSTALL_ML" = "true" ]; then \
      apt-get update && apt-get install -y --no-install-recommends libglib2.0-0 libgl1 ffmpeg && rm -rf /var/lib/apt/lists/* \
      && pip install --no-cache-dir -r requirements-ml.txt; fi
COPY app app
COPY tools tools
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
