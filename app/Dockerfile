# =============================================================================
# Stage 1: Build — install dependencies in a virtual env
# =============================================================================
FROM python:3.12-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

COPY . .

# =============================================================================
# Stage 2: Runtime — slim image with only what's needed
# =============================================================================
FROM python:3.12-slim

# Security: run as non-root
RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser

WORKDIR /app

# Copy virtual env and application code
COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /build/app.py .

# Use the virtual env
ENV PATH="/opt/venv/bin:$PATH"
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Build-time metadata passed as env vars
ARG VERSION=dev
ARG BUILD_TIME=unknown
ENV APP_VERSION=${VERSION}
ENV BUILD_TIME=${BUILD_TIME}

USER appuser

EXPOSE 8080

# Use gunicorn for production (4 workers, graceful timeout)
CMD ["gunicorn", \
     "--bind", "0.0.0.0:8080", \
     "--workers", "4", \
     "--timeout", "30", \
     "--graceful-timeout", "30", \
     "--access-logfile", "-", \
     "app:app"]

