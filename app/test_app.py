"""Unit tests for the Hello World microservice."""

import json
import pytest
from app import app


@pytest.fixture
def client():
    """Create a Flask test client."""
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_hello_root(client):
    resp = client.get("/")
    assert resp.status_code == 200
    data = json.loads(resp.data)
    assert data["message"] == "Hello World"


def test_hello_endpoint(client):
    resp = client.get("/hello")
    assert resp.status_code == 200
    data = json.loads(resp.data)
    assert data["message"] == "Hello World"


def test_healthz(client):
    resp = client.get("/healthz")
    assert resp.status_code == 200
    data = json.loads(resp.data)
    assert data["status"] == "alive"


def test_readyz(client):
    resp = client.get("/readyz")
    assert resp.status_code == 200
    data = json.loads(resp.data)
    assert data["status"] == "ready"


def test_version(client):
    resp = client.get("/version")
    assert resp.status_code == 200
    data = json.loads(resp.data)
    assert "version" in data
    assert "build_time" in data


def test_metrics(client):
    # Hit an endpoint first so there's something to report
    client.get("/hello")
    resp = client.get("/metrics")
    assert resp.status_code == 200
    assert b"http_requests_total" in resp.data

