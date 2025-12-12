# Multi-stage build for security and size optimization
FROM python:3.11-slim AS builder

# Set working directory
WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    unixodbc-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and build wheels
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip>=25.3 \
    && pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

# Final stage - minimal runtime image
FROM python:3.11-slim

# Set environment variables for UTF-8 encoding
ENV PYTHONIOENCODING=utf-8
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Set working directory
WORKDIR /app

# Install only runtime dependencies (no Azure CLI needed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    ca-certificates \
    unixodbc \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg \
    && curl -fsSL https://packages.microsoft.com/config/debian/12/prod.list > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y msodbcsql18 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy pre-built wheels and install (fixes urllib3, starlette, pip CVEs)
COPY --from=builder /wheels /wheels
COPY --from=builder /app/requirements.txt .
RUN pip install --no-cache-dir --upgrade pip>=25.3 \
    && pip install --no-cache-dir --no-index --find-links=/wheels -r requirements.txt \
    && pip install --no-cache-dir --upgrade urllib3>=2.6.0 starlette>=0.49.1 \
    && rm -rf /wheels

# Copy application code
COPY main.py .

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Create non-root user for security
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Run the application directly (managed identity will work in Azure, local needs token passed in)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
