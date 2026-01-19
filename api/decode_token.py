import os
import base64
import json

token = os.environ.get("AZURE_ACCESS_TOKEN", "")
if not token:
    print("No token found")
    exit(1)

parts = token.split(".")
if len(parts) < 2:
    print("Invalid token format")
    exit(1)

payload = parts[1]
padding = "=" * (4 - len(payload) % 4) if len(payload) % 4 != 0 else ""

try:
    decoded = base64.urlsafe_b64decode(payload + padding)
    claims = json.loads(decoded)

    print("=== Token Identity ===")
    print(f'unique_name: {claims.get("unique_name", "N/A")}')
    print(f'upn: {claims.get("upn", "N/A")}')
    print(f'name: {claims.get("name", "N/A")}')
    print(f'oid: {claims.get("oid", "N/A")}')
    print()
    print("SQL Server will match against: unique_name or upn")
    print(
        f'Expected database user: {claims.get("unique_name") or claims.get("upn", "UNKNOWN")}'
    )
except Exception as e:
    print(f"Error decoding token: {e}")
