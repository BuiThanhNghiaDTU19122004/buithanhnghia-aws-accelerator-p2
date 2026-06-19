FROM python:3.13-alpine

# Tạo non-root user/group (UID 1000) trước khi copy code
RUN addgroup -g 1000 appgroup && \
    adduser -u 1000 -G appgroup -D -h /app appuser

RUN pip install --no-cache-dir flask prometheus-flask-exporter

COPY --chown=appuser:appgroup app.py /app/app.py
WORKDIR /app
ENV FLASK_APP=app.py

# Chuyển sang non-root user trước khi chạy
USER 1000

EXPOSE 8080
CMD ["flask", "run", "--host=0.0.0.0", "--port=8080"]