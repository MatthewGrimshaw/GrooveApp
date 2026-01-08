# Local Development Guide

## Overview

This guide covers setting up and running the GrooveApp locally for development.

## Prerequisites

### Required Software
- **Docker Desktop** (for containerized development)
- **PowerShell 7+** (for running build scripts)
- **Git** (for version control)
- **Visual Studio Code** (recommended IDE)
- **Azure CLI** (for Azure resource access)

### Optional Tools
- **Python 3.11+** (for non-Docker API development)
- **Node.js 18+** and npm (for non-Docker frontend development)
- **SQL Server Management Studio** or **Azure Data Studio** (for database work)

---

## Quick Start

### Option 1: Automated Docker Setup (Recommended)

Both frontend and API can be built and run locally using Docker:

```powershell
# Build and run API locally
cd api
.\build-localApi.ps1

# In another terminal, build and run frontend locally
cd app
.\build-localFrontEnd.ps1
```

**Access:**
- Frontend: http://localhost:4200
- API: http://localhost:8000
- API Docs: http://localhost:8000/docs

### Option 2: VS Code Tasks

Use the predefined tasks in `.vscode/tasks.json`:

1. **Ctrl+Shift+P** → "Tasks: Run Task"
2. Select **"Start Full Stack (API + Frontend)"**

This runs both the API and frontend dev servers.

---

## API Local Development

### Docker Approach (Recommended)

**Build and Run:**
```powershell
cd api
.\build-localApi.ps1
```

**What it does:**
1. Builds Docker image `grooveapp-api:latest`
2. Runs container on port 8000
3. Mounts `api/` directory for live code reloading
4. Sets environment variables for local SQL Server

**Environment Variables:**
The script reads from environment variables or prompts you:
```powershell
$env:SQL_SERVER = "your-local-server.database.windows.net"
$env:SQL_DATABASE = "your-local-database"
```

**Test the API:**
```powershell
# Health check
curl http://localhost:8000/health

# Get C major scale
curl http://localhost:8000/scales/C/1

# Interactive docs
# Open browser: http://localhost:8000/docs
```

**Stop and Clean Up:**
```powershell
# Stop container
docker stop grooveapp-api-local

# Remove container
docker rm grooveapp-api-local

# Remove image
docker rmi grooveapp-api:latest
```

---

### Python Virtual Environment Approach

**Setup:**
```powershell
cd api

# Create virtual environment
python -m venv venv

# Activate
.\venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt
```

**Configure Environment:**
Create `.env` file in `api/` directory:
```env
SQL_SERVER=your-server.database.windows.net
SQL_DATABASE=your-database
LOG_LEVEL=DEBUG
APPLICATIONINSIGHTS_CONNECTION_STRING=your-connection-string
```

**Run:**
```powershell
# Start with auto-reload
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

**VS Code Task:**
Use the "API: Start FastAPI" task for automatic startup.

---

### API Database Connection

**Local SQL Server:**
```powershell
# Set environment variables
$env:SQL_SERVER = "localhost"
$env:SQL_DATABASE = "grooveapp"

# Connection uses Windows Authentication locally
# No password needed
```

**Azure SQL Database:**
```powershell
# Using managed identity (requires Azure CLI login)
az login

# Set environment variables
$env:SQL_SERVER = "sql-grooveapp-dev-uhxg.database.windows.net"
$env:SQL_DATABASE = "db-grooveapp-dev"

# Code uses DefaultAzureCredential which will use your Azure CLI token
```

**Connection String (Alternative):**
```powershell
# For local development only, never commit this
$env:SQL_CONNECTION_STRING = "Server=localhost;Database=grooveapp;Trusted_Connection=True;"
```

---

## Frontend Local Development

### Docker Approach

**Build and Run:**
```powershell
cd app
.\build-localFrontEnd.ps1
```

**What it does:**
1. Builds Docker image `grooveapp-frontend:latest`
2. Runs container on port 4200
3. Configures API_URL to point to local API (http://localhost:8000)

**Access:**
- Frontend: http://localhost:4200

**Note:** Easy Auth is disabled locally, so authentication won't work. API calls will fail if they require auth.

---

### npm Development Server (Recommended for Active Development)

**Setup:**
```powershell
cd app

# Install dependencies
npm install
```

**Run Development Server:**
```powershell
# Start dev server with auto-reload
npm start

# Or use VS Code task: "Frontend: Start Dev Server"
```

**Access:**
- Frontend: http://localhost:4200
- Auto-reloads on file changes

**Configure API URL:**

Frontend uses runtime configuration. For local development:

1. **Edit `environment.ts`:**
```typescript
export const environment = {
  production: false,
  apiUrl: 'http://localhost:8000',
  enableAuth: false  // Disable Easy Auth for local dev
};
```

2. **Or set via environment variable before build:**
```powershell
$env:API_URL = "http://localhost:8000"
npm start
```

---

### Frontend Build Options

**Development Build:**
```powershell
npm run build
```

**Production Build:**
```powershell
npm run build:prod
```

**Staging Build:**
```powershell
npm run build:staging
```

**Output:** Builds to `app/dist/groove-app/browser/`

---

## Database Setup

### Local SQL Server

**1. Install SQL Server:**
- Download [SQL Server Express](https://www.microsoft.com/sql-server/sql-server-downloads)
- Or use Docker:
  ```powershell
  docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=YourStrong@Passw0rd" `
      -p 1433:1433 --name sql1 `
      -d mcr.microsoft.com/mssql/server:2022-latest
  ```

**2. Create Database:**
```powershell
# Using sqlcmd
sqlcmd -S localhost -Q "CREATE DATABASE grooveapp"
```

**3. Run Schema:**
```powershell
cd infra
sqlcmd -S localhost -d grooveapp -i setup-music-tables.sql
```

---

### Azure SQL Database (Remote)

**1. Connect:**
```powershell
# Login to Azure
az login

# Add your IP to firewall
$myIp = (Invoke-WebRequest -Uri "https://api.ipify.org").Content
az sql server firewall-rule create `
    --resource-group rg-grooveapp-dev `
    --server sql-grooveapp-dev-uhxg `
    --name "MyDevMachine" `
    --start-ip-address $myIp `
    --end-ip-address $myIp
```

**2. Test Connection:**
```powershell
sqlcmd -S sql-grooveapp-dev-uhxg.database.windows.net -d db-grooveapp-dev -G
```

**3. Query Data:**
```sql
-- Test tables exist
SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE';

-- Get scale
SELECT * FROM Scales WHERE root_note = 'C' AND scale_type = 1;
```

---

## Development Workflow

### Typical Development Cycle

1. **Start Backend:**
   ```powershell
   cd api
   .\build-localApi.ps1
   ```

2. **Start Frontend:**
   ```powershell
   cd app
   npm start
   ```

3. **Make Changes:**
   - Backend: Edit Python files → auto-reload via `--reload`
   - Frontend: Edit TypeScript/HTML → auto-reload via webpack

4. **Test:**
   - Backend: http://localhost:8000/docs
   - Frontend: http://localhost:4200

5. **Debug:**
   - Use VS Code debugger
   - Check browser console (F12)
   - Check API logs in terminal

---

### Working with Features

**Add a new API endpoint:**
```python
# api/main.py

@app.get("/new-endpoint")
async def new_endpoint():
    return {"message": "Hello"}
```

**Add a new Angular component:**
```powershell
cd app
ng generate component components/my-new-component
```

**Test the endpoint:**
```powershell
curl http://localhost:8000/new-endpoint
```

---

## Debugging

### Backend Debugging (Python)

**VS Code Launch Configuration:**
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Python: FastAPI",
            "type": "python",
            "request": "launch",
            "module": "uvicorn",
            "args": [
                "main:app",
                "--reload",
                "--host", "0.0.0.0",
                "--port", "8000"
            ],
            "cwd": "${workspaceFolder}/api",
            "env": {
                "SQL_SERVER": "${env:SQL_SERVER}",
                "SQL_DATABASE": "${env:SQL_DATABASE}"
            }
        }
    ]
}
```

**Set Breakpoints:**
1. Open `api/main.py`
2. Click left margin to set breakpoint
3. Press F5 to start debugging
4. Make request to API
5. Debugger pauses at breakpoint

---

### Frontend Debugging (Angular)

**Browser DevTools:**
1. Open browser (http://localhost:4200)
2. Press F12
3. Go to Sources tab
4. Set breakpoints in TypeScript files
5. Interact with app

**VS Code Debugging:**
1. Install "Debugger for Chrome" extension
2. Add launch config:
```json
{
    "name": "Launch Chrome against localhost",
    "type": "chrome",
    "request": "launch",
    "url": "http://localhost:4200",
    "webRoot": "${workspaceFolder}/app/src"
}
```

---

### Database Debugging

**Check Connection:**
```powershell
# Test connectivity
sqlcmd -S your-server -d your-database -G -Q "SELECT 1"
```

**View Queries:**
```powershell
# Enable query logging in API
$env:LOG_LEVEL = "DEBUG"
uvicorn main:app --reload
```

**Debug Stored Procedures:**
```sql
-- Run manually
EXEC GetScale @root_note = 'C', @scale_type = 1;
```

---

## Testing

### API Tests

**Run all tests:**
```powershell
cd api
pytest -v
```

**Run specific test:**
```powershell
pytest tests/test_scales.py -v
```

**With coverage:**
```powershell
pytest --cov=. --cov-report=html
```

---

### Frontend Tests

**Run unit tests:**
```powershell
cd app
npm test
```

**Run end-to-end tests:**
```powershell
npm run e2e
```

---

## Common Local Development Issues

### Issue: Port Already in Use

**Symptoms:**
```
Error: Address already in use
```

**Solution:**
```powershell
# Find process using port 8000
netstat -ano | findstr :8000

# Kill process (replace PID)
taskkill /PID <PID> /F
```

---

### Issue: Module Not Found (Python)

**Symptoms:**
```
ModuleNotFoundError: No module named 'fastapi'
```

**Solution:**
```powershell
# Reinstall dependencies
cd api
pip install -r requirements.txt
```

---

### Issue: npm Install Fails

**Symptoms:**
```
npm ERR! code EACCES
```

**Solution:**
```powershell
# Clear npm cache
npm cache clean --force

# Delete node_modules and reinstall
rm -r node_modules
npm install
```

---

### Issue: Database Connection Fails

**Symptoms:**
```
Error: Cannot connect to SQL Server
```

**Solutions:**
1. **Check environment variables:**
   ```powershell
   echo $env:SQL_SERVER
   echo $env:SQL_DATABASE
   ```

2. **Test connection:**
   ```powershell
   sqlcmd -S $env:SQL_SERVER -d $env:SQL_DATABASE -G -Q "SELECT 1"
   ```

3. **Check firewall:**
   ```powershell
   # Add your IP
   az sql server firewall-rule create ...
   ```

---

## Environment Variables Reference

### API Variables
```powershell
$env:SQL_SERVER = "your-server.database.windows.net"
$env:SQL_DATABASE = "your-database"
$env:LOG_LEVEL = "DEBUG"  # DEBUG, INFO, WARNING, ERROR
$env:APPLICATIONINSIGHTS_CONNECTION_STRING = "InstrumentationKey=..."
```

### Frontend Variables
```powershell
$env:API_URL = "http://localhost:8000"
$env:ENABLE_AUTH = "false"  # Disable Easy Auth locally
```

---

## Scripts Reference

### API Scripts
- `build-localApi.ps1` - Build and run API in Docker
- `debug-localApi.ps1` - Run API with debug logging
- `test-apiResponses.ps1` - Test API endpoints

### Frontend Scripts
- `build-localFrontEnd.ps1` - Build and run frontend in Docker

### Infrastructure Scripts
- `setup-music-tables.sql` - Create database schema
- `test-database.sql` - Verify database setup
- `query_examples.sql` - Example queries

---

## Next Steps

- **[Deployment Guide](DEPLOYMENT.md)** - Deploy to Azure
- **[CORS Configuration](CORS_CONFIGURATION.md)** - Configure CORS for production
- **[Troubleshooting](TROUBLESHOOTING.md)** - Common issues and solutions
- **[Logging Quick Reference](LOGGING_QUICK_REFERENCE.md)** - Logging best practices

---

**Last Updated:** January 2025  
**Questions?** Check [README.md](../README.md) for project overview
