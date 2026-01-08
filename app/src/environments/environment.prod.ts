export const environment = {
  production: true,
  apiUrl: 'https://app-grooveapp-prod-api.azurewebsites.net',
  // Application Insights connection string (injected at build time via environment variable)
  appInsightsConnectionString: '${APPLICATIONINSIGHTS_CONNECTION_STRING}',
  // Log Level: 'OFF' | 'ERROR' | 'WARNING' | 'INFO' | 'DEBUG'
  logLevel: 'INFO'
};
