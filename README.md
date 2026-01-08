# GrooveApp - Music Theory Application

A full-stack web application for music theory education and exploration, featuring correct note spelling, traditional musical staff notation, and comprehensive chord/scale analysis.

## 🎵 Overview

**GrooveApp** is a cloud-native music theory application built with modern web technologies and deployed on Microsoft Azure. The application provides interactive tools for exploring scales, chords, arpeggios, and key signatures with mathematically correct note spelling based on music theory conventions.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Azure Cloud                          │
│                                                             │
│  ┌──────────────────┐         ┌──────────────────┐        │
│  │  Frontend        │         │  Backend API     │        │
│  │  (Angular 19)    │◄───────►│  (FastAPI)       │        │
│  │  App Service     │  CORS   │  App Service     │        │
│  │  + Easy Auth     │         │  + Easy Auth     │        │
│  └────────┬─────────┘         └────────┬─────────┘        │
│           │                             │                   │
│           │                             │                   │
│           │                    ┌────────▼─────────┐        │
│           │                    │  Azure SQL       │        │
│           │                    │  Database        │        │
│           │                    │  + Music Theory  │        │
│           │                    │    Data          │        │
│           │                    └──────────────────┘        │
│           │                                                 │
│  ┌────────▼──────────────────────────────────────┐        │
│  │  Azure Container Registry (ACR)               │        │
│  │  - grooveapp-frontend:latest                  │        │
│  │  - grooveapp-api:latest                       │        │
│  └───────────────────────────────────────────────┘        │
│                                                             │
│  ┌───────────────────────────────────────────────┐        │
│  │  Entra ID (Azure AD)                          │        │
│  │  - API App Registration                       │        │
│  │  - Frontend App Registration                  │        │
│  │  - Security Groups                            │        │
│  └───────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

### Tech Stack

| Component | Technology | Description |
|-----------|-----------|-------------|
| **Frontend** | Angular 19 | Standalone components, reactive forms, HTTP interceptors |
| **Backend** | FastAPI (Python 3.11) | Async REST API with Pydantic validation |
| **Database** | Azure SQL Database | Music theory data, stored procedures, key signatures |
| **Authentication** | Entra ID + Easy Auth | Enterprise SSO, group-based access control |
| **Hosting** | Azure App Service | Linux containers, auto-scaling, deployment slots |
| **Container Registry** | Azure Container Registry | Private Docker images, vulnerability scanning |
| **Infrastructure** | Terraform + PowerShell | Infrastructure as Code, automated deployments |
| **Monitoring** | Application Insights | Distributed tracing, custom metrics, alerts |

## ✨ Key Features

### 🎼 Correct Note Spelling
- **Music Theory Rules**: Each scale uses proper accidentals based on the Circle of Fifths
- **Letter Uniqueness**: Every note letter (A-G) appears exactly once per scale
- **Key Signature System**: 70+ scale/root combinations with correct spellings
  - F Major: F, G, A, **Bb**, C, D, E (not A#)
  - D Major: D, E, **F#**, G, A, B, **C#** (not Gb, Db)
- **Enharmonic Intelligence**: Database functions match notes by both semitone AND letter name

### 🎹 Musical Staff Visualization
- **Traditional Notation**: 5-line treble clef staff rendered in SVG
- **Accurate Positioning**: Notes placed at correct vertical positions
- **Accidental Symbols**: Sharp (♯) and flat (♭) displayed before notes
- **Ledger Lines**: Automatic extension for notes outside staff range
- **Octave Detection**: Handles octave changes during scale rendering

### 🎺 Jazz Chord Extensions
- **Extension Intervals**: 9ths, 11ths, 13ths beyond basic triads
- **Altered Tones**: ♭9, ♯9, ♯11, ♭13 for dominant chords
- **Visual Display**: Interactive grid with extension descriptions
- **Educational Context**: Helps musicians understand advanced harmony

### 🔒 Enterprise Security
- **Easy Auth**: Entra ID (Azure AD) authentication on both frontend and API
- **CORS Protection**: API configured to accept requests only from authorized frontend origin with credentials support
- **Managed Identity**: Database access without hardcoded credentials
- **Vulnerability Scanning**: Docker Scout blocks HIGH/CRITICAL CVEs before deployment
- **Multi-stage Builds**: Minimal container attack surface

### ☁️ Cloud-Native Architecture
- **Blue-Green Deployment**: Zero-downtime updates via staging slots
- **Auto-scaling**: App Service Plan scales based on CPU/memory
- **Health Checks**: Automated probing of /health endpoint
- **Distributed Logging**: Centralized logs in Application Insights
- **Continuous Monitoring**: Azure Monitor alerts for performance issues

## 🚀 Quick Start

### Prerequisites
- Azure Subscription
- Azure CLI installed and authenticated
- Docker Desktop (for local development)
- PowerShell 7+ or PowerShell Core

### Deploy to Azure (One Command)

```powershell
# Deploy complete infrastructure
cd infra
.\build-appInfra.ps1
```

This automated script performs 25 steps including:
- ✅ Resource group creation
- ✅ Azure SQL Server + Database
- ✅ Music theory data population
- ✅ Container registry setup
- ✅ Docker image builds (API + Frontend)
- ✅ App Service deployment
- ✅ Entra ID app registrations
- ✅ Easy Auth configuration
- ✅ CORS and networking setup

**Deployment time**: ~15-20 minutes

### Access the Application

After deployment:
- **Frontend**: `https://app-grooveapp-dev-frontend.azurewebsites.net`
- **API**: `https://app-grooveapp-dev-api.azurewebsites.net`
- **API Docs**: `https://app-grooveapp-dev-api.azurewebsites.net/docs`

### Local Development

#### Backend API
```powershell
cd api
.\build-localApi.ps1 -Rebuild
```
Access at: `http://localhost:8000`

#### Frontend
```powershell
cd app
npm install
npm start
```
Access at: `http://localhost:4200`

## 📖 Documentation

### Getting Started
- **[Local Development](docs/LOCAL_DEVELOPMENT.md)** - Set up local development environment with Docker or native tools
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Comprehensive deployment instructions for Azure
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

### Infrastructure & DevOps
- [Terraform Guide](docs/TERRAFORM_README.md) - Infrastructure as Code with Terraform
- [Authentication Setup](docs/AUTHENTICATION.md) - Entra ID and Easy Auth configuration
- [CORS Configuration](docs/CORS_CONFIGURATION.md) - Cross-origin request setup and troubleshooting
- [Private Endpoints](docs/PRIVATE_ENDPOINTS.md) - Network security and private connectivity
- [Monitoring & Alerts](docs/MONITORING_IMPLEMENTATION_GUIDE.md) - Azure Monitor baseline alerts
- [Monitoring Alerts Summary](docs/MONITORING_ALERTS_SUMMARY.md) - Alert rules and thresholds

### Development Guides
- [Environment Configuration](docs/ENVIRONMENT_CONFIG.md) - Dev/staging/prod environment setup
- [Database Access](docs/DATABASE_ACCESS_FIX.md) - Managed Identity and authentication troubleshooting
- [Logging Guide](docs/LOGGING_QUICK_REFERENCE.md) - Application Insights logging (backend & frontend)
- [API Logging](docs/API_LOGGING.md) - Backend logging configuration
- [Frontend Logging](docs/FRONTEND_LOGGING.md) - Angular logging implementation
- [Terraform Logging](docs/TERRAFORM_LOGGING.md) - Infrastructure deployment logging

### Features & Architecture
- [Musical Staff Feature](docs/MUSICAL_STAFF_FEATURE.md) - Staff notation visualization
- [Key Signature System](docs/KEY_SIGNATURE_SYSTEM.md) - Note spelling algorithm
- [Musical Staff Implementation](docs/IMPLEMENTATION_SUMMARY_MUSICAL_STAFF.md) - Technical implementation details

### Project Management
- [TODO List](docs/TODO.md) - Feature roadmap and development backlog

## 🛠️ Technology Details

### Backend (FastAPI)
- **Framework**: FastAPI 0.104+ with async/await
- **Database**: PyODBC with ODBC Driver 18 for SQL Server
- **Authentication**: Azure AD token validation via Easy Auth headers
- **Logging**: Structured JSON logs to Application Insights
- **Health Checks**: `/health` endpoint with database connectivity test
- **API Documentation**: Auto-generated OpenAPI/Swagger docs

**Key Endpoints**:
- `GET /scales/{note}/{scaleTypeId}` - Get scale with correct note spelling
- `GET /chords/{note}/{chordTypeId}` - Get chord intervals and notes
- `GET /arpeggios/{note}/{arpeggioTypeId}` - Get arpeggio sequence
- `GET /health` - Health check with database status

### Frontend (Angular)
- **Framework**: Angular 19 with standalone components
- **Routing**: Angular Router with lazy loading
- **HTTP**: HttpClient with interceptors for auth and logging
- **State Management**: RxJS observables and signals
- **Styling**: CSS with CSS Grid and Flexbox
- **Runtime Config**: Environment variables injected via Docker entrypoint at container startup

**Key Components**:
- `MusicalStaffComponent` - SVG-based staff notation renderer
- `AppComponent` - Main app shell with health monitoring
- `AuthInterceptor` - Adds credentials to cross-origin API requests
- `LoggingInterceptor` - Centralized request/response logging
- `ConfigService` - Runtime configuration from window.runtimeConfig

### Database (Azure SQL)
- **Tables**: Notes, Intervals, Scales, Chords, KeySignatures
- **Functions**: `fn_GenerateScale`, `fn_GenerateChord`, `fn_GenerateArpeggio`
- **Key Signature Logic**: Circle of Fifths-based accidental selection
- **Indexes**: Optimized for scale/chord lookups
- **Security**: Managed Identity authentication, no connection strings

## 🔐 Security Features

- **Authentication**: Entra ID with Easy Auth (no custom auth code)
- **Authorization**: Group-based access control
- **Network**: CORS configured for frontend-only access with credentials support
- **Credentials**: Managed Identity for database (no secrets)
- **Container Security**: Docker Scout scanning, non-root user
- **HTTPS Only**: TLS 1.2+ enforced on all endpoints
- **Token Validation**: API validates Entra ID tokens from Easy Auth
- **Unauthenticated Action**: API returns 401 (not redirect) to support CORS preflight

## 📊 Monitoring & Observability

- **Application Insights**: Distributed tracing, custom metrics, operation correlation
- **Log Analytics**: Centralized log aggregation and querying
- **Azure Monitor Alerts**: CPU, memory, response time, HTTP errors, database connectivity
- **Health Probes**: App Service startup and liveness checks
- **Custom Metrics**: Render time, API latency, operation tracking

## 🧪 Testing & Quality

- **API Tests**: Pytest with async test clients
- **Frontend Tests**: Karma + Jasmine unit tests
- **Security Scanning**: Docker Scout CVE detection (blocks HIGH/CRITICAL)
- **Code Quality**: ESLint, Pylint, TypeScript strict mode
- **Health Checks**: Automated endpoint monitoring

## 🌍 Deployment Environments

| Environment | Purpose | URL Pattern | Database |
|------------|---------|-------------|----------|
| **Development** | Local dev + Azure dev | `*-dev-*.azurewebsites.net` | `db-grooveapp-dev` |
| **Staging** | Pre-production testing | `*-staging-*.azurewebsites.net` | `db-grooveapp-staging` |
| **Production** | Live application | `*-prod-*.azurewebsites.net` | `db-grooveapp-prod` |

Each environment has:
- Separate App Service instances with deployment slots
- Isolated databases
- Environment-specific configuration via app settings
- Blue-green deployment capability

## 🔄 Recent Updates

### Runtime Configuration (January 2026)
- Implemented runtime environment variable injection via Docker entrypoint
- `window.runtimeConfig` provides API URL and configuration to Angular at startup
- Solves issue where Easy Auth protects static assets (config.json)
- ConfigService loads configuration before app initialization

### CORS & Authentication (January 2026)
- Configured API CORS to allow frontend origin with credentials
- Changed API unauthenticated action from redirect to Return401
- Fixes "Redirect is not allowed for a preflight request" error
- Auth interceptor adds `withCredentials: true` for cross-origin requests

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- Music theory validation based on Circle of Fifths principles
- Azure architecture following Microsoft Well-Architected Framework
- Security practices aligned with OWASP guidelines

---

**Built with ❤️ for musicians and music theory enthusiasts**
