"""
Hello World microservice — Flask + Prometheus metrics.
Endpoints:
    GET /          → {"message": "Hello World"}
    GET /hello     → {"message": "Hello World"}
    GET /healthz   → {"status": "alive"}       (liveness probe)
    GET /readyz    → {"status": "ready"}        (readiness probe)
    GET /metrics   → Prometheus metrics
    GET /version   → {"version": ..., "build_time": ...}
"""

import os
import signal
import sys
import time
import logging

from flask import Flask, jsonify, request
from prometheus_client import (
    Counter,
    Histogram,
    generate_latest,
    CONTENT_TYPE_LATEST,
)
from werkzeug.serving import make_server

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
VERSION = os.getenv("APP_VERSION", "dev")
BUILD_TIME = os.getenv("BUILD_TIME", "unknown")
PORT = int(os.getenv("PORT", "8080"))

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Prometheus metrics
# ---------------------------------------------------------------------------
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests by path, method, and status",
    ["path", "method", "status"],
)

REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["path", "method"],
)

# ---------------------------------------------------------------------------
# Flask app
# ---------------------------------------------------------------------------
app = Flask(__name__)


@app.before_request
def _start_timer():
    """Record request start time."""
    request._start_time = time.perf_counter()


@app.after_request
def _record_metrics(response):
    """Record Prometheus metrics for every request."""
    # Skip metrics endpoint to avoid self-referential noise
    if request.path == "/metrics":
        return response

    latency = time.perf_counter() - getattr(request, "_start_time", time.perf_counter())
    REQUEST_COUNT.labels(
        path=request.path,
        method=request.method,
        status=response.status_code,
    ).inc()
    REQUEST_LATENCY.labels(
        path=request.path,
        method=request.method,
    ).observe(latency)
    return response


# -- Application endpoints ---------------------------------------------------

@app.route("/")
@app.route("/hello")
def hello():
    """Return Hello World."""
    return jsonify({"message": "Hello World"}), 200


# -- Health checks (Kubernetes probes) --------------------------------------

@app.route("/healthz")
def healthz():
    """Liveness probe."""
    return jsonify({"status": "alive"}), 200


@app.route("/readyz")
def readyz():
    """Readiness probe."""
    return jsonify({"status": "ready"}), 200


# -- Observability -----------------------------------------------------------

@app.route("/metrics")
def metrics():
    """Prometheus metrics endpoint."""
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


@app.route("/version")
def version():
    """Build info."""
    return jsonify({"version": VERSION, "build_time": BUILD_TIME}), 200


# ---------------------------------------------------------------------------
# Graceful shutdown
# ---------------------------------------------------------------------------
server = None


def _shutdown(signum, frame):
    logger.info("Received signal %s, shutting down gracefully...", signum)
    if server:
        server.shutdown()
    sys.exit(0)


def main():
    global server

    signal.signal(signal.SIGINT, _shutdown)
    signal.signal(signal.SIGTERM, _shutdown)

    logger.info(
        "Server starting on :%d (version=%s, built=%s)", PORT, VERSION, BUILD_TIME
    )
    server = make_server("0.0.0.0", PORT, app)
    server.serve_forever()


if __name__ == "__main__":
    main()

