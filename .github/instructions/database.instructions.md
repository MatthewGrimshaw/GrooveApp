# Database Management Instructions

## Core Principle
**ALL database schema changes MUST be made in `infra/setup-music-tables.sql`**

This file is the single source of truth for the database schema. It is idempotent and can be run repeatedly without causing errors.

## Database Connection Details

### Environment-Specific Connection Strings

**NEVER use environment variables (`$env:SQL_SERVER`, `$env:SQL_DATABASE`)** when deploying or testing databases.
Always use explicit connection strings for the specific environment:

#### Development
```powershell
Server: sql-grooveapp-dev-uhxg.database.windows.net
Database: sqldb-grooveapp-dev
```

#### Staging
```powershell
Server: sql-grooveapp-staging-{suffix}.database.windows.net
Database: sqldb-grooveapp-staging
```

#### Production
```powershell
Server: sql-grooveapp-prod-{suffix}.database.windows.net
Database: sqldb-grooveapp-prod
```

### Available Tools for Database Access

1. **sqlcmd with Interactive Azure AD Authentication** (PREFERRED METHOD)
   
   **Why this is preferred:**
   - Works reliably on non-domain-joined machines
   - Uses your Azure AD credentials securely
   - No environment variable conflicts
   - Opens browser for one-time authentication per session
   
   **Before first use, clear any conflicting environment variables:**
   ```powershell
   Remove-Item Env:\SQLCMDPASSWORD -ErrorAction SilentlyContinue
   ```
   
   **Execute SQL scripts:**
   ```powershell
   sqlcmd -S sql-grooveapp-dev-uhxg.database.windows.net -d sqldb-grooveapp-dev -G -U matgri@microsoft.com -i setup-music-tables.sql
   ```
   
   **Run queries:**
   ```powershell
   sqlcmd -S sql-grooveapp-dev-uhxg.database.windows.net -d sqldb-grooveapp-dev -G -U matgri@microsoft.com -Q "SELECT * FROM Notes"
   ```
   
   **Authentication flags explained:**
   - `-G` - Use Azure Active Directory authentication
   - `-U matgri@microsoft.com` - Your Azure AD user principal name (UPN)
   - First run opens browser for authentication
   - Token cached for subsequent commands in same session

2. **MCP Azure SQL Tools** (Copilot can connect directly)
   - Copilot has access to Azure SQL MCP server tools
   - Can execute queries directly without manual sqlcmd commands
   - Useful for investigation and verification

3. **MSSQL Connection Tools** (Copilot can manage connections)
   - `mssql_connect` - Connect to Azure SQL Server
   - `mssql_list_databases` - List available databases
   - `mssql_change_database` - Switch database context
   - Direct query execution via Copilot

## What NOT to Do

### ❌ NEVER Create Separate Deployment Scripts
Do NOT create wrapper scripts like:
- `deploy-*.ps1`
- `update-database.ps1`
- `migrate-*.ps1`
- Any other PowerShell/bash scripts that deploy database changes

### ❌ NEVER Create Separate SQL Files for Changes
Do NOT create files like:
- `add-feature.sql`
- `update-schema.sql`
- `migration-001.sql`
- `hotfix-*.sql`

## What TO Do

### ✅ Update setup-music-tables.sql Directly
All database changes go into `infra/setup-music-tables.sql`:
- Add new tables
- Insert reference data
- Create views
- Add indexes
- Modify schemas

The file is designed to be idempotent using patterns like:
```sql
IF OBJECT_ID('dbo.TableName', 'U') IS NOT NULL
    DROP TABLE dbo.TableName;

IF NOT EXISTS (SELECT 1 FROM dbo.TableName WHERE ...)
BEGIN
    INSERT INTO dbo.TableName ...
END
```

### ✅ Deploy Using Interactive Azure AD Authentication

**ALWAYS use the interactive Azure AD method with explicit server and database names:**

```powershell
cd infra

# Clear any environment variable conflicts (run once per session)
Remove-Item Env:\SQLCMDPASSWORD -ErrorAction SilentlyContinue

# Development
sqlcmd -S sql-grooveapp-dev-uhxg.database.windows.net -d sqldb-grooveapp-dev -G -U matgri@microsoft.com -i setup-music-tables.sql

# Staging
sqlcmd -S sql-grooveapp-staging-{suffix}.database.windows.net -d sqldb-grooveapp-staging -G -U matgri@microsoft.com -i setup-music-tables.sql

# Production
sqlcmd -S sql-grooveapp-prod-{suffix}.database.windows.net -d sqldb-grooveapp-prod -G -U matgri@microsoft.com -i setup-music-tables.sql
```

**Authentication Details:**
- `-G` - Azure Active Directory authentication
- `-U matgri@microsoft.com` - Your Azure AD UPN (replace with your email)
- Browser opens for first authentication in session
- Token cached for subsequent commands
- No need for `az login` first (sqlcmd handles authentication)

### ✅ Use test-database.sql for All Database Testing
**THE ONLY database testing file is `infra/test-database.sql`**

This comprehensive SQL script tests ALL database functionality:
- Core tables (Notes, Intervals, ScaleTypes, ChordTypes)
- Views (vw_NoteIntervals, vw_CircleOfFifthsKeys)
- Functions (fn_GenerateScale, fn_GenerateArpeggio)
- Chord progressions (DiatonicChordProgressions)
- Circle of Fifths validation (duplicates, sharp symbols, chord counts)
- Detailed diagnostics for missing data

**Run after every deployment:**
```powershell
cd infra

# Development
sqlcmd -S sql-grooveapp-dev-uhxg.database.windows.net -d sqldb-grooveapp-dev -G -U matgri@microsoft.com -i test-database.sql

# Staging
sqlcmd -S sql-grooveapp-staging-{suffix}.database.windows.net -d sqldb-grooveapp-staging -G -U matgri@microsoft.com -i test-database.sql

# Production
sqlcmd -S sql-grooveapp-prod-{suffix}.database.windows.net -d sqldb-grooveapp-prod -G -U matgri@microsoft.com -i test-database.sql
```

**Do NOT create separate test SQL files** like:
- ❌ `test-circle-of-fifths.sql`
- ❌ `test-feature-*.sql`
- ❌ `verify-*.sql`
- ❌ `check-*.sql`

**Do NOT create separate PowerShell test scripts** like:
- ❌ `test-database-content.ps1`
- ❌ `verify-*.ps1`
- ❌ `check-*.ps1`

**All database testing and verification logic must be in `test-database.sql` using T-SQL.**

When adding new features to the database:
1. Add the schema/data to `setup-music-tables.sql`
2. Add corresponding tests to `test-database.sql` (append as new test numbers)
3. Update the test summary section in `test-database.sql` to document the new tests

**Application/API testing scripts are acceptable:**
- ✅ `api/test-chord-progressions.ps1` - Tests API endpoints (not database directly)
- ✅ `api/test-apiResponses.ps1` - Tests API responses
- ✅ Application-level integration tests

## Workflow for Database Changes

1. **Edit** `infra/setup-music-tables.sql`
   - Add your changes using idempotent patterns
   - Keep the file organized by feature/table

2. **Deploy** using interactive Azure AD authentication:
   ```powershell
   cd infra
   # Development
   sqlcmd -S sql-grooveapp-dev-uhxg.database.windows.net -d sqldb-grooveapp-dev -G -U matgri@microsoft.com -i setup-music-tables.sql
   ```

3. **Test** using test-database.sql:
   ```powershell
   cd infra
   # Development
   sqlcmd -S sql-grooveapp-dev-uhxg.database.windows.net -d sqldb-grooveapp-dev -G -U matgri@microsoft.com -i test-database.sql
   ```
   
   Review the output for:
   - ✓ All tests passed
   - ✗ Failed tests indicate missing data or schema errors
   - Detailed diagnostics for troubleshooting

4. **Add tests** for new features:
   - When adding new tables/views/functions to setup-music-tables.sql
   - Also add verification tests to test-database.sql
   - Use Test format: `PRINT 'Test N: Description...'`
   - Include expected counts, sample data, and failure messages

## Alternative: Using Copilot MCP Tools

Copilot can connect directly to Azure SQL databases using MCP tools:

```
Ask Copilot to:
- "Connect to the dev database and run test-database.sql"
- "Connect to sql-grooveapp-dev-uhxg.database.windows.net / sqldb-grooveapp-dev and execute setup-music-tables.sql"
- "Query the DiatonicChordProgressions table in the dev database"
```

This approach eliminates manual sqlcmd commands and allows Copilot to:
- Execute queries directly
- Verify deployment results
- Troubleshoot data issues
- Run diagnostic queries

## Why This Approach?

1. **Single Source of Truth**: One file contains the entire schema
2. **Idempotent**: Can run repeatedly without errors
3. **Version Control**: Git tracks all changes in one place
4. **No Migration Management**: No need to track which migrations ran
5. **Simple Deployment**: One command deploys everything
6. **Self-Documenting**: File shows complete database structure

## Exception: CI/CD Pipelines

GitHub Actions workflows can call setup-music-tables.sql but should not contain inline SQL. Keep all SQL in the .sql file.

Example (acceptable):
```yaml
- name: Deploy Database
  run: sqlcmd -S ${{ secrets.SQL_SERVER }} -d ${{ secrets.SQL_DATABASE }} -G -i infra/setup-music-tables.sql
```

## Summary

- ✅ Edit: `infra/setup-music-tables.sql` (all schema changes)
- ✅ Deploy: `sqlcmd -S sql-grooveapp-dev-uhxg.database.windows.net -d sqldb-grooveapp-dev -G -U matgri@microsoft.com -i setup-music-tables.sql`
- ✅ Test: `sqlcmd -S sql-grooveapp-dev-uhxg.database.windows.net -d sqldb-grooveapp-dev -G -U matgri@microsoft.com -i test-database.sql`
- ✅ Add tests: Update test-database.sql with new validation tests
- ✅ Use interactive Azure AD authentication (`-G -U your@email.com`)
- ✅ Clear environment variables first: `Remove-Item Env:\SQLCMDPASSWORD -ErrorAction SilentlyContinue`
- ✅ Or ask Copilot to connect directly using MCP tools
- ❌ Don't: Use `-G` alone (requires domain-joined machine)
- ❌ Don't: Use environment variables for authentication
- ❌ Don't: Create deployment wrapper scripts
- ❌ Don't: Create separate migration files
- ❌ Don't: Create PowerShell database test scripts (use T-SQL only)
