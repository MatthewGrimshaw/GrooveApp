# CI/CD Pipeline Documentation

This document describes the comprehensive CI/CD pipeline configured for the GrooveApp repository.

## Overview

The pipeline implements a multi-stage CI/CD workflow that includes:
- **Security Scanning**: Secret detection, SAST, SCA, dependency vulnerabilities
- **Code Quality**: Linting, formatting, type checking
- **Testing**: Unit tests, integration tests with coverage tracking
- **Infrastructure**: Terraform validation, security scanning, and deployment
- **Quality Gates**: Enforced thresholds before merging

## Pipeline Stages

### 1. Security Scanning (Parallel Execution)

#### Secret Scanning
- **TruffleHog**: Detects secrets in code history
- **GitLeaks**: GitHub-native secret scanning
- **Triggers**: Every push and PR
- **Fail-fast**: Yes - blocks pipeline if secrets detected

#### CodeQL Analysis (SAST)
- **Languages**: Python, JavaScript/TypeScript
- **Queries**: Security-extended + quality checks
- **Integration**: GitHub Advanced Security
- **Results**: Uploaded to Security tab

#### Dependency Scanning (SCA)
- **Python**: Safety + pip-audit
- **Node.js**: npm audit
- **Thresholds**: Fails on high/critical vulnerabilities
- **Reports**: JSON artifacts uploaded

### 2. Terraform Validation & Security

Runs in parallel with other scans:

```yaml
Jobs:
  - Format check (terraform fmt)
  - Validation (terraform validate)
  - Security scanning:
    - tfsec
    - Checkov
  - Linting (TFLint)
```

**Results**: Posted as PR comment + SARIF uploaded to Security tab

### 3. Application Testing (Parallel)

#### Python API Tests
- Framework: pytest with pytest-xdist (parallel execution)
- Coverage: Minimum 70% threshold
- Reports: JUnit XML + HTML coverage
- Upload to: Codecov

#### Angular Frontend Tests
- Framework: Karma + Jasmine
- Browser: ChromeHeadless
- Coverage: Minimum 70% threshold
- Reports: LCOV + JSON coverage
- Upload to: Codecov

#### Python Linting & SAST
- **Black**: Code formatting
- **isort**: Import sorting
- **Flake8**: Style guide enforcement
- **Pylint**: Static analysis
- **Bandit**: Security linting
- **MyPy**: Type checking

#### Angular Linting
- **ESLint**: TypeScript/JavaScript linting
- **Angular CLI**: Component/template linting

### 4. Docker Image Security

Runs after tests pass:

- **Trivy Scanner**: Vulnerability detection in Docker images
- **Severity**: Critical/High findings fail the pipeline
- **Images Scanned**: API + Frontend
- **Results**: SARIF uploaded to Security tab

### 5. Quality Gate

Aggregates all previous job results:

```
Required Checks:
✓ No secrets detected
✓ No critical CodeQL issues
✓ No high/critical dependencies
✓ Terraform valid
✓ Tests passed (>70% coverage)
✓ No critical Docker vulnerabilities
```

**Result**: Posted as PR comment with status table

### 6. Terraform Apply (Conditional)

Only runs when:
- Quality gates pass
- Branch is `main` or `develop`
- Uses GitHub Environments for approval gates

**Process**:
1. Azure login via OIDC (no secrets!)
2. Terraform init with remote backend
3. Plan + review
4. Apply (auto-approved for CI)
5. Output captured as artifact

### 7. Integration Tests (Post-Deployment)

Runs after infrastructure deployment:

```bash
Health Checks:
  - API /health endpoint
  - Frontend redirect (302)
  - Database connectivity
  - Authentication flow
```

### 8. Pipeline Summary

Generates markdown summary showing:
- Build information
- All stage results
- Links to artifacts
- Coverage reports

## GitHub Secrets Required

Configure these secrets in your repository (created by `Configure-Github.ps1`):

### Repository Secrets
```
AZURE_CLIENT_ID          # Service principal client ID
AZURE_TENANT_ID          # Azure AD tenant ID
```

### Environment Secrets (Production, Dev, etc.)
```
AZURE_SUBSCRIPTION_ID           # Target subscription
AZURE_STORAGE_ACCOUNT_NAME      # Terraform state storage
AZURE_STORAGE_CONTAINER_NAME    # State container
AZURE_RESOURCE_GROUP_NAME       # State resource group
```

## Quality Gates

### Coverage Thresholds
- **Python API**: Minimum 70% line coverage
- **Angular Frontend**: Minimum 70% line coverage

### Security Thresholds
- **Secrets**: Zero tolerance - any detection fails
- **CodeQL**: Critical/High issues fail
- **Dependencies**: High/Critical vulnerabilities fail
- **Docker**: Critical vulnerabilities fail

### Linting Standards
- **Python**: 
  - Black formatting required
  - Flake8 errors fail
  - Bandit high-severity issues fail
- **TypeScript/Angular**:
  - ESLint errors fail

## Parallelization Strategy

The pipeline is optimized for speed:

```
Stage 1 (Parallel): ~3-5 minutes
├─ Secret Scanning
├─ CodeQL (Python + JavaScript)
├─ Dependency Scanning
└─ Terraform Validation

Stage 2 (Parallel): ~5-8 minutes
├─ Python Tests (pytest-xdist)
├─ Python Lint
├─ Angular Tests
└─ Angular Lint

Stage 3 (Parallel): ~3-5 minutes
├─ Docker Scan (API)
└─ Docker Scan (Frontend)

Stage 4: Quality Gate (~30 seconds)

Stage 5: Terraform Apply (~2-5 minutes) [main/develop only]

Stage 6: Integration Tests (~2 minutes) [main/develop only]
```

**Total Time**:
- PR/Feature Branch: ~12-18 minutes
- Main/Develop: ~17-25 minutes

## Branch Strategy

### Feature Branches
- All security scans run
- All tests run
- Quality gates enforced
- **No deployment**

### Pull Requests to Main
- All checks required to pass
- PR comment with results
- Approval gates before merge

### Main Branch
- All checks run
- Deploys to Production environment
- Integration tests executed
- Requires manual approval (GitHub Environment)

### Develop Branch
- All checks run
- Deploys to Dev environment
- Integration tests executed
- Auto-deploys (no approval)

## GitHub Advanced Security Integration

### Security Tab Features
1. **Code Scanning Alerts**: CodeQL findings
2. **Secret Scanning**: Detected secrets
3. **Dependency Alerts**: Vulnerable packages
4. **Security Advisories**: CVE tracking

### SARIF Uploads
All security tools upload SARIF format:
- tfsec (Terraform)
- Checkov (IaC)
- Trivy (Docker)
- CodeQL (SAST)

## Notifications

### PR Comments
- Terraform plan results
- Quality gate status
- Coverage reports

### GitHub Checks
- All jobs appear as checks
- Required status checks enforced
- Detailed logs available

## Troubleshooting

### Common Issues

**1. Terraform Init Fails**
```
Error: Failed to get existing workspaces
```
**Solution**: Check Azure storage account firewall settings

**2. Coverage Below Threshold**
```
Error: Coverage 65% is below 70% threshold
```
**Solution**: Add more tests or adjust threshold in workflow

**3. Secret Detected**
```
Error: TruffleHog found verified secrets
```
**Solution**: Remove secret, rotate credentials, update .gitignore

**4. Docker Scan Critical Vuln**
```
Error: Trivy found CRITICAL vulnerabilities
```
**Solution**: Update base image, patch dependencies

### Debug Mode

Enable debug logging:
```yaml
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

## Customization

### Adjust Coverage Threshold
Edit workflow file:
```yaml
if (( $(echo "$coverage < 70" | bc -l) )); then
  # Change 70 to desired threshold
```

### Add New Security Tools
```yaml
- name: My Security Tool
  uses: vendor/tool-action@v1
  with:
    format: sarif
    output: results.sarif

- name: Upload Results
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: results.sarif
```

### Skip Jobs for Specific Branches
```yaml
if: github.ref != 'refs/heads/skip-ci'
```

## Performance Optimization

Current optimizations:
- ✅ Parallel job execution (8-10 jobs concurrent)
- ✅ NPM/Pip caching
- ✅ Incremental CodeQL analysis
- ✅ Docker layer caching
- ✅ pytest-xdist parallel tests

Future improvements:
- [ ] Test sharding for large suites
- [ ] Remote caching for Terraform
- [ ] Matrix builds for multiple environments

## Compliance & Auditing

The pipeline provides audit trail for:
- Code changes (Git history)
- Test results (JUnit XML + artifacts)
- Security scans (SARIF reports)
- Deployments (Terraform state)
- Approvals (GitHub Environment history)

**Retention**: Artifacts kept for 90 days

## Cost Considerations

GitHub Actions usage:
- **Free tier**: 2,000 minutes/month (public repos unlimited)
- **Estimated usage**: ~500 minutes/week for active development
- **Cost per PR**: ~20-30 minutes
- **Cost per deployment**: ~25-35 minutes

**Optimization tip**: Use self-hosted runners for cost reduction

## Support

For issues or questions:
1. Check workflow run logs in Actions tab
2. Review Security tab for vulnerability details
3. See [GitHub Actions documentation](https://docs.github.com/actions)
4. Contact DevOps team

## Changelog

### v1.0.0 (Current)
- Initial pipeline setup
- Security scanning integrated
- Quality gates enforced
- Terraform deployment automated
- Integration tests added
