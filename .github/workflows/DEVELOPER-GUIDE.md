# CI/CD Pipeline - Developer Quick Reference

## Pre-Commit Checklist

Before pushing code, run these locally to catch issues early:

### Python API
```bash
cd api

# Format code
black .
isort .

# Run linters
flake8 .
pylint **/*.py

# Security scan
bandit -r . -ll

# Run tests with coverage
pytest --cov=. --cov-report=term

# Type checking
mypy . --ignore-missing-imports
```

### Angular Frontend
```bash
cd app

# Install dependencies
npm ci

# Lint code
ng lint

# Run tests with coverage
ng test --code-coverage --watch=false --browsers=ChromeHeadless

# Build for production
ng build --configuration=production
```

### Terraform
```bash
cd infra/terraform

# Format
terraform fmt -recursive

# Validate
terraform init -backend=false
terraform validate

# Security scan
tfsec .
checkov -d .
```

### Docker
```bash
# Build images
docker build -t grooveapp-api:test ./api
docker build -t grooveapp-app:test ./app

# Scan for vulnerabilities
trivy image grooveapp-api:test
trivy image grooveapp-app:test
```

## Pipeline Triggers

| Event | Trigger | Jobs Run | Deploy? |
|-------|---------|----------|---------|
| Push to feature branch | Automatic | All tests + scans | No |
| Push to develop | Automatic | All tests + scans + deploy | Yes (Dev) |
| Push to main | Automatic | All tests + scans + deploy | Yes (Prod) |
| Pull Request | Automatic | All tests + scans | No |

## Understanding Pipeline Results

### ✅ Green Check - Success
All quality gates passed. Safe to merge!

### ❌ Red X - Failure
Check the failed job logs:
1. Click "Details" next to the failed check
2. Expand the failed step
3. Review error message
4. Fix and push again

### 🟡 Yellow Dot - In Progress
Pipeline is running. Wait for completion.

## Common Failures & Fixes

### 1. "Secret detected by TruffleHog"
```bash
# Remove the secret from code
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch path/to/file" \
  --prune-empty --tag-name-filter cat -- --all

# Rotate the exposed credential immediately!
```

### 2. "Coverage below 70% threshold"
```bash
# Check which files need more tests
pytest --cov=. --cov-report=html
open htmlcov/index.html

# Add tests for uncovered lines
# Push again
```

### 3. "Terraform fmt check failed"
```bash
cd infra/terraform
terraform fmt -recursive
git add .
git commit -m "fix: terraform formatting"
git push
```

### 4. "Black formatting failed"
```bash
cd api
black .
git add .
git commit -m "fix: python formatting"
git push
```

### 5. "Docker image has CRITICAL vulnerabilities"
```bash
# Check the Trivy report
trivy image grooveapp-api:test

# Update base image in Dockerfile
FROM python:3.11-slim  # Use latest patch version

# Update dependencies
pip install --upgrade package-name

# Rebuild and test
docker build -t grooveapp-api:test .
trivy image grooveapp-api:test
```

### 6. "High severity npm vulnerabilities"
```bash
cd app

# Check audit
npm audit

# Auto-fix if possible
npm audit fix

# If auto-fix doesn't work, update manually
npm update package-name

# Test locally
npm test
```

## Quality Gate Requirements

To pass quality gates, your code must:

- [ ] ✅ No secrets in code
- [ ] ✅ No critical/high security vulnerabilities
- [ ] ✅ Python tests pass with >70% coverage
- [ ] ✅ Angular tests pass with >70% coverage
- [ ] ✅ No linting errors
- [ ] ✅ Terraform valid and formatted
- [ ] ✅ Docker images have no critical vulnerabilities

## Skipping CI (Emergency Only)

Add `[skip ci]` to commit message:
```bash
git commit -m "docs: update README [skip ci]"
```

⚠️ **WARNING**: Only use for documentation changes! Never skip CI for code changes.

## Getting Help

### Pipeline Logs
1. Go to **Actions** tab
2. Click on your workflow run
3. Click on failed job
4. Expand failed step
5. Copy relevant error

### Security Issues
1. Go to **Security** tab
2. Click **Code scanning** or **Dependabot**
3. Review alerts
4. Click alert for remediation guidance

### Local Testing
Run the same checks locally before pushing:
```bash
# Install pre-commit hooks
pip install pre-commit
pre-commit install

# Run all checks
pre-commit run --all-files
```

## Pipeline Stages Overview

```
┌─────────────────────────────────────────────┐
│  STAGE 1: Security Scanning (Parallel)     │
│  - Secret scanning                          │
│  - CodeQL (SAST)                           │
│  - Dependency scanning (SCA)               │
│  - Terraform security                      │
│  Duration: ~3-5 minutes                    │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│  STAGE 2: Testing (Parallel)               │
│  - Python unit tests + coverage            │
│  - Python linting                          │
│  - Angular unit tests + coverage           │
│  - Angular linting                         │
│  Duration: ~5-8 minutes                    │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│  STAGE 3: Docker Scanning (Parallel)       │
│  - API image scan                          │
│  - Frontend image scan                     │
│  Duration: ~3-5 minutes                    │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│  STAGE 4: Quality Gate                     │
│  - Aggregate all results                   │
│  - Enforce thresholds                      │
│  Duration: ~30 seconds                     │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│  STAGE 5: Deploy (main/develop only)       │
│  - Terraform apply                         │
│  - Integration tests                       │
│  Duration: ~7-10 minutes                   │
└─────────────────────────────────────────────┘
```

**Total Duration**: 12-30 minutes (depending on branch)

## Best Practices

### Writing Tests
```python
# Python - Use descriptive names
def test_api_returns_401_for_unauthenticated_requests():
    response = client.get("/protected-endpoint")
    assert response.status_code == 401

# Cover edge cases
def test_handles_empty_input():
    result = process_data("")
    assert result == expected_empty_result
```

```typescript
// Angular - Test components thoroughly
it('should redirect unauthenticated users', () => {
  component.checkAuth();
  expect(router.navigate).toHaveBeenCalledWith(['/login']);
});
```

### Writing Secure Code
```python
# ❌ BAD - Secret in code
api_key = "sk-1234567890abcdef"

# ✅ GOOD - Use environment variables
api_key = os.environ.get("API_KEY")

# ❌ BAD - SQL injection
query = f"SELECT * FROM users WHERE name = '{user_input}'"

# ✅ GOOD - Parameterized query
query = "SELECT * FROM users WHERE name = ?"
cursor.execute(query, (user_input,))
```

### Terraform Best Practices
```hcl
# Use variables
variable "environment" {
  description = "Environment name"
  type        = string
}

# Add tags
tags = {
  Environment = var.environment
  ManagedBy   = "Terraform"
  Application = "GrooveApp"
}

# Use remote state
terraform {
  backend "azurerm" {
    # Configuration from secrets
  }
}
```

## Monitoring Your PR

After pushing:
1. **Check Status**: Look for green checkmarks in PR
2. **Review Comments**: Bot will post Terraform plan and quality gate results
3. **Fix Issues**: If any checks fail, review logs and fix
4. **Request Review**: Once all checks pass, request code review

## Environment Deployment

### Dev Environment
- **Branch**: develop
- **Auto-deploy**: Yes
- **Approval**: Not required
- **URL**: https://app-grooveapp-dev-frontend.azurewebsites.net

### Production Environment
- **Branch**: main
- **Auto-deploy**: No
- **Approval**: Required (GitHub Environment protection)
- **URL**: https://app-grooveapp-prod-frontend.azurewebsites.net

## Useful Commands

### Check Pipeline Status
```bash
# Via GitHub CLI
gh run list --branch $(git branch --show-current)
gh run view --log-failed
```

### Download Artifacts
```bash
gh run download <run-id>
```

### Re-run Failed Jobs
```bash
gh run rerun <run-id> --failed
```

## Tips for Faster CI

1. **Write focused tests**: Small, fast, focused tests
2. **Use caching**: NPM and pip caching enabled automatically
3. **Run locally first**: Catch issues before pushing
4. **Fix formatting**: Run formatters before commit
5. **Keep dependencies updated**: Reduces scan time

## Need More Help?

- 📖 [Full Documentation](./CI-CD-README.md)
- 🔒 [Security Tab](../../../security)
- 🚀 [Actions Tab](../../../actions)
- 💬 Ask in #devops channel
