# Logging Framework Documentation

## Overview

The GrooveApp API includes a comprehensive logging framework that integrates with Azure Application Insights while providing graceful fallback for local development.

## Features

- ✅ **Azure Application Insights Integration**: Automatic telemetry upload to Azure Monitor
- ✅ **Local Development Support**: Works without Application Insights (console logging only)
- ✅ **Configurable Log Levels**: Control verbosity via environment variable
- ✅ **Structured Logging**: Query-friendly log format in Application Insights
- ✅ **Request/Response Tracing**: Automatic logging of all HTTP requests
- ✅ **Database Operation Logging**: Track query performance and failures
- ✅ **Audit Trail**: Structured audit logs for compliance
- ✅ **Distributed Tracing**: Operation IDs for request correlation

## Configuration

### Environment Variables

Set these in your Azure Web App or local environment:

```bash
# Log Level (default: INFO)
# Options: OFF, ERROR, WARNING, INFO, ON, VERBOSE, DEBUG
LOG_LEVEL=INFO

# Application Insights Connection String (automatically set in Azure)
APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=xxx...
```

### Log Levels

| Level | Description | Use Case |
|-------|-------------|----------|
| `OFF` | No logging | Production with minimal overhead |
| `ERROR` | Errors only | Production troubleshooting |
| `WARNING` | Warnings + errors | Production monitoring |
| `INFO` / `ON` | Normal operations | **Default** - Production use |
| `VERBOSE` / `DEBUG` | Detailed diagnostics | Development & debugging |

## Usage Examples

### Basic Logging

```python
from logging_config import logger

# Info logging
logger.info("User authenticated successfully")

# Warning logging
logger.warning("Database query took longer than expected")

# Error logging
logger.error("Failed to connect to database", exc_info=True)
```

### Structured Logging with Context

```python
logger.info(
    "Scale generated successfully",
    extra={
        'operation_id': request.state.operation_id,
        'user_id': request.state.user_id,
        'request_path': request.url.path,
        'scale_type': 'Major',
        'root_note': 'C',
        'duration_ms': 15
    }
)
```

### Database Operation Logging

```python
from logging_middleware import DatabaseLoggingMiddleware

@app.get("/scales/{note}/{scale_type_id}")
async def get_scale(note: str, scale_type_id: int, request: Request):
    with DatabaseLoggingMiddleware(logger, f"Get scale {note} type {scale_type_id}", request):
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM dbo.fn_GenerateScale(?, ?)", note, scale_type_id)
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
    
    # Automatically logs start, duration, and errors
    return rows
```

### Audit Logging

```python
from logging_config import create_audit_log

create_audit_log(
    logger=logger,
    event_type='USER_ACCESS',
    user_id=user_id,
    operation_id=operation_id,
    details={'action': 'view_scale', 'resource': f'/scales/{note}/{scale_type_id}'},
    request_path=request.url.path,
    duration_ms=25
)
```

## Application Insights Queries

### View All Requests

```kusto
requests
| where cloud_RoleName == "grooveapp-api"
| project timestamp, name, duration, resultCode, operation_Id
| order by timestamp desc
```

### Find Slow Queries

```kusto
traces
| where message contains "DB SUCCESS"
| extend duration_ms = toint(customDimensions.duration_ms)
| where duration_ms > 100
| project timestamp, message, duration_ms, operation_id=customDimensions.operation_id
| order by duration_ms desc
```

### Track Errors

```kusto
traces
| where severityLevel >= 3  // Error or Critical
| project timestamp, message, severityLevel, operation_id=customDimensions.operation_id, error=customDimensions.error
| order by timestamp desc
```

### Audit Trail Query

```kusto
traces
| where message startswith "AUDIT:"
| extend event_type = customDimensions.event_type
| extend user_id = customDimensions.user_id
| extend details = customDimensions.details
| project timestamp, event_type, user_id, details, operation_id=customDimensions.operation_id
| order by timestamp desc
```

### Request Success Rate

```kusto
requests
| where cloud_RoleName == "grooveapp-api"
| summarize 
    total = count(),
    success = countif(success == true),
    failure = countif(success == false)
| extend success_rate = round(todouble(success) / todouble(total) * 100, 2)
```

## Local Development

When running locally **without** Application Insights:

1. Logs output to console only
2. No telemetry sent to Azure
3. All structured logging still works
4. Log level controlled via `LOG_LEVEL` environment variable

```bash
# Local testing with different log levels
docker run -e LOG_LEVEL=DEBUG ...    # Verbose output
docker run -e LOG_LEVEL=INFO ...     # Normal output (default)
docker run -e LOG_LEVEL=ERROR ...    # Errors only
docker run -e LOG_LEVEL=OFF ...      # No logging
```

## Automatic Features

The `RequestLoggingMiddleware` automatically logs:

- ✅ Every HTTP request (method, path, query params, client IP)
- ✅ Every HTTP response (status code, duration)
- ✅ Request/response correlation via `X-Operation-ID` header
- ✅ User identification from `X-User-ID` header (if present)
- ✅ Errors with full stack traces

## Performance Impact

| Log Level | Performance Impact | Use Case |
|-----------|-------------------|----------|
| OFF | None | Maximum performance |
| ERROR | Minimal | Production (errors only) |
| INFO | Low (~1-2ms per request) | **Recommended for production** |
| DEBUG | Medium (~5-10ms per request) | Development only |

## Best Practices

1. **Use structured logging**: Always include `operation_id`, `user_id`, `request_path` in `extra` dict
2. **Log at appropriate levels**: 
   - `ERROR`: Exceptions and failures
   - `WARNING`: Degraded performance or unexpected behavior
   - `INFO`: Normal operations and state changes
   - `DEBUG`: Detailed diagnostic information
3. **Include context**: Add relevant data to `extra` dict for better querying
4. **Use audit logs**: Create audit trail for security-sensitive operations
5. **Monitor in production**: Set `LOG_LEVEL=INFO` in Azure Web App

## Azure Web App Configuration

To configure logging in Azure:

```bash
# Set log level
az webapp config appsettings set --name app-grooveapp-dev-api \\
  --resource-group rg-grooveapp-dev-uhxg \\
  --settings LOG_LEVEL=INFO

# Connection string is automatically set via Terraform
# APPLICATIONINSIGHTS_CONNECTION_STRING is already configured
```

## Troubleshooting

### Logs not appearing in Application Insights

1. Check connection string: `echo $APPLICATIONINSIGHTS_CONNECTION_STRING`
2. Verify log level: `echo $LOG_LEVEL` (must not be `OFF`)
3. Wait 2-5 minutes for telemetry ingestion
4. Check Application Insights Live Metrics for real-time data

### Too many logs

```bash
# Reduce log verbosity
az webapp config appsettings set --name app-grooveapp-dev-api \\
  --settings LOG_LEVEL=WARNING
```

### Need more detail for debugging

```bash
# Increase log verbosity temporarily
az webapp config appsettings set --name app-grooveapp-dev-api \\
  --settings LOG_LEVEL=DEBUG

# Remember to set back to INFO after debugging!
```
