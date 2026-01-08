# Frontend Logging Framework Documentation

## Overview

The GrooveApp Angular frontend includes a comprehensive logging framework that integrates with Azure Application Insights while providing graceful fallback for local development.

## Features

- ✅ **Azure Application Insights Integration**: Browser telemetry uploaded to Azure Monitor
- ✅ **Local Development Support**: Works without Application Insights (console logging only)
- ✅ **Configurable Log Levels**: Control verbosity via environment configuration
- ✅ **Automatic HTTP Request Tracking**: All API calls logged with timing and correlation
- ✅ **Global Error Handler**: Unhandled exceptions automatically logged
- ✅ **Operation ID Correlation**: Frontend/backend request correlation via headers
- ✅ **Page View Tracking**: Automatic page navigation tracking
- ✅ **Custom Events and Metrics**: Track user interactions and performance
- ✅ **Audit Trail**: Structured audit logs for compliance

## Configuration

### Environment Files

**Development** (`src/environments/environment.ts`):
```typescript
export const environment = {
  production: false,
  apiUrl: 'http://localhost:8000',
  appInsightsConnectionString: '',  // Empty = console only
  logLevel: 'DEBUG'                 // Verbose local logging
};
```

**Production** (`src/environments/environment.prod.ts`):
```typescript
export const environment = {
  production: true,
  apiUrl: 'https://app-grooveapp-dev-api.azurewebsites.net',
  appInsightsConnectionString: '${APPLICATIONINSIGHTS_CONNECTION_STRING}',
  logLevel: 'INFO'
};
```

### Log Levels

| Level | Description | Use Case |
|-------|-------------|----------|
| `OFF` | No logging | Not recommended |
| `ERROR` | Errors only | Minimal logging |
| `WARNING` | Warnings + errors | Production monitoring |
| `INFO` | Normal operations | **Production default** |
| `DEBUG` | Detailed diagnostics | **Development default** |

## Installation

```bash
cd app
npm install
# This will install @microsoft/applicationinsights-web
```

## Usage Examples

### Basic Logging

Inject the `LoggingService` into any component:

```typescript
import { Component, inject } from '@angular/core';
import { LoggingService } from './services/logging.service';

@Component({
  selector: 'app-musical-staff',
  template: '...'
})
export class MusicalStaffComponent {
  private logger = inject(LoggingService);

  ngOnInit() {
    this.logger.info('Musical staff component initialized', {
      component: 'MusicalStaffComponent',
      page: 'home'
    });
  }

  generateScale(note: string, scaleType: number) {
    this.logger.debug('Generating scale', {
      component: 'MusicalStaffComponent',
      action: 'generate_scale',
      note: note,
      scaleType: scaleType
    });
    
    // Your code here...
  }

  onError(error: Error) {
    this.logger.error('Failed to generate scale', error, {
      component: 'MusicalStaffComponent',
      action: 'generate_scale'
    });
  }
}
```

### Track Custom Events

```typescript
// Track button clicks
this.logger.trackEvent('ButtonClick', {
  buttonName: 'GenerateScale',
  component: 'MusicalStaffComponent',
  note: 'C',
  scaleType: 'Major'
});

// Track user actions
this.logger.trackEvent('UserAction', {
  action: 'change_key_signature',
  from: 'C Major',
  to: 'G Major'
});
```

### Track Page Views

The logging service automatically tracks page views when using Angular Router, but you can also track manually:

```typescript
ngOnInit() {
  this.logger.trackPageView(
    'Musical Staff',
    '/musical-staff',
    { feature: 'scale_visualization' }
  );
}
```

### Track Metrics

```typescript
// Track performance metrics
const renderTime = performance.now() - startTime;
this.logger.trackMetric('StaffRenderTime', renderTime, {
  component: 'MusicalStaffComponent',
  noteCount: notes.length
});
```

### Audit Logging

```typescript
// Create audit trail for security-sensitive actions
this.logger.audit('USER_PREFERENCE_CHANGED', {
  setting: 'key_signature',
  oldValue: 'C Major',
  newValue: 'G Major',
  component: 'SettingsComponent'
});
```

### Set User Context

When user authenticates:

```typescript
onUserLogin(userId: string) {
  this.logger.setUserId(userId);
  this.logger.info('User logged in', {
    component: 'AuthComponent',
    userId: userId
  });
}
```

## Automatic Features

### HTTP Request Logging

The `loggingInterceptor` automatically logs:
- ✅ Every HTTP request (method, URL, headers)
- ✅ Every HTTP response (status code, duration)
- ✅ HTTP errors with full details
- ✅ Backend correlation via `X-Operation-ID` header

**No manual logging required for API calls!**

### Global Error Handling

The `GlobalErrorHandler` automatically catches:
- ✅ Unhandled JavaScript errors
- ✅ Angular component errors
- ✅ Promise rejections
- ✅ RxJS observable errors

All errors are automatically logged to Application Insights with stack traces.

### Page Navigation Tracking

When `enableAutoRouteTracking: true` is set (default), Application Insights automatically tracks:
- Page views on route changes
- Time spent on each page
- Navigation paths

## Application Insights Queries

### View All Frontend Logs

```kusto
traces
| where cloud_RoleName == "grooveapp-frontend"
| project timestamp, message, severityLevel, customDimensions
| order by timestamp desc
```

### Track User Actions

```kusto
customEvents
| where cloud_RoleName == "grooveapp-frontend"
| where name startswith "UserAction"
| project timestamp, name, customDimensions
| order by timestamp desc
```

### Frontend Error Analysis

```kusto
exceptions
| where cloud_RoleName == "grooveapp-frontend"
| project timestamp, type, outerMessage, customDimensions
| order by timestamp desc
```

### API Call Performance

```kusto
dependencies
| where cloud_RoleName == "grooveapp-frontend"
| where type == "HTTP"
| summarize 
    count=count(),
    avg_duration=avg(duration),
    p50=percentile(duration, 50),
    p95=percentile(duration, 95),
    p99=percentile(duration, 99),
    success_rate=100.0 * countif(success == true) / count()
  by name
| order by count desc
```

### Frontend/Backend Correlation

```kusto
// Find all logs for a specific operation
let operationId = "abc123...";
union traces, requests, dependencies, exceptions
| where operation_Id == operationId or customDimensions.operationId == operationId
| project timestamp, itemType, message, cloud_RoleName
| order by timestamp asc
```

### Page View Analytics

```kusto
pageViews
| where cloud_RoleName == "grooveapp-frontend"
| summarize 
    views=count(),
    avg_duration=avg(duration),
    unique_users=dcount(user_Id)
  by name
| order by views desc
```

## Local Development

When running locally **without** Application Insights:

1. ✅ All logs output to browser console
2. ✅ No telemetry sent to Azure
3. ✅ Structured logging still works
4. ✅ Log level controlled via `environment.ts`

```bash
# Start dev server
npm start

# Open browser console (F12) to see logs
# You'll see structured log output like:
[DEBUG] HTTP Request: GET http://localhost:8000/scales { method: "GET", url: "...", operationId: "..." }
[DEBUG] HTTP Response: GET http://localhost:8000/scales - 200 (45ms) { ... }
```

## Build for Production

The production build will use `environment.prod.ts` which includes the Application Insights connection string placeholder:

```bash
npm run build:prod
```

The connection string `${APPLICATIONINSIGHTS_CONNECTION_STRING}` will be replaced at deployment time by the Azure Web App.

## Performance Impact

| Log Level | Performance Impact | Use Case |
|-----------|-------------------|----------|
| OFF | None | Not recommended |
| ERROR | Minimal | Production (errors only) |
| INFO | Low (~1-5ms per action) | **Recommended for production** |
| DEBUG | Medium (~10-20ms per action) | Development only |

Application Insights uses batching and async upload, so the performance impact on user experience is minimal.

## Best Practices

### 1. Use Structured Context

Always include context in your logs:

```typescript
this.logger.info('Action completed', {
  component: 'ComponentName',  // Always include component
  action: 'action_name',       // What action occurred
  userId: 'user123',           // Who performed it
  // Add any relevant data
  itemId: 42,
  duration: 123
});
```

### 2. Log at Appropriate Levels

```typescript
// ERROR: Exceptions and failures that prevent functionality
this.logger.error('Failed to load scale data', error, { ... });

// WARNING: Unexpected situations that don't prevent functionality
this.logger.warning('API response slower than expected', { duration: 5000 });

// INFO: Normal operations and state changes
this.logger.info('Scale generated successfully', { note: 'C', type: 'Major' });

// DEBUG: Detailed diagnostic information
this.logger.debug('Processing note: C', { semitone: 0, octave: 4 });
```

### 3. Track User Interactions

```typescript
onClick() {
  this.logger.trackEvent('ButtonClick', {
    button: 'generate_scale',
    component: 'MusicalStaffComponent'
  });
  // Your code...
}
```

### 4. Use Audit Logs for Security

```typescript
onPermissionChange(permission: string, granted: boolean) {
  this.logger.audit('PERMISSION_CHANGED', {
    permission: permission,
    granted: granted,
    changedBy: this.currentUserId
  });
}
```

### 5. Flush Logs Before Unload

```typescript
ngOnDestroy() {
  this.logger.flush(); // Ensure all logs are sent
}
```

## Troubleshooting

### Logs not appearing in Application Insights

1. **Check connection string**: Open browser console and look for initialization message
2. **Verify log level**: Must not be `OFF`
3. **Wait 2-5 minutes**: Telemetry ingestion has a delay
4. **Check Live Metrics**: Should see real-time data if configured correctly
5. **Check browser console**: Any initialization errors will appear there

### Too verbose in development

```typescript
// In environment.ts, reduce log level:
logLevel: 'INFO'  // Instead of 'DEBUG'
```

### Need more detail for debugging

```typescript
// Temporarily increase log level:
logLevel: 'DEBUG'
```

## Azure Web App Configuration

The Application Insights connection string is automatically injected during the build process in Azure. The placeholder `${APPLICATIONINSIGHTS_CONNECTION_STRING}` in `environment.prod.ts` is replaced with the actual connection string from the Web App settings.

To verify in Azure:

```bash
az webapp config appsettings list \
  --name app-grooveapp-dev-frontend \
  --resource-group rg-grooveapp-dev-uhxg \
  --query "[?name=='APPLICATIONINSIGHTS_CONNECTION_STRING'].value"
```

## Example: Complete Component with Logging

```typescript
import { Component, inject, OnInit, OnDestroy } from '@angular/core';
import { LoggingService } from './services/logging.service';
import { MusicApiService } from './services/music-api.service';

@Component({
  selector: 'app-scale-viewer',
  template: '...'
})
export class ScaleViewerComponent implements OnInit, OnDestroy {
  private logger = inject(LoggingService);
  private musicApi = inject(MusicApiService);

  ngOnInit() {
    this.logger.trackPageView('Scale Viewer', '/scales');
    this.logger.info('Component initialized', {
      component: 'ScaleViewerComponent'
    });
  }

  loadScale(note: string, scaleType: number) {
    this.logger.debug('Loading scale', {
      component: 'ScaleViewerComponent',
      action: 'load_scale',
      note: note,
      scaleType: scaleType
    });

    const startTime = performance.now();

    this.musicApi.getScale(note, scaleType).subscribe({
      next: (scale) => {
        const duration = performance.now() - startTime;
        
        this.logger.info('Scale loaded successfully', {
          component: 'ScaleViewerComponent',
          note: note,
          scaleType: scaleType,
          noteCount: scale.length
        });

        this.logger.trackMetric('ScaleLoadTime', duration, {
          note: note,
          scaleType: scaleType
        });

        this.logger.trackEvent('ScaleViewed', {
          note: note,
          scaleType: scaleType,
          component: 'ScaleViewerComponent'
        });
      },
      error: (error) => {
        this.logger.error('Failed to load scale', error, {
          component: 'ScaleViewerComponent',
          note: note,
          scaleType: scaleType
        });
      }
    });
  }

  ngOnDestroy() {
    this.logger.flush();
  }
}
```
