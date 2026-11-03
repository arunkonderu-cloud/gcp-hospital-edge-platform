from fastapi.testclient import TestClient

from src.main import app

client = TestClient(app)


def test_health_and_ready():
    assert client.get("/healthz").json() == {"status": "ok"}
    body = client.get("/readyz").json()
    assert body["status"] == "ready"


def test_complete_tray():
    r = client.post(
        "/v1/scans",
        json={"tray_id": "TRAY-001", "expected_instruments": 12, "detected_instruments": 12, "station": "spd-1"},
    )
    assert r.status_code == 201
    body = r.json()
    assert body["complete"] is True
    assert body["missing"] == 0

    fetched = client.get(f"/v1/scans/{body['id']}")
    assert fetched.status_code == 200
    assert fetched.json()["tray_id"] == "TRAY-001"


def test_incomplete_tray_reports_missing():
    r = client.post(
        "/v1/scans",
        json={"tray_id": "TRAY-002", "expected_instruments": 10, "detected_instruments": 8, "station": "spd-2"},
    )
    assert r.json()["complete"] is False
    assert r.json()["missing"] == 2


def test_rejects_bad_tray_id():
    r = client.post(
        "/v1/scans",
        json={"tray_id": "x; DROP TABLE", "expected_instruments": 1, "detected_instruments": 1, "station": "s"},
    )
    assert r.status_code == 422


def test_unknown_scan_404():
    assert client.get("/v1/scans/does-not-exist").status_code == 404


def test_metrics_exposed():
    r = client.get("/metrics")
    assert r.status_code == 200
    assert "tray_scans_total" in r.text
