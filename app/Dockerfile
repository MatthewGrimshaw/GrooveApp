# Stage 1: Build Angular application
FROM node:20-alpine AS build

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Security: Run npm audit on all dependencies (including dev) and fail on critical vulnerabilities
# Known issue: tar vulnerability in @angular/cli (requires Angular 21 upgrade - breaking change)
ARG SKIP_AUDIT=false
RUN if [ "$SKIP_AUDIT" = "false" ]; then \
  echo "Running npm audit (all dependencies)..."; \
  npm audit --audit-level=critical || { \
  echo "❌ Critical security vulnerabilities found! Run 'npm audit fix' or set --build-arg SKIP_AUDIT=true"; \
  exit 1; \
  }; \
  else \
  echo "⚠️  Skipping npm audit (SKIP_AUDIT=true)"; \
  fi

# Copy source code
COPY . .

# Build argument for Application Insights connection string (injected at build time in Azure)
ARG APPLICATIONINSIGHTS_CONNECTION_STRING=""

# Replace placeholder in environment.prod.ts if connection string is provided
RUN if [ -n "$APPLICATIONINSIGHTS_CONNECTION_STRING" ]; then \
  echo "Injecting Application Insights connection string into environment.prod.ts"; \
  sed -i "s|\${APPLICATIONINSIGHTS_CONNECTION_STRING}|$APPLICATIONINSIGHTS_CONNECTION_STRING|g" src/environments/environment.prod.ts; \
  fi

# Build argument to select configuration (development or production)
# Defaults to development for local testing (localhost API)
ARG BUILD_CONFIGURATION=development
RUN echo "Building with configuration: $BUILD_CONFIGURATION" && \
  npm run build -- --configuration $BUILD_CONFIGURATION

# Stage 2: Serve with nginx
FROM nginx:alpine

# Install gettext for envsubst command
RUN apk add --no-cache gettext

# Copy custom nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Copy built application
COPY --from=build /app/dist/grooveapp-ui/browser /usr/share/nginx/html

# Copy entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Expose port 8080
EXPOSE 8080

# Use entrypoint to inject environment variables at runtime
ENTRYPOINT ["/docker-entrypoint.sh"]

