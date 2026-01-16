# GrooveApp - GitHub Copilot Instructions

## Project Overview

**GrooveApp** is a music theory application with a three-tier architecture:
- **Angular Frontend** (presentation layer - display only)
- **FastAPI Backend** (business logic layer)
- **Azure SQL Database** (data layer with music theory calculations)

The app generates scales, arpeggios, intervals, and jazz chord extensions with correct enharmonic spelling following music theory conventions.

## Architecture Rules

### Component Responsibilities

**Angular Frontend (`/app`)**
- ✅ Display data fetched from API
- ✅ User input collection (dropdowns, selections)
- ✅ UI/UX interactions
- ✅ Musical staff rendering (SVG visualization)
- ❌ **NEVER implement music theory calculations in the frontend**
- ❌ **NEVER implement business logic in the frontend**

**FastAPI API (`/api`)**
- ✅ REST endpoint definitions
- ✅ Request/response validation (Pydantic models)
- ✅ Database connection management
- ✅ Error handling and HTTP responses
- ✅ CORS configuration
- ⚠️ Prefer implementing calculations in database when possible

**Azure SQL Database**
- ✅ All music theory data storage
- ✅ Complex calculations (scale generation, interval calculations)
- ✅ Note spelling logic (enharmonic equivalents, key signatures)
- ✅ SQL functions for business logic
- ✅ Data validation and constraints

### Decision Framework: Where to Implement Logic

**Database** - Use for:
- Music theory calculations
- Complex queries with JOINs
- Set-based operations
- Data transformations

**API** - Use for:
- HTTP endpoint logic
- Request validation
- External integrations
- Authentication/authorization

**Frontend** - Use for:
- Data presentation
- User interactions
- Visual rendering
- Navigation

## Critical Build & Test Scripts

### Single-Purpose Script Philosophy

⚠️ **NEVER create alternative build or test scripts**

Each task has ONE authoritative script:

**API Docker Build**: `api/build-localApi.ps1`
- Performs CVE scanning with Docker Scout
- Fails on HIGH/CRITICAL vulnerabilities
- DO NOT create: `build-api-v2.ps1`, `quick-build.ps1`, etc.
- UPDATE this file for any build changes

**Frontend Docker Build**: `app/build-localFrontEnd.ps1`
- Performs CVE scanning with Docker Scout
- Fails on HIGH/CRITICAL vulnerabilities
- DO NOT create: `build-frontend-v2.ps1`, `dev-build.ps1`, etc.
- UPDATE this file for any build changes

**API Testing**: `api/test-apiResponses.ps1`
- Tests ALL API endpoints (509+ comprehensive tests)
- Single source of truth for API validation
- Tests locally (Docker) or Azure deployments
- DO NOT create: `quick-test.ps1`, `test-v2.ps1`, etc.
- UPDATE this file when adding new endpoints

## Log File Management

### ⚠️ CRITICAL: Centralized Log Storage Rule

**ALL log files MUST be stored in `/logs/` directory at repository root.**

This is a **STRICT, NON-NEGOTIABLE** rule that MUST be followed for:
- ✅ Troubleshooting logs
- ✅ Deployment logs
- ✅ Test execution logs
- ✅ Debug output files
- ✅ Performance logs
- ✅ API response captures
- ✅ Azure CLI output
- ✅ Terraform logs
- ✅ Any diagnostic or debugging output

### Log File Placement Rules

**ALWAYS place logs in `/logs/` with descriptive filenames:**

```powershell
# ✅ CORRECT - Robust path resolution (works in VS Code, ISE, terminal)
$scriptPath = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$repoRoot = $scriptPath
while ($repoRoot -and -not (Test-Path (Join-Path $repoRoot ".git"))) {
    $repoRoot = Split-Path -Parent $repoRoot
}
if (-not $repoRoot) { $repoRoot = Split-Path -Parent $scriptPath }

$logFile = Join-Path $repoRoot "logs" "deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$logFile = Join-Path $repoRoot "logs" "test-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$logFile = Join-Path $repoRoot "logs" "troubleshooting-circle-of-fifths.log"

# ❌ WRONG - Never scatter logs across repository
$logFile = "$PSScriptRoot\debug.log"           # Don't put in script directory
$logFile = "$PSScriptRoot\..\api-logs.txt"    # Don't put in root
$logFile = "$PSScriptRoot\temp\output.json"   # Don't create temp folders
```

**Naming Convention:**
- Use descriptive names: `deployment-{timestamp}.log`, `test-api-{date}.log`
- Include timestamps for sequential runs
- Use kebab-case: `troubleshooting-auth-issue.log`
- Group related logs: `terraform-apply-{timestamp}.log`

**Git Exclusion:**
- `/logs/` is excluded in `.gitignore` - logs are NEVER committed
- This prevents repository pollution with diagnostic files
- Ensures clean commit history without temporary files

**Why This Matters:**
- 🎯 Single location to find ALL troubleshooting data
- 🧹 Prevents log files scattered across repository
- 🚫 Logs never committed to version control
- 📊 Easy to review recent debugging sessions
- 🗑️ Simple cleanup: delete `/logs/` folder

### Example Usage in Scripts

```powershell
# Robust path resolution for /logs/ folder (works in VS Code, PowerShell ISE, and terminal)
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# Get script directory - works in VS Code, ISE, and direct execution
$scriptPath = if ($PSScriptRoot) { 
    $PSScriptRoot 
}
elseif ($psISE) { 
    Split-Path -Parent $psISE.CurrentFile.FullPath 
}
elseif ($null -ne $psEditor) {
    Split-Path -Parent $psEditor.GetEditorContext().CurrentFile.Path
}
else {
    $PWD.Path
}

# Navigate to repository root and find logs folder
$repoRoot = $scriptPath
while ($repoRoot -and -not (Test-Path (Join-Path $repoRoot ".git"))) {
    $repoRoot = Split-Path -Parent $repoRoot
}

if (-not $repoRoot) {
    # Fallback: assume we're in a subdirectory and go up one level
    $repoRoot = Split-Path -Parent $scriptPath
}

$logDir = Join-Path $repoRoot "logs"

# Ensure logs directory exists
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Create log file with descriptive name
$logFile = Join-Path $logDir "deployment-$timestamp.log"

# Write to log
"Starting deployment..." | Tee-Object -FilePath $logFile -Append
```

**Alternative: Simpler approach for scripts in known locations**

```powershell
# If your script is always in /api/ or /infra/ subdirectory
$scriptPath = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$logDir = Join-Path (Split-Path -Parent $scriptPath) "logs"

# Or hardcode from workspace root for VS Code tasks
$logDir = Join-Path $env:WORKSPACE "logs"  # When running as VS Code task

# Create log with timestamp
$logFile = Join-Path $logDir "my-script-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
```


## Repository Structure

```
grooveapp/
├── api/                          # FastAPI Backend (Python 3.11)
│   ├── main.py                   # All API endpoints
│   ├── requirements.txt          # Python dependencies
│   ├── Dockerfile                # Multi-stage Docker build
│   ├── build-localApi.ps1        # ⚠️ ONLY API build script
│   └── test-apiResponses.ps1     # ⚠️ ONLY API test script
│
├── app/                          # Angular Frontend (v19.2)
│   ├── src/app/
│   │   ├── components/           # Angular components
│   │   ├── services/             # HTTP services
│   │   ├── models/               # TypeScript interfaces
│   │   └── app.component.*       # Main component
│   ├── package.json              # Node.js dependencies
│   ├── Dockerfile                # Multi-stage Docker build
│   └── build-localFrontEnd.ps1   # ⚠️ ONLY Frontend build script
│
├── infra/                        # Infrastructure as Code
│   ├── build-appInfra.ps1        # Deploy to Azure
│   ├── deploy-updates.ps1        # Update existing deployment
│   ├── cleanup-appInfra.ps1      # Delete Azure resources
│   └── setup-music-tables.sql    # Database schema & data
│
└── logs/                         # ⚠️ ALL logs go here (git-ignored)
    ├── deployment-*.log          # Deployment logs
    ├── test-*.log                # Test execution logs
    ├── troubleshooting-*.log     # Debug and diagnostic logs
    └── terraform-*.log           # Infrastructure logs
```

## Code Standards

### Python (FastAPI)

```python
# Use type hints with Pydantic models
class ChordExtension(BaseModel):
    ExtensionId: int
    ExtensionName: str
    Note: Optional[str] = None

# Use async/await for endpoints
@app.get("/chords/{chord_type_id}/extensions")
async def get_chord_extensions(chord_type_id: int, root_note: Optional[str] = None):
    try:
        # Database queries here
        pass
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Always handle errors with HTTPException
# Use descriptive endpoint names
# Include docstrings for complex endpoints
```

### TypeScript (Angular)

```typescript
// Use standalone components (Angular 19+)
@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, FormsModule, HttpClientModule],
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})

// Use interfaces matching API responses (PascalCase)
export interface ChordExtension {
  ExtensionId: number;
  ExtensionName: string;
  Note: string | null;
}

// Use RxJS Observables for API calls
getChordExtensions(chordTypeId: number, rootNote?: string): Observable<ChordExtension[]> {
  const url = rootNote 
    ? `${this.apiUrl}/chords/${chordTypeId}/extensions?root_note=${encodeURIComponent(rootNote)}`
    : `${this.apiUrl}/chords/${chordTypeId}/extensions`;
  return this.http.get<ChordExtension[]>(url);
}

// NO business logic in components - only display and user interaction
```

### SQL

```sql
-- Use proper indentation and formatting
-- Include COALESCE for NULL handling
-- Use descriptive table/column names
-- Add comments for complex queries

SELECT 
    ExtensionId,
    ExtensionName,
    COALESCE(Description, 'No description') AS Description
FROM dbo.ChordExtensions
WHERE ChordTypeId = @chordTypeId
ORDER BY DisplayOrder, Semitones;

-- Use SQL functions for calculations
-- Prefer set-based operations over cursors
```

### PowerShell

```powershell
# Use clear variable names
$apiUrl = "http://localhost:8000"

# Include error handling
try {
    $response = Invoke-WebRequest -Uri $url -Method Get
} catch {
    Write-Error "Failed: $_"
    exit 1
}

# Add comments for complex logic
# Use consistent formatting (4 spaces)
# Include script parameters
```

## Common Tasks

### Adding a New API Endpoint

1. **Define Pydantic model** in `api/main.py`
2. **Create endpoint** with proper decorators and error handling
3. **Update API tests** in `api/test-apiResponses.ps1`
4. **Test locally**: `cd api; .\test-apiResponses.ps1`
5. **Update frontend service** in `app/src/app/services/music-api.service.ts`
6. **Update TypeScript interface** in `app/src/app/models/music.models.ts`
7. **Update component** to use new data
8. **Update template** to display new data

### Adding Database Tables/Functions

1. **Edit** `infra/setup-music-tables.sql`
2. **Test SQL** locally or in Azure SQL
3. **Update API endpoints** to use new data
4. **Update tests** to validate new data
5. **Document** in query examples if needed

### Modifying Build Process

1. **Edit existing script**: `build-localApi.ps1` or `build-localFrontEnd.ps1`
2. **Maintain CVE scanning** - never remove security checks
3. **Test locally** before committing
4. **Never create alternative build scripts**

### Updating Dependencies

**Python:**
```powershell
cd api
pip install --upgrade <package>
pip freeze > requirements.txt
.\build-localApi.ps1  # Verify no CVE issues
```

**Node.js:**
```powershell
cd app
npm update <package>
.\build-localFrontEnd.ps1  # Verify no CVE issues
```

## Security Requirements

### Mandatory CVE Scanning
- All Docker builds MUST include CVE scanning
- Builds MUST FAIL on HIGH or CRITICAL vulnerabilities
- No exceptions for "quick builds" or "dev-only" images

### Authentication
- Azure Entra ID (Easy Auth) for production
- Managed Identity for database access (no credentials in code)
- CORS configured for specific origins only

### Environment Variables
- Never hardcode credentials
- Use environment variables for SQL_SERVER, SQL_DATABASE
- Use .env files for local development (excluded from Git)

## Testing Guidelines

### API Testing
- Use `api/test-apiResponses.ps1` for all API validation
- Test ALL endpoints comprehensively
- Validate data quality (no NULL values, proper formatting)
- Test both local Docker and Azure deployments

### Frontend Testing
```powershell
cd app
npm test  # Jasmine/Karma unit tests
```

### Integration Testing
```powershell
# Start API locally
cd api
docker run -p 8000:8000 -e SQL_SERVER="..." -e SQL_DATABASE="..." grooveapp-api

# Start Frontend locally
cd app
docker run -p 8080:80 -e API_URL="http://localhost:8000" grooveapp-frontend

# Test full stack
cd api
.\test-apiResponses.ps1
```

## Common Patterns

### Calculating Notes from Intervals
```python
# CORRECT: Use modulo arithmetic with SemitonesFromC
note_cursor.execute("""
    SELECT TOP 1 NoteName
    FROM dbo.Notes
    WHERE SemitonesFromC = (
        (SELECT SemitonesFromC FROM dbo.Notes WHERE NoteName = ?) + ?
    ) % 12
    AND (IsSharp = 1 OR IsNatural = 1)
    ORDER BY IsNatural DESC, IsSharp DESC
""", (root_note, semitones))

# WRONG: Using NoteId arithmetic (doesn't wrap correctly)
```

### Frontend Service Pattern
```typescript
// Always use Observable pattern
// Always encode special characters (# becomes %23)
getScale(rootNote: string, scaleTypeId: number): Observable<ScaleDegree[]> {
  const encodedNote = rootNote.replace('#', '%23');
  return this.http.get<ScaleDegree[]>(
    `${this.apiUrl}/scales/${encodedNote}/${scaleTypeId}`
  );
}
```

### Component Data Loading
```typescript
// Load data in lifecycle hooks
ngOnInit() {
  this.loadInitialData();
}

// Separate method for data loading
loadInitialData() {
  this.musicApi.getNotes().subscribe({
    next: (notes) => this.notes = notes,
    error: (err) => console.error('Failed to load notes:', err)
  });
}

// NO calculations - only display
```

## Deployment

### Local Development
```powershell
# Build API
cd api
.\build-localApi.ps1

# Build Frontend
cd app
.\build-localFrontEnd.ps1

# Test API
cd api
.\test-apiResponses.ps1
```

### Azure Deployment
```powershell
# Full deployment
cd infra
.\build-appInfra.ps1

# Code updates only
cd infra
.\deploy-updates.ps1

# Cleanup
cd infra
.\cleanup-appInfra.ps1
```

## Key Concepts

### Music Theory Considerations
- **Enharmonic Spelling**: F Major uses Bb, not A#
- **Each letter A-G appears exactly once** in each scale
- **Key Signatures**: Determined by Circle of Fifths
- **Jazz Extensions**: 9th, 11th, 13th, altered tones (b9, #9, #11, b13)

### Data Flow
```
User Input → Angular Component → HTTP Service → FastAPI Endpoint → 
SQL Query → Database Function → Result Set → JSON Response → 
TypeScript Interface → Angular Template → DOM Rendering
```

## Anti-Patterns to Avoid

❌ Creating alternative build scripts (`build-v2.ps1`)
❌ Creating alternative test scripts (`quick-test.ps1`)
❌ Implementing music theory logic in Angular
❌ Hardcoding credentials or connection strings
❌ Removing CVE scanning from build scripts
❌ Using cursors instead of set-based SQL
❌ Direct DOM manipulation in Angular
❌ Synchronous HTTP calls (use Observables)

## When in Doubt

1. **Logic placement**: If it's a calculation → Database. If it's presentation → Frontend. If it's HTTP → API.
2. **Build changes**: Update existing script, don't create new ones.
3. **Testing**: Use `test-apiResponses.ps1`, don't create alternatives.
4. **Security**: Maintain CVE scanning, no exceptions.
5. **Data flow**: Always: Database → API → Frontend, never Frontend → Database.
## Logging & Monitoring

### Overview

GrooveApp uses **Azure Application Insights** for centralized logging, monitoring, and diagnostics in Azure environments. Local development uses console logging.

**Environment Variables:**
- `APPLICATIONINSIGHTS_CONNECTION_STRING`: App Insights connection string (Azure only)
- `LOG_LEVEL`: Controls verbosity - `OFF`, `ERROR`, `WARNING`, `INFO`, `DEBUG`

### API Logging (Python/FastAPI)

**Framework: OpenCensus** (configured in `api/logging_config.py`)

#### Correct Logging Pattern

```python
# ✅ CORRECT: Use logger with extra context
from logging_config import configure_logging

# Initialize logger at module level
logger = configure_logging(
    app_insights_connection_string=os.getenv('APPLICATIONINSIGHTS_CONNECTION_STRING'),
    log_level=os.getenv('LOG_LEVEL', 'INFO'),
    service_name='grooveapp-api'
)

# Log with structured context
logger.info(
    "Processing chord extensions request",
    extra={
        'operation_id': getattr(request.state, 'operation_id', 'N/A'),
        'user_id': getattr(request.state, 'user_id', 'anonymous'),
        'request_path': '/chords/extensions',
        'chord_type_id': chord_type_id,
        'root_note': root_note
    }
)

# Log errors with exception info
logger.error(
    f"Database query failed: {str(e)}",
    extra={
        'operation_id': operation_id,
        'user_id': 'system',
        'request_path': '/database-error',
        'error_type': type(e).__name__
    },
    exc_info=True  # Includes full stack trace
)
```

#### Required Context Fields

**All log entries MUST include these fields in `extra`:**
- `operation_id`: Unique ID for request correlation (from `request.state.operation_id`)
- `user_id`: User identifier or `'anonymous'` or `'system'`
- `request_path`: API endpoint path (e.g., `/chords/extensions`)

**Optional but recommended:**
- `duration_ms`: Operation duration in milliseconds
- `status_code`: HTTP response status
- `error_type`: Exception class name
- Custom fields: `chord_type_id`, `root_note`, etc.

#### Log Levels

```python
# OFF: Disable all logging (production troubleshooting only)
LOG_LEVEL = 'OFF'

# ERROR: Only errors and exceptions
logger.error("Database connection failed", extra={...})

# WARNING: Warnings and above
logger.warning("Deprecated endpoint called", extra={...})

# INFO: Normal operations (default)
logger.info("Request processed successfully", extra={...})

# DEBUG/VERBOSE: Detailed diagnostics
logger.debug("Executing SQL query", extra={'query': sql, ...})
```

#### Automatic Request Logging

The `RequestLoggingMiddleware` automatically logs:
- ✅ Request start (INFO)
- ✅ Request completion with duration (INFO)
- ✅ Request errors (ERROR with exc_info)

```python
# Already configured in main.py - NO CODE CHANGES NEEDED
app.add_middleware(RequestLoggingMiddleware, logger=logger)
```

#### Database Logging Pattern

```python
# Use DatabaseLoggingMiddleware for query tracking
with DatabaseLoggingMiddleware(logger, "Fetching chord extensions", request):
    cursor.execute(query, params)
    results = cursor.fetchall()
# Automatically logs query duration
```

### Frontend Logging (TypeScript/Angular)

**Framework: @microsoft/applicationinsights-web** (configured in `app/src/app/services/logging.service.ts`)

#### Correct Logging Pattern

```typescript
import { LoggingService } from '../services/logging.service';

export class MyComponent implements OnInit {
  constructor(private logger: LoggingService) {}

  ngOnInit() {
    // ✅ CORRECT: Use LoggingService with context
    this.logger.info('Component initialized', {
      component: 'ChordExtensionsComponent',
      operationId: this.logger.generateOperationId()
    });

    this.loadData();
  }

  loadData() {
    this.musicApi.getChordExtensions(1).subscribe({
      next: (data) => {
        this.logger.info('Chord extensions loaded', {
          component: 'ChordExtensionsComponent',
          count: data.length
        });
      },
      error: (error) => {
        this.logger.error('Failed to load chord extensions', error, {
          component: 'ChordExtensionsComponent',
          endpoint: '/chords/1/extensions'
        });
      }
    });
  }
}
```

#### Log Methods

```typescript
// INFO: General information
this.logger.info('User selected scale', {
  component: 'ScaleDisplay',
  scaleType: scaleTypeId,
  rootNote: rootNote
});

// WARNING: Non-critical issues
this.logger.warning('API call took longer than expected', {
  component: 'MusicService',
  duration: 5000,
  endpoint: '/scales'
});

// ERROR: Errors and exceptions
this.logger.error('API call failed', error, {
  component: 'MusicService',
  endpoint: '/chords',
  statusCode: error.status
});

// DEBUG: Detailed diagnostics
this.logger.debug('Rendering musical staff', {
  component: 'MusicalStaff',
  noteCount: notes.length
});
```

#### Automatic HTTP Logging

The `loggingInterceptor` automatically logs all HTTP requests/responses:
- ✅ Request initiated
- ✅ Response received with duration
- ✅ HTTP errors with status codes

```typescript
// Already configured in app.config.ts - NO CODE CHANGES NEEDED
export const appConfig: ApplicationConfig = {
  providers: [
    provideHttpClient(
      withInterceptors([
        loggingInterceptor,  // Logs all HTTP traffic
        authInterceptor
      ])
    )
  ]
};
```

#### Track Custom Events

```typescript
// Track user interactions
this.logger.trackEvent('UserSelectedChord', {
  chordType: 'Major7',
  rootNote: 'C',
  extensions: '9, 13'
});

// Track performance metrics
this.logger.trackMetric('ScaleRenderTime', renderDuration, {
  scaleType: 'Major',
  noteCount: 7
});
```

### Logging Anti-Patterns

❌ **DON'T** use `console.log()` directly in production code:
```typescript
// ❌ WRONG: Bypasses Application Insights
console.log('User clicked button');

// ✅ CORRECT: Uses logging service
this.logger.info('User clicked button', { component: 'MyComponent' });
```

❌ **DON'T** log without context:
```python
# ❌ WRONG: No operation_id, user_id, or request_path
logger.info("Processing request")

# ✅ CORRECT: Includes all required context
logger.info("Processing request", extra={
    'operation_id': operation_id,
    'user_id': 'anonymous',
    'request_path': '/chords'
})
```

❌ **DON'T** log sensitive data:
```python
# ❌ WRONG: Logs passwords, tokens, etc.
logger.info(f"User logged in: {username}/{password}")

# ✅ CORRECT: Log only non-sensitive info
logger.info("User logged in", extra={
    'user_id': user_id,
    'auth_method': 'Entra ID'
})
```

❌ **DON'T** catch exceptions without logging:
```python
# ❌ WRONG: Silent failures
try:
    process_data()
except Exception:
    pass  # Error is lost

# ✅ CORRECT: Log and re-raise or handle
try:
    process_data()
except Exception as e:
    logger.error(f"Processing failed: {e}", extra={...}, exc_info=True)
    raise HTTPException(status_code=500, detail=str(e))
```

### Querying Logs in Application Insights

**Azure Portal → Application Insights → Logs (KQL)**

```kusto
// Find all API errors in last 24 hours
traces
| where cloud_RoleName == "grooveapp-api"
| where severityLevel >= 3  // ERROR and above
| where timestamp > ago(24h)
| project timestamp, message, severityLevel, customDimensions
| order by timestamp desc

// Find slow API requests
requests
| where cloud_RoleName == "grooveapp-api"
| where duration > 1000  // > 1 second
| project timestamp, name, duration, resultCode
| order by duration desc

// Trace a specific operation
traces
| where customDimensions.operation_id == "abc-123-def-456"
| project timestamp, severityLevel, message
| order by timestamp asc

// Count errors by endpoint
exceptions
| where cloud_RoleName == "grooveapp-api"
| summarize count() by operation_Name
| order by count_ desc
```

### Log Level Configuration

**Local Development (`docker-compose.yml` or `.env`):**
```yaml
environment:
  - LOG_LEVEL=DEBUG
  - APPLICATIONINSIGHTS_CONNECTION_STRING=  # Empty for local
```

**Azure App Service (Terraform `main.tf`):**
```terraform
app_settings = {
  LOG_LEVEL = "INFO"  # Production
  APPLICATIONINSIGHTS_CONNECTION_STRING = module.log_analytics.app_insights_connection_string
}
```

### Monitoring Best Practices

1. **Use structured logging**: Always include context in `extra` parameter
2. **Set appropriate log levels**: DEBUG locally, INFO in production
3. **Log at entry/exit points**: Start/end of requests, operations
4. **Log state changes**: User actions, data mutations
5. **Log errors with context**: Include `exc_info=True` for stack traces
6. **Use correlation IDs**: Track requests across frontend → API → database
7. **Monitor performance**: Log duration for slow operations
8. **Alert on errors**: Configure alerts for ERROR logs in App Insights

### Required Logging for New Features

When adding new API endpoints or frontend features:

1. **API Endpoint**: Must log request start, completion, and any errors
2. **Frontend Component**: Must log initialization and key user actions
3. **Database Operations**: Must log query execution and errors
4. **Error Handling**: Must log all exceptions with full context
5. **Performance**: Must log duration for operations > 100ms

### Troubleshooting: No Data in App Insights

**Checklist:**
1. ✅ `APPLICATIONINSIGHTS_CONNECTION_STRING` environment variable set
2. ✅ Connection string format: `InstrumentationKey=...;IngestionEndpoint=...`
3. ✅ Network connectivity to `*.in.applicationinsights.azure.com`
4. ✅ Logs include required `extra` fields (`operation_id`, `user_id`, `request_path`)
5. ✅ Wait 2-5 minutes for data ingestion (not real-time)
6. ✅ Check Azure portal for ingestion errors
7. ✅ Verify `LOG_LEVEL` is not set to `OFF`

**Test Logging:**
```python
# API: Test log ingestion
logger.info("Test log entry", extra={
    'operation_id': 'test-123',
    'user_id': 'system',
    'request_path': '/test'
})
```

```typescript
// Frontend: Test log ingestion
this.logger.info('Test log entry', {
  component: 'TestComponent',
  operationId: 'test-123'
});
```