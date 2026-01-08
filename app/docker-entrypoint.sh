#!/bin/sh
# Docker entrypoint script to inject environment variables into index.html

# Create runtime config script with environment variables
cat > /usr/share/nginx/html/runtime-config.js <<EOF
window.runtimeConfig = {
  apiUrl: '${API_URL:-https://app-grooveapp-dev-api.azurewebsites.net}',
  appInsightsConnectionString: '${APPLICATIONINSIGHTS_CONNECTION_STRING:-}',
  logLevel: 'DEBUG'
};
EOF

# Start nginx
exec nginx -g "daemon off;"
