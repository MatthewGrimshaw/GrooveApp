# GrooveApp Music Theory Application

Full-stack music theory application with REST API backend and Angular frontend. Generates scales, chords, and arpeggios with correct note spelling following music theory conventions. Features traditional musical staff visualization and comprehensive security.

## Overview

**Backend (FastAPI + Azure SQL)**
- REST API for music theory data (scales, chords, arpeggios, intervals)
- Key signature system for correct note spelling (Bb in F Major, not A#)
- Deployed on Azure App Service with Easy Auth and Managed Identity
- Automated vulnerability scanning with Docker Scout
- CORS configured for secure cross-origin requests from frontend

**Frontend (Angular 19)**
- Interactive scale and arpeggio explorer
- Traditional 5-line musical staff notation with treble clef
- Real-time note visualization with proper accidental symbols (♯ ♭)
- Responsive UI with purple theme
- Deployed on Azure App Service with Easy Auth (Entra ID)
- HTTP interceptor for authenticated cross-origin API requests

**Database (Azure SQL)**
- Music theory data: notes, intervals, scales, chords
- Key signature mappings (70+ scale/root combinations)
- Enhanced functions for correct note spelling based on Circle of Fifths

## Key Features

### Correct Note Spelling
The application follows music theory conventions for note spelling:
- **F Major**: F, G, A, **Bb**, C, D, E, F (not A#)
- **D Major**: D, E, **F#**, G, A, B, **C#**, D (not Gb or Db)
- **Each letter A-G appears exactly once** in every scale
- Follows the Circle of Fifths: sharp keys use sharps, flat keys use flats

This is implemented via a **Key Signature System**:
- `KeySignatures` table maps each scale/root to proper accidentals
- `fn_GenerateScale` matches notes by both semitone AND letter name
- Covers Major, Minor (Natural/Harmonic/Melodic), Modes, Pentatonic, Blues

### Musical Staff Visualization
Traditional music notation display:
- 5-line treble clef staff rendered in SVG
- Notes positioned at correct vertical positions
- Sharp (♯) and flat (♭) symbols displayed before notes
- Ledger lines for notes outside staff range
- Automatic octave change detection
- Works for both scales and arpeggios

### Jazz Chord Extensions
Interactive display of common jazz chord extensions:
- **Extension intervals** beyond basic triads and 7th chords
- **Common jazz voicings** including 9ths, 11ths, 13ths, and altered tones
- **Visual presentation** in grid format alongside arpeggio notes
- **Educational context** with descriptions for each extension
- Covers Major, Minor, Dominant, and altered chord extensions
- Helps musicians understand advanced harmony and voicing options

Extensions include:
- **Natural extensions**: 9, 11, 13
- **Altered tones**: b9, #9, #11, b13
- **Augmented intervals**: #5 for altered dominant chords

### Security Features
- **Easy Auth**: Entra ID authentication on both frontend and API with group-based access control
- **Managed Identity**: Azure SQL access without credentials
- **CORS Protection**: API only accepts requests from authorized origins
- **Credential Sharing**: HTTP interceptor enables secure cross-origin authentication
- **Vulnerability Scanning**: Docker Scout blocks HIGH/CRITICAL CVEs
- **Multi-stage Builds**: Minimal attack surface, non-root user

## Quick Start

### Deploy Complete Infrastructure (One Command)

```powershell
# Deploy everything to Azure
.\infra\build-appInfra.ps1
```

This automated script performs 25 steps:

**Backend Deployment (Steps 1-17):**
1. ✅ Authenticate to Azure
2. ✅ Create Resource Group
3. ✅ Create SQL Server with Entra ID admin
4. ✅ Create SQL Database
5. ✅ Populate database with music theory data
6. ✅ Create Azure Container Registry
7. ✅ Build and scan API Docker image locally
8. ✅ Push secure API image to ACR
9. ✅ Create App Service Plan (Linux B1)
10. ✅ Create Entra ID Security Group
11. ✅ Create API Web App
12. ✅ Enable Managed Identity for API
13. ✅ Configure API container settings and CORS
14. ✅ Configure API app settings (with FRONTEND_URL)
15. ✅ Configure Easy Auth for API (Entra ID)
16. ✅ Enable continuous deployment and health checks for API
17. ✅ Grant Managed Identity database access

**Frontend Deployment (Steps 18-25):**
18. ✅ Build and push Frontend Docker image to ACR
19. ✅ Create Frontend Web App
20. ✅ Enable Managed Identity for Frontend
21. ✅ Configure Frontend container settings
22. ✅ Configure Frontend app settings
23. ✅ Configure Easy Auth for Frontend (Entra ID)
24. ✅ Enable continuous deployment for Frontend
25. ✅ Configure Frontend-to-API authentication

**Access the deployed application:**
- **Frontend**: `https://webapp-grooveapp-frontend.azurewebsites.net`
- **API**: `https://webapp-grooveapp-api.azurewebsites.net`
- **API Docs**: `https://webapp-grooveapp-api.azurewebsites.net/docs`
- Sign in with your Entra ID credentials (must be in GrooveApp-Users group)

### Clean Up Environment

```powershell
# Remove all resources
.\infra\cleanup-appInfra.ps1
```

This cleanup script will delete:
- ✅ API App Registration and Service Principal
- ✅ Frontend App Registration and Service Principal
- ✅ Entra ID Security Group (GrooveApp-Users)
- ✅ Resource Group (SQL Server, Database, ACR, API Web App, Frontend Web App, all logs)

**Safety features:**
- Requires typing "DELETE" to confirm
- Clear list of resources to be deleted
- Background deletion for resource group (takes 5-10 minutes)

## Architecture

### Technology Stack

**Backend**
- Python 3.11 + FastAPI
- Azure SQL Database with pyodbc
- Docker with multi-stage builds
- Azure App Service (Linux B1)

**Frontend**
- Angular 19.2.16
- TypeScript 5.6
- Standalone components
- SVG-based music notation
- HTTP interceptor for authentication
- Nginx reverse proxy

**Infrastructure**
- Azure Container Registry (2 images: API + Frontend)
- Azure SQL Server (Entra ID only auth)
- Azure App Service Plan (Linux B1) - hosts both web apps
- Managed Identity for credential-less SQL auth
- Easy Auth (Entra ID) on both frontend and API
- CORS configuration for secure cross-origin requests
- Application Insights for monitoring

### Data Model

**Core Tables**
- `Notes`: 21 notes with enharmonic equivalents (C, C#/Db, D, etc.)
- `Intervals`: 13 interval types (Perfect 5th, Major 3rd, etc.)
- `ScaleTypes`: 13 scale types (Major, Minor variants, Modes, Pentatonic, Blues)
- `ChordTypes`: 28 chord types (Triads, 7ths, 9ths, 11ths, 13ths, Altered)

**Key Signature System**
- `KeySignatures`: 70+ mappings of root note + scale type → letter sequence + accidental preference
- `ChordKeySignatures`: 17 root note mappings for chord accidental preferences

**Functions**
- `fn_GenerateScale`: Returns scale notes with correct spelling using KeySignatures table
- `fn_GenerateArpeggio`: Returns arpeggio notes with correct spelling using ChordKeySignatures table
- `vw_NoteIntervals`: View of all note-to-note interval relationships

### Frontend Architecture

**Components**
- `AppComponent`: Main application with tabs for scales and arpeggios
- `MusicalStaffComponent`: Standalone SVG-based staff notation renderer

**Services & Interceptors**
- `MusicApiService`: HTTP client service for API communication
- `authInterceptor`: Adds `withCredentials: true` to API requests for cross-origin auth

**Authentication Flow**
1. User visits frontend → Easy Auth redirects to Entra ID login
2. User signs in → Easy Auth creates session with auth cookie
3. Frontend makes API call → HTTP interceptor adds `withCredentials: true`
4. API receives request with auth cookie → Easy Auth validates token
5. If valid & user in GrooveApp-Users group → API processes request
6. API returns data → Frontend displays it

**Data Flow**
1. User selects root note and scale/chord type
2. Frontend calls API endpoint (with auth credentials)
3. API validates authentication token via Easy Auth
4. API queries database function (fn_GenerateScale or fn_GenerateArpeggio)
5. Database returns correctly spelled notes using key signature logic
6. Frontend displays notes as text and on musical staff
7. Staff component calculates Y positions and renders SVG

## API Endpoints

### Notes
- `GET /notes` - Get all musical notes with properties (semitones, sharp/flat/natural flags)

### Intervals
- `GET /intervals` - Get all interval types with semitone counts
- `GET /intervals/{from_note}` - Get intervals from a specific note (e.g., `/intervals/C`)

### Scales
- `GET /scales` - Get all scale types
- `GET /scales/{root_note}/{scale_type_id}` - Generate a scale with correct note spelling
  - Example: `/scales/C/1` - C Major (C, D, E, F, G, A, B, C)
  - Example: `/scales/F/1` - F Major (F, G, A, **Bb**, C, D, E, F)
  - Example: `/scales/D/1` - D Major (D, E, **F#**, G, A, B, **C#**, D)
  - Example: `/scales/Eb/1` - Eb Major (Eb, F, G, Ab, Bb, C, D, Eb)

### Chords/Arpeggios
- `GET /chords` - Get all chord types
- `GET /arpeggios/{root_note}/{chord_type_id}` - Generate an arpeggio with correct spelling
  - Example: `/arpeggios/C/5` - C Major 7 (C, E, G, B)
  - Example: `/arpeggios/F/5` - F Major 7 (F, A, C, E) - uses Bb for extensions
  - Example: `/arpeggios/A/22` - A Dominant 13

### Chord Extensions (Jazz Harmony)
- `GET /chords/{chord_type_id}/extensions` - Get common jazz chord extensions for a chord type
  - Returns extension intervals used in jazz harmony (9th, 11th, 13th, altered tones)
  - Filtered to show only common jazz extensions (`IsCommonInJazz = 1`)
  - Ordered by display priority and semitones
  - Example: `/chords/1/extensions` - Major chord extensions (9, 11, 13)
  - Example: `/chords/3/extensions` - Dominant 7 extensions (9, b9, #9, #11, b13, 13, #5)
  - Example: `/chords/2/extensions` - Minor chord extensions (9, 11, b13)

**Extension Types:**
- **Major Chords**: Major 9, Major 11, Major 13
- **Minor Chords**: Minor 9, Minor 11, Minor b13
- **Dominant Chords**: Dominant 9, Dominant b9, Dominant #9, Dominant #11, Dominant b13, Dominant 13, Augmented 5th (for altered dominant)
- **Half Diminished**: Minor 7b5 with 9 and 11
- **Minor Major 7**: With Major 9
- **Dominant 9**: With 11 and 13

These extensions are essential for jazz voicings and improvisation, showing the additional intervals that can be added to basic chord structures.

### Health Check
- `GET /health` - Database connectivity check (unauthenticated)

## Authentication & CORS

### Easy Auth Configuration

**Frontend Web App**
- Entra ID authentication required for all pages
- Redirects unauthenticated users to login
- Creates session with auth cookie after successful login
- Same security group (GrooveApp-Users) controls access

**API Web App**
- Entra ID authentication required for all endpoints
- Returns 401 for unauthenticated requests (API-friendly)
- Excluded paths: `/health`, `/docs`, `/openapi.json`
- Validates tokens from authenticated requests

**Security Group Access Control**
- Both apps use same Entra ID group: `GrooveApp-Users`
- Only group members can access frontend and API
- Managed centrally in Entra ID

### CORS Configuration

**API CORS Settings (main.py)**
```python
allowed_origins = [
    "http://localhost:8080",  # Local development
    "http://localhost:4200",  # Angular dev server
    os.environ.get("FRONTEND_URL", "https://webapp-grooveapp-frontend.azurewebsites.net")
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,  # Required for auth cookies
    allow_methods=["*"],
    allow_headers=["*"],
)
```

**Azure CORS Settings**
- Configured via Azure CLI during deployment
- Allows: `https://webapp-grooveapp-frontend.azurewebsites.net`
- Allows: `http://localhost:8080` (for local testing)

### HTTP Interceptor (Angular)

**auth.interceptor.ts**
```typescript
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  if (req.url.startsWith(environment.apiUrl)) {
    const authReq = req.clone({
      withCredentials: true  // Include auth cookies
    });
    return next(authReq);
  }
  return next(req);
};
```

Registered in `app.config.ts`:
```typescript
provideHttpClient(withInterceptors([authInterceptor]))
```

### Authentication Flow

```
User → Frontend
  ↓ (Easy Auth)
Entra ID Login
  ↓
Frontend App (with session cookie)
  ↓ (HTTP request with withCredentials: true)
API (validates token via Easy Auth)
  ↓
Database
  ↓
Response → Frontend
```

## Key Signature System

### The Problem
Original logic: "if root is flat, prefer flats; otherwise prefer sharps"
- **Result**: F Major returned F, G, A, **A#**, C, D, E, F (incorrect!)
- **Issue**: Violated rule that each letter A-G appears exactly once

### The Solution
Key signature mappings based on Circle of Fifths:

**Sharp Keys** (use sharps): G, D, A, E, B, F#, C#  
**Flat Keys** (use flats): F, Bb, Eb, Ab, Db, Gb  
**Natural Key**: C

### Implementation

**KeySignatures Table**
```sql
CREATE TABLE dbo.KeySignatures (
    RootNote NVARCHAR(10),
    ScaleTypeId INT,
    PreferredAccidental NVARCHAR(10), -- 'sharp', 'flat', or 'natural'
    ScaleLetterSequence NVARCHAR(50), -- e.g., 'F,G,A,B,C,D,E' for F Major
    Description NVARCHAR(200)
);
```

**Enhanced fn_GenerateScale Function**
1. Looks up KeySignatures for root note + scale type
2. Extracts letter sequence (e.g., F,G,A,B,C,D,E)
3. For each degree:
   - Gets required letter from sequence
   - Calculates semitone from interval pattern
   - Finds note matching BOTH semitone AND letter
4. Returns correctly spelled scale

**Example: F Major**
- Degree 4 needs letter "B" at 5 semitones from F
- Finds **Bb** (not A#) because it matches both:
  - Letter requirement: B
  - Semitone requirement: 5 semitones from F
- Result: F, G, A, **Bb**, C, D, E, F ✓

### Coverage
- **Major scales**: 14 keys
- **Natural Minor**: 14 keys
- **Harmonic Minor**: 12 keys
- **Melodic Minor**: 6 keys
- **Modes**: 9 common modes (Dorian, Phrygian, Lydian, Mixolydian, Locrian)
- **Pentatonic**: 4 scales
- **Blues**: 2 scales
- **Total**: 70+ key signature definitions

### Database Setup
The complete database schema including key signatures is in `infra/setup-music-tables.sql`. To deploy:

```powershell
# Option 1: Via Azure Data Studio / SSMS
# Open setup-music-tables.sql and execute against your database

# Option 2: Via deployment script (uses Azure CLI token)
cd infra
python apply-key-signatures.py
```

This single file creates/updates:
- All tables (Notes, Intervals, ScaleTypes, KeySignatures, ChordKeySignatures, ChordTypes)
- All data (70+ key signatures, 17 chord key signatures)
- Enhanced functions (fn_GenerateScale, fn_GenerateArpeggio)
- Views (vw_NoteIntervals)

## Musical Staff Visualization

### Overview
Traditional 5-line musical staff with treble clef displays scales and arpeggios in standard music notation.

### Features

**Staff Rendering**
- 5 horizontal lines (standard treble clef staff)
- SVG-based for crisp rendering (800x200px)
- Unicode treble clef symbol (𝄞)
- Left-aligned to match other UI elements

**Note Display**
- Notes positioned at correct vertical positions based on pitch
- C4 (middle C) on first ledger line below staff
- Sharp (♯) and flat (♭) symbols before notes
- Ledger lines automatically generated for notes outside staff range
- Note stems extending from each note head

**Smart Octave Detection**
- Notes without octave numbers default to octave 4
- Detects octave changes in sequential notes
- When B is followed by C, octave increments automatically
- Ensures scales spanning octaves display correctly

**Integration**
- Appears in both Scales and Arpeggios tabs
- Updates automatically when user selects different scale/chord
- Displays notes passed from API in real-time

### Component Structure

**File**: `app/src/app/components/musical-staff.component.ts`

```typescript
@Component({
  selector: 'app-musical-staff',
  standalone: true,
  template: `<!-- SVG rendering -->`
})
export class MusicalStaffComponent {
  @Input() notes: string[] = [];
  
  // Note positioning algorithm
  calculateNotePositions() {
    // Maps note letters to Y coordinates on staff
    // Handles accidentals (♯ ♭)
    // Generates ledger lines
    // Detects octave changes
  }
}
```

### Note Positioning

**Staff Line Positions** (Y coordinates, centerY = 100):
- Line 5 (top): centerY - 20px = 80px (F5)
- Line 4: centerY - 10px = 90px (D5)
- Line 3 (middle): centerY = 100px (B4)
- Line 2: centerY + 10px = 110px (G4)
- Line 1 (bottom): centerY + 20px = 120px (E4)

**Note Mapping**:
- C4 (middle C): 150px (3 ledger lines below staff)
- E4: 140px (bottom staff line)
- G4: 130px (second staff line)
- B4: 120px (middle staff line)
- D5: 110px (second staff line from top)
- F5: 100px (top staff line)

Each half-step = 5px vertical spacing

### Example Displays

**C Major Scale**
- Input: `["C", "D", "E", "F", "G", "A", "B", "C"]`
- Display: 8 notes ascending from C4 to C5
- Last C automatically positioned in octave 5

**F Major Scale**
- Input: `["F", "G", "A", "Bb", "C", "D", "E", "F"]`
- Display: Notes with flat symbol (♭) before the B
- Demonstrates correct note spelling (Bb not A#)

**D Major Scale**
- Input: `["D", "E", "F#", "G", "A", "B", "C#", "D"]`
- Display: Sharp symbols (♯) before F and C
- Shows proper sharp key signature

### Frontend Development

```powershell
cd app

# Build and run locally
.\test-local-app.ps1 -Rebuild

# View at http://localhost:8080
```

## Security Architecture

### Authentication & Authorization

**Easy Auth (Azure App Service)**
- Entra ID authentication required for all endpoints (except `/health`)
- Group-based access control via `GrooveApp-Users` security group
- Automatic redirect to Microsoft login
- Session management with token store

**Database Access**
- Managed Identity for SQL Server authentication
- No connection strings or passwords
- Azure-managed credential rotation
- Read-only access (db_datareader role)

### Authentication Flow

| Environment | User Auth | Database Auth | Security Level |
|-------------|-----------|---------------|----------------|
| **Azure Production** | Easy Auth (Entra ID) | Managed Identity | ⭐⭐⭐⭐⭐ |
| **Local Docker** | None | Access Token | ⭐⭐⭐⭐ |
| **Local Python** | None | Azure CLI | ⭐⭐⭐⭐ |

### Local Development Security

**Token-based Authentication (Docker):**
```powershell
# Automated script handles tokens securely
.\api\test-local-api.ps1 -Rebuild
```

**How it works:**
1. ✅ Script requests token from your Azure CLI session
2. ✅ Token passed to container as environment variable (runtime only)
3. ✅ Token stored in memory only (not in image or on disk)
4. ✅ Automatic expiry after ~1 hour
5. ✅ No credential files mounted

**Security features:**
- Tokens never baked into Docker images
- Short-lived tokens limit exposure
- No .azure directory mounting required
- Works across Windows, Linux, macOS

### Vulnerability Management

**Automated Security Scanning:**
- Every Docker build scanned with Docker Scout
- Blocks deployments with HIGH or CRITICAL vulnerabilities
- Configurable severity thresholds
- Detailed CVE reports and fix recommendations

**Current Security Status:**
- ✅ **0 Critical vulnerabilities**
- ✅ **0 High vulnerabilities**
- ⚠️ **1 Medium vulnerability** (system library, no fix available)
- ℹ️ **33 Low vulnerabilities** (non-exploitable in container context)

**Security scanning commands:**
```powershell
# Default: Block HIGH and CRITICAL
.\api\test-local-api.ps1 -Rebuild

# Only block CRITICAL
.\api\test-local-api.ps1 -Rebuild -MaxSeverity critical

# View detailed CVE report
docker scout cves grooveapp-api

# Get fix recommendations
docker scout recommendations grooveapp-api
```

### Docker Security Features

**Multi-stage Build:**
- Build dependencies separated from runtime
- Smaller attack surface
- Only essential packages in final image

**Runtime Security:**
- Non-root user (`appuser`, UID 1000)
- Minimal base image (Python 3.11-slim)
- No Azure CLI in production container
- Health check endpoint for monitoring

## Local Development

### Prerequisites
- Python 3.11+
- Node.js 20+
- Docker Desktop
- Azure CLI
- SQL Server ODBC Driver 18 (for non-Docker Python development)

### Full Stack Development (Recommended)

**Step 1: Start API (Backend)**
```powershell
cd api

# Login to Azure
az login

# Build, scan, and run API locally
.\test-local-api.ps1 -Rebuild

# API runs on http://localhost:8000
```

**Step 2: Start Frontend**
```powershell
cd app

# Build and run frontend with Docker
.\test-local-app.ps1 -Rebuild

# Frontend runs on http://localhost:8080
# Connects to API at http://localhost:8000
```

**Access the application:**
- Frontend: http://localhost:8080
- API Docs: http://localhost:8000/docs
- API Health: http://localhost:8000/health

### API Docker Development

```powershell
cd api

# Build, scan, and run API locally
.\test-local-api.ps1 -Rebuild

# View logs
.\test-local-api.ps1 -Logs

# Stop container
.\test-local-api.ps1 -Stop
```

Visit http://localhost:8000/docs for interactive API documentation.

**Script features:**
1. ✅ Builds Docker image with multi-stage optimization
2. ✅ Scans for security vulnerabilities
3. ✅ Gets fresh Azure access token
4. ✅ Passes token as environment variable (secure)
5. ✅ Starts container on port 8000
6. ✅ Tests API health

### Python Development (Without Docker)

```powershell
cd api

# Create virtual environment
python -m venv venv
.\venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Set environment variables
$env:SQL_SERVER="sql-grooveapp.database.windows.net"
$env:SQL_DATABASE="db-grooveapp"

# Login to Azure
az login

# Run the API
python main.py
```

### Frontend Docker Development

```powershell
cd app

# Build and run frontend with Docker
.\test-local-app.ps1 -Rebuild

# View logs
.\test-local-app.ps1 -Logs

# Stop container
.\test-local-app.ps1 -Stop
```

**Script features:**
1. ✅ Builds Docker image with multi-stage optimization (Node + Nginx)
2. ✅ Scans for npm vulnerabilities (optional with -SkipScan)
3. ✅ Builds Angular app with development configuration (localhost API)
4. ✅ Serves with Nginx on port 8080
5. ✅ Tests health endpoint

**Note:** Frontend connects to `http://localhost:8000` in development mode. Make sure the API is running first.

### Frontend Angular Development (Without Docker)

```powershell
cd app

# Install dependencies
npm install

# Run development server
npm start

# Frontend runs on http://localhost:4200
# Connects to API at http://localhost:8000
```

### Token Refresh

Tokens expire after ~1 hour. To refresh:
```powershell
# Stop API container
.\api\test-local-api.ps1 -Stop

# Restart with new token
.\api\test-local-api.ps1 -NoBuild
```

## Testing

### Comprehensive API Testing (133 Tests)
```powershell
cd api

# Test all endpoints locally
.\test_deployment.ps1

# Test deployed API
.\test_deployment.ps1 -ApiUrl "https://webapp-grooveapp-api.azurewebsites.net"
```

**Test Coverage:**
- ✅ Health checks (2 tests)
- ✅ Notes endpoint (3 tests)
- ✅ Intervals endpoint (3 tests)
- ✅ Scales: All 14 scale types across Circle of Fifths (60 tests)
  - Major scales (12 keys), Minor scales (3 types), Modes (5 types)
  - Pentatonic (2 types), Blues (6-note scale), Altered
- ✅ Chords: All 28 chord types (51 tests)
  - Triads, 7th chords, 6th chords, 9th chords, 11th chords, 13th chords
  - Suspended chords, Altered extensions
- ✅ Error handling (4 tests)
- ✅ Edge cases: Enharmonic equivalents, fallback logic (10 tests)

**Key Tests:**
- Verifies F Major returns Bb (not A#)
- Verifies C Pentatonic Minor returns Eb and Bb
- Verifies Blues scale returns 6 notes including blue notes
- Tests all chord extensions (9th, 11th, 13th)

### Local Testing (Both Apps)
```powershell
# Terminal 1: Start API
cd api
.\test-local-api.ps1 -Rebuild

# Terminal 2: Start Frontend
cd app
.\test-local-app.ps1 -Rebuild

# Terminal 3: Run tests
cd api
.\test_deployment.ps1
```

### Example Requests

```bash
# Get all notes
curl http://localhost:8000/notes

# Generate C Major scale (natural notes)
curl http://localhost:8000/scales/C/1
# Returns: C, D, E, F, G, A, B, C

# Generate F Major scale (demonstrates Bb not A#)
curl http://localhost:8000/scales/F/1
# Returns: F, G, A, Bb, C, D, E, F

# Generate D Major scale (demonstrates F# and C#)
curl http://localhost:8000/scales/D/1
# Returns: D, E, F#, G, A, B, C#, D

# Generate F Major 7 arpeggio
curl http://localhost:8000/arpeggios/F/5
# Returns: F, A, C, E (uses Bb for extensions)

# Get intervals from C
curl http://localhost:8000/intervals/C

# Health check (unauthenticated endpoint)
curl http://localhost:8000/health
```

## Azure Deployment

### Automated Deployment

```powershell
# Deploy complete infrastructure
.\infra\build-appInfra.ps1
```

**What gets created:**
- Resource Group: `rg-grooveapp`
- SQL Server: `sql-grooveapp` (Entra ID only auth)
- Database: `db-grooveapp` (populated with music theory data including key signatures)
- Container Registry: `acrgrooveapp`
- App Service Plan: `plan-grooveapp` (Linux B1)
- Web App: `webapp-grooveapp-api`
- App Registration: `webapp-grooveapp-api-auth`
- Security Group: `GrooveApp-Users`

**Database includes:**
- Core music theory tables (Notes, Intervals, ScaleTypes, ChordTypes)
- Key signature system (KeySignatures with 70+ entries, ChordKeySignatures with 17 entries)
- Enhanced functions (fn_GenerateScale, fn_GenerateArpeggio with correct note spelling)
- All data populated automatically from `infra/setup-music-tables.sql`

**Security features configured:**
- Easy Auth with Entra ID
- Managed Identity for SQL access
- Health check endpoint excluded from auth
- Group-based access control
- Docker image vulnerability scanning
- Database firewall rules

### Manual Deployment (Advanced)

If you need to deploy components individually:

```powershell
# Set variables
$resourceGroup = "rg-grooveapp"
$location = "swedencentral"
$sqlServer = "sql-grooveapp"
$database = "db-grooveapp"
$acrName = "acrgrooveapp"
$webAppName = "webapp-grooveapp-api"

# Create infrastructure
az group create --name $resourceGroup --location $location

az sql server create `
    --name $sqlServer `
    --resource-group $resourceGroup `
    --location $location `
    --enable-ad-only-auth

az sql db create `
    --resource-group $resourceGroup `
    --server $sqlServer `
    --name $database `
    --service-objective S0

# Create and configure container
az acr create `
    --resource-group $resourceGroup `
    --name $acrName `
    --sku Basic `
    --location $location

# Build and push (with security scan)
cd api
.\test-local-api.ps1 -Rebuild
az acr build --registry $acrName --image grooveapp-api:latest --file Dockerfile .

# Create App Service
az appservice plan create `
    --name plan-grooveapp `
    --resource-group $resourceGroup `
    --is-linux `
    --sku B1 `
    --location $location

az webapp create `
    --resource-group $resourceGroup `
    --plan plan-grooveapp `
    --name $webAppName `
    --deployment-container-image-name $acrName.azurecr.io/grooveapp-api:latest

# Enable managed identity
az webapp identity assign `
    --name $webAppName `
    --resource-group $resourceGroup

# Configure app settings
az webapp config appsettings set `
    --name $webAppName `
    --resource-group $resourceGroup `
    --settings SQL_SERVER=$sqlServer.database.windows.net SQL_DATABASE=$database WEBSITES_PORT=8000

# Grant database permissions (run in Azure Data Studio)
# CREATE USER [webapp-grooveapp-api] FROM EXTERNAL PROVIDER;
# ALTER ROLE db_datareader ADD MEMBER [webapp-grooveapp-api];
```

### Adding Users to the App

Only members of the `GrooveApp-Users` security group can access the API.

```powershell
# Get group ID
$groupId = az ad group show --group "GrooveApp-Users" --query "id" -o tsv

# Add user by email
$userId = az ad user show --id "user@example.com" --query "id" -o tsv
az ad group member add --group $groupId --member-id $userId

# Add user by UPN
az ad group member add --group $groupId --member-id "user@example.com"
```

## Monitoring & Troubleshooting

### View Logs

```powershell
# Stream live logs
az webapp log tail --name webapp-grooveapp-api --resource-group rg-grooveapp

# Download logs
az webapp log download --name webapp-grooveapp-api --resource-group rg-grooveapp --log-file "logs.zip"
```

### Common Issues

#### Local Docker: Token Expired
**Symptom:** Database connection fails after ~1 hour

**Solution:**
```powershell
.\api\test-local-api.ps1 -Stop
.\api\test-local-api.ps1 -NoBuild
```

#### Azure: 401 Unauthorized After Sign-in
**Symptom:** User redirected to Microsoft login but gets 401 after authentication

**Solution:** User not in security group
```powershell
# Check group membership
az ad group member check --group "GrooveApp-Users" --member-id <user-object-id>

# Add user to group
az ad group member add --group <group-id> --member-id <user-object-id>
```

#### Azure: Database Connection Failed
**Symptom:** Health check returns 503 or database errors

**Solution:** Check managed identity permissions
```sql
-- Connect to database and verify user exists
SELECT name, type_desc FROM sys.database_principals WHERE name = 'webapp-grooveapp-api';

-- If not found, create user and grant permissions
CREATE USER [webapp-grooveapp-api] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [webapp-grooveapp-api];
```

#### Azure: Admin Consent Required
**Symptom:** Error `AADSTS650056: Misconfigured application`

**Solution:** Grant admin consent (requires Global Administrator)
```powershell
az ad app permission admin-consent --id <app-id>
```

Or visit the consent URL:
```
https://login.microsoftonline.com/{tenant-id}/adminconsent?client_id={app-id}
```

#### Security Scan Failed
**Symptom:** Docker build fails with HIGH/CRITICAL vulnerabilities

**Solution:** Update dependencies
```powershell
cd api

# Check for outdated packages
pip list --outdated

# Update requirements
pip install --upgrade <package>
pip freeze > requirements.txt

# Rebuild
.\test-local-api.ps1 -Rebuild
```

## Project Structure

```
grooveapp/
├── api/
│   ├── main.py                  # FastAPI application
│   ├── Dockerfile               # Multi-stage build with security hardening
│   ├── requirements.txt         # Python dependencies
│   ├── test-local-api.ps1      # Local Docker workflow (build, scan, test)
│   └── test_deployment.ps1      # Deployment validation tests
├── infra/
│   ├── build-appInfra.ps1      # Complete Azure deployment (17 steps)
│   ├── cleanup-appInfra.ps1    # Remove all resources
│   └── setup-music-tables.sql  # Database schema and data
└── README.md                    # This file
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Azure App Service                    │
│  ┌──────────────────────────────────────────────────┐  │
│  │               Easy Auth (Entra ID)                │  │
│  │  • User authentication                            │  │
│  │  • Group-based authorization                      │  │
│  │  • Token management                               │  │
│  └──────────────────────────────────────────────────┘  │
│                           │                             │
│  ┌──────────────────────────────────────────────────┐  │
│  │          FastAPI Application Container           │  │
│  │  • Non-root user (appuser)                        │  │
│  │  • Health checks                                  │  │
│  │  • Managed Identity client                        │  │
│  └──────────────────────────────────────────────────┘  │
│                           │                             │
│  ┌──────────────────────────────────────────────────┐  │
│  │            System Managed Identity               │  │
│  │  • No credentials stored                          │  │
│  │  • Azure-managed rotation                         │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                            │
                            │ (Token-based auth)
                            ▼
            ┌──────────────────────────────┐
            │     Azure SQL Database       │
            │  • Entra ID only auth        │
            │  • Managed Identity access   │
            │  • db_datareader role        │
            └──────────────────────────────┘
```

## Security Best Practices Summary

| Scenario | Method | Security Level | Notes |
|----------|--------|----------------|-------|
| **Azure Production** | Easy Auth + Managed Identity | ⭐⭐⭐⭐⭐ | Zero credentials, Azure-managed |
| **Local Docker** | Access token via env var | ⭐⭐⭐⭐ | Short-lived, memory-only |
| **Local Python** | Azure CLI credentials | ⭐⭐⭐⭐ | Uses local login |
| **CI/CD** | Service Principal | ⭐⭐⭐⭐ | For automation only |
| ❌ **Mounting .azure dir** | Not recommended | ⭐⭐ | Security risk |

## API Documentation

Once deployed, access interactive documentation:
- **Swagger UI**: `https://webapp-grooveapp-api.azurewebsites.net/docs`
- **ReDoc**: `https://webapp-grooveapp-api.azurewebsites.net/redoc`

Local development:
- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`

## Frontend Application

An Angular-based web UI for interacting with the Music Theory API is available in the `app/` folder.

### Frontend Features
- 🎹 Interactive scales generator
- 🎸 Arpeggios builder
- 📏 Intervals calculator
- 🎨 Modern, responsive UI
- 🔒 Dockerized with nginx

### Quick Start

**Run Frontend Locally:**
```powershell
cd app
.\test-local-app.ps1 -Rebuild
```

**Run Both API and Frontend:**
```powershell
# Terminal 1 - Start API
cd api
.\test-local-api.ps1 -Rebuild

# Terminal 2 - Start Frontend
cd app
.\test-local-app.ps1 -Rebuild
```

Visit:
- Frontend: http://localhost:8080
- API: http://localhost:8000
- API Docs: http://localhost:8000/docs

**Deploy Frontend to Azure:**
```powershell
cd app

# Build and push to ACR
az acr build --registry acrgrooveapp --image grooveapp-ui:latest --file Dockerfile .

# Create web app
az webapp create `
    --resource-group rg-grooveapp `
    --plan plan-grooveapp `
    --name webapp-grooveapp-ui `
    --deployment-container-image-name acrgrooveapp.azurecr.io/grooveapp-ui:latest

# Configure
az webapp config appsettings set `
    --name webapp-grooveapp-ui `
    --resource-group rg-grooveapp `
    --settings WEBSITES_PORT=8080
```

See `app/README.md` for detailed frontend documentation.

## Project Structure

```
grooveapp/
├── api/                             # FastAPI Backend
│   ├── main.py                      # API application
│   ├── Dockerfile                   # Multi-stage build
│   ├── requirements.txt             # Python dependencies
│   ├── test-local-api.ps1          # Local API testing
│   └── test_deployment.ps1          # API validation
├── app/                             # Angular Frontend
│   ├── src/
│   │   ├── app/
│   │   │   ├── components/
│   │   │   │   └── musical-staff.component.ts  # Staff notation
│   │   │   ├── models/              # TypeScript interfaces
│   │   │   ├── services/            # API client
│   │   │   └── app.component.*      # Main component with tabs
│   │   └── environments/            # Environment configs
│   ├── Dockerfile                   # Multi-stage nginx build
│   ├── nginx.conf                   # nginx configuration
│   └── test-local-app.ps1          # Local UI testing
├── infra/
│   ├── build-appInfra.ps1          # Complete deployment (17 steps)
│   ├── cleanup-appInfra.ps1        # Resource cleanup
│   ├── setup-music-tables.sql      # Complete database schema
│   │                                # (includes key signatures)
│   └── CONSOLIDATION_COMPLETE.md   # SQL consolidation notes
└── README.md                        # This file (consolidated docs)
```

## Key Files

**Backend**
- `api/main.py`: FastAPI application with CORS, health checks, music theory endpoints
- `api/Dockerfile`: Multi-stage build with security scanning
- `infra/setup-music-tables.sql`: Complete database setup (tables, data, functions)

**Frontend**
- `app/src/app/components/musical-staff.component.ts`: SVG staff notation (252 lines)
- `app/src/app/app.component.ts`: Main UI with scales/arpeggios tabs
- `app/Dockerfile`: Nginx-based static site hosting

**Infrastructure**
- `infra/build-appInfra.ps1`: Automated Azure deployment (SQL, ACR, App Service, Easy Auth)
- `infra/cleanup-appInfra.ps1`: Complete resource removal with safety checks

## Recent Updates

### Key Signature System (December 2025)
**Problem Fixed**: Scales returned incorrect note spelling (e.g., F Major showed A# instead of Bb)

**Solution Implemented**:
- Created `KeySignatures` table with 70+ scale/root mappings
- Created `ChordKeySignatures` table with 17 chord root mappings
- Enhanced `fn_GenerateScale` to match notes by semitone AND letter name
- Enhanced `fn_GenerateArpeggio` to use chord-specific accidental preferences
- Consolidated all SQL into single `setup-music-tables.sql` file

**Result**: All scales now follow music theory conventions (Circle of Fifths)
- F Major: F, G, A, **Bb**, C, D, E, F ✓
- D Major: D, E, **F#**, G, A, B, **C#**, D ✓
- Each letter A-G appears exactly once per scale ✓

### Musical Staff Visualization (December 2025)
**Feature Added**: Traditional 5-line musical staff with treble clef

**Implementation**:
- Created `MusicalStaffComponent` (252 lines, SVG-based)
- Integrated into Scales and Arpeggios tabs
- Features: note positioning, accidentals (♯ ♭), ledger lines, octave detection
- Left-aligned to match UI layout

**Result**: Users see scales and arpeggios in standard music notation

## Resources

- **Azure App Service**: https://docs.microsoft.com/azure/app-service/
- **Managed Identity**: https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/
- **Easy Auth**: https://docs.microsoft.com/azure/app-service/overview-authentication-authorization
- **Docker Scout**: https://docs.docker.com/scout/
- **FastAPI**: https://fastapi.tiangolo.com/
- **Angular**: https://angular.io/docs
- **Music Theory - Circle of Fifths**: https://en.wikipedia.org/wiki/Circle_of_fifths

## License

This is a demonstration project for learning purposes.
