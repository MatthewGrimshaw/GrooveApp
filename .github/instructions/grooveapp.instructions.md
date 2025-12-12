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
└── infra/                        # Infrastructure as Code
    ├── build-appInfra.ps1        # Deploy to Azure
    ├── deploy-updates.ps1        # Update existing deployment
    ├── cleanup-appInfra.ps1      # Delete Azure resources
    └── setup-music-tables.sql    # Database schema & data
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
