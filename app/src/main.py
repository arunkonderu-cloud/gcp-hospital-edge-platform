"""tray-tracker: sample microservice that records surgical-tray scan events.

Designed to run identically on GKE and on a hospital edge cluster (k3s).
- No PHI is logged; patient identifiers are never accepted by this API.
- Structured JSON logs so Cloud Logging / Loki can index them.
- /healthz (liveness) and /readyz (readiness) for Kubernetes probes.
- /metrics for Prometheus.
"""

from __future__ import annotations

import logging
import os
import time
import uuid
from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException, Request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from pydantic import BaseModel, Field
from starlette.responses import Response

SITE_ID = os.getenv("SITE_ID", "gcp-dev")
VERSION = os.getenv("APP_VERSION", "dev")

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format='{"ts":"%(asctime)s","level":"%(levelname)s","site":"' + SITE_ID + '","msg":"%(message)s"}',
)
log = logging.getLogger("tray-tracker")

REQUESTS = Counter("http_requests_total", "HTTP requests", ["method", "path", "status"])
LATENCY = Histogram("http_request_duration_seconds", "Request latency", ["path"])
SCANS = Counter("tray_scans_total", "Tray scan events", ["site", "result"])

app = FastAPI(title="tray-tracker", version=VERSION)

# In-memory store keeps the demo dependency-free. Production would use Cloud SQL
# (GCP) or a local Postgres on the edge node with outbound replication.
_EVENTS: dict[str, dict] = {}


class ScanEvent(BaseModel):
    tray_id: str = Field(..., min_length=3, max_length=64, pattern=r"^[A-Za-z0-9\-]+$")
    expected_instruments: int = Field(..., ge=0, le=500)
    detected_instruments: int = Field(..., ge=0, le=500)
    station: str = Field(..., min_length=1, max_length=32)


class ScanResult(ScanEvent):
    id: str
    site: str
    complete: bool
    missing: int
    recorded_at: str


@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    path = request.url.path
    LATENCY.labels(path).observe(time.perf_counter() - start)
    REQUESTS.labels(request.method, path, str(response.status_code)).inc()
    return response


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}


@app.get("/readyz")
def readyz() -> dict:
    return {"status": "ready", "site": SITE_ID, "version": VERSION}


@app.get("/metrics")
def metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.post("/v1/scans", status_code=201, response_model=ScanResult)
def record_scan(event: ScanEvent) -> ScanResult:
    missing = max(event.expected_instruments - event.detected_instruments, 0)
    complete = missing == 0
    result = ScanResult(
        **event.model_dump(),
        id=str(uuid.uuid4()),
        site=SITE_ID,
        complete=complete,
        missing=missing,
        recorded_at=datetime.now(timezone.utc).isoformat(),
    )
    _EVENTS[result.id] = result.model_dump()
    SCANS.labels(SITE_ID, "complete" if complete else "incomplete").inc()
    log.info("scan recorded tray=%s complete=%s missing=%d", event.tray_id, complete, missing)
    return result


@app.get("/v1/scans/{scan_id}", response_model=ScanResult)
def get_scan(scan_id: str) -> ScanResult:
    event = _EVENTS.get(scan_id)
    if event is None:
        raise HTTPException(status_code=404, detail="scan not found")
    return ScanResult(**event)
