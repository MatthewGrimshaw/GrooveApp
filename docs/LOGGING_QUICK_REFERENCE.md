# Logging Framework - Quick Reference

## Backend (Python API)

### Setup
```python
from logging_config import logger, create_audit_log
from logging_middleware import DatabaseLoggingMiddleware
```

### Basic Logging
```python
logger.debug("Detailed debug info")
logger.info("Normal operation")
logger.warning("Something unexpected")
logger.error("Error occurred", exc_info=True)
```

### With Context
```python
logger.info("User action", extra={
    'operation_id': request.state.operation_id,
    'user_id': request.state.user_id,
    'request_path': request.url.path,
    'action': 'generate_scale',
    'note': 'C'
})
```

### Database Operations
```python
with DatabaseLoggingMiddleware(logger, "Get scales", request):
    # Your DB code - automatically logs timing/errors
    pass
```

### Audit Logging
```python
create_audit_log(
    logger=logger,
    event_type='DATA_ACCESS',
    user_id='user123',
    operation_id='op456',
    details={'resource': 'scales', 'action': 'read'},
    request_path='/scales/C/1'
)
```

### Environment Variables
```bash
LOG_LEVEL=DEBUG  # OFF, ERROR, WARNING, INFO, DEBUG
APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=...
```

---

## Frontend (Angular)

### Setup
```typescript
import { LoggingService } from './services/logging.service';

private logger = inject(LoggingService);
```

### Basic Logging
```typescript
this.logger.debug('Debug message', { component: 'MyComponent' });
this.logger.info('Info message', { component: 'MyComponent' });
this.logger.warning('Warning message', { component: 'MyComponent' });
this.logger.error('Error message', error, { component: 'MyComponent' });
```

### Track Events
```typescript
this.logger.trackEvent('ButtonClick', {
  button: 'generate_scale',
  component: 'MusicalStaffComponent'
});
```

### Track Page Views
```typescript
this.logger.trackPageView('Scale Viewer', '/scales', {
  feature: 'visualization'
});
```

### Track Metrics
```typescript
this.logger.trackMetric('RenderTime', durationMs, {
  component: 'MusicalStaffComponent'
});
```

### Audit Logging
```typescript
this.logger.audit('USER_ACTION', {
  action: 'change_key_signature',
  from: 'C Major',
  to: 'G Major'
});
```

### Set User Context
```typescript
this.logger.setUserId('user@example.com');
```

### Environment Configuration
```typescript
// environment.ts
export const environment = {
  production: false,
  apiUrl: 'http://localhost:8000',
  appInsightsConnectionString: '',  // Empty for local dev
  logLevel: 'DEBUG'  // OFF, ERROR, WARNING, INFO, DEBUG
};
```

---

## Application Insights Queries

### All Backend Logs
```kusto
traces
| where cloud_RoleName == "grooveapp-api"
| project timestamp, message, severityLevel, customDimensions
| order by timestamp desc
```

### All Frontend Logs
```kusto
traces
| where cloud_RoleName == "grooveapp-frontend"
| project timestamp, message, severityLevel, customDimensions
| order by timestamp desc
```

### Correlate Frontend/Backend Requests
```kusto
let operationId = "abc123...";
union traces, requests, dependencies, exceptions
| where operation_Id == operationId or customDimensions.operationId == operationId
| project timestamp, itemType, message, cloud_RoleName
| order by timestamp asc
```

### API Performance
```kusto
requests
| where cloud_RoleName == "grooveapp-api"
| summarize 
    count=count(),
    avg_duration=avg(duration),
    p95=percentile(duration, 95),
    success_rate=100.0 * countif(success == true) / count()
  by name
| order by count desc
```

### Error Analysis
```kusto
exceptions
| union traces | where severityLevel >= 3
| where cloud_RoleName in ("grooveapp-api", "grooveapp-frontend")
| project timestamp, cloud_RoleName, message, severityLevel
| order by timestamp desc
```

### Slow Database Queries
```kusto
traces
| where message contains "DB SUCCESS"
| extend duration_ms = toint(customDimensions.duration_ms)
| where duration_ms > 100
| project timestamp, message, duration_ms, operation_id=customDimensions.operation_id
| order by duration_ms desc
```

### Audit Trail
```kusto
traces
| where message startswith "AUDIT:"
| extend event_type = customDimensions.event_type
| extend user_id = customDimensions.user_id
| project timestamp, cloud_RoleName, event_type, user_id, customDimensions
| order by timestamp desc
```

---

## Log Levels Comparison

| Level | Backend (Python) | Frontend (Angular) | Production? |
|-------|------------------|-------------------|-------------|
| OFF | No logs | No logs | ❌ Not recommended |
| ERROR | Errors only | Errors only | ⚠️ Minimal visibility |
| WARNING | Warnings + Errors | Warnings + Errors | ⚠️ Limited visibility |
| INFO | Normal ops | Normal ops | ✅ **Recommended** |
| DEBUG | Verbose | Verbose | ❌ Development only |

---

## Testing

### Local Backend
```bash
cd api
LOG_LEVEL=DEBUG python -m uvicorn main:app --reload
```

### Local Frontend
```bash
cd app
npm start
# Open browser console (F12) to see logs
```

### Check Application Insights
1. Go to Azure Portal → Application Insights
2. Click "Logs" or "Live Metrics"
3. Run queries from above
4. Wait 2-5 minutes for telemetry ingestion

---

## Common Patterns

### Component Lifecycle Logging
```typescript
export class MyComponent implements OnInit, OnDestroy {
  private logger = inject(LoggingService);

  ngOnInit() {
    this.logger.info('Component initialized', { 
      component: 'MyComponent' 
    });
  }

  ngOnDestroy() {
    this.logger.flush();
  }
}
```

### API Error Handling
```python
@app.get("/scales/{note}/{scale_type_id}")
async def get_scale(note: str, scale_type_id: int, request: Request):
    try:
        with DatabaseLoggingMiddleware(logger, f"Get scale {note}", request):
            # DB code
            pass
        return result
    except Exception as e:
        logger.error(f"Failed to get scale", exc_info=True, extra={
            'operation_id': request.state.operation_id,
            'note': note,
            'scale_type_id': scale_type_id
        })
        raise HTTPException(status_code=500, detail=str(e))
```

### HTTP Request Tracking (Automatic!)
Both frontend and backend automatically track HTTP requests with:
- Request/response timing
- Status codes
- Operation ID correlation
- Error details

**No manual logging needed for API calls!**
