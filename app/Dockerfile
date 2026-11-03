# syntax=docker/dockerfile:1.7
# Multi-stage build -> distroless runtime:
#  - no shell, no package manager in the final image (smaller attack surface, fewer CVEs)
#  - runs as non-root (uid 65532)
#  - read-only root filesystem friendly

FROM python:3.12-slim AS build
WORKDIR /build
ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
COPY requirements.txt .
RUN pip install --target /deps -r requirements.txt
COPY src/ ./src/

FROM gcr.io/distroless/python3-debian12:nonroot
WORKDIR /app
COPY --from=build /deps /deps
COPY --from=build /build/src ./src
ENV PYTHONPATH=/deps PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["python3", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8080"]
