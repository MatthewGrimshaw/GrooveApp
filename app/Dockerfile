# Stage 1: Build Angular application
FROM node:20-alpine AS build

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Security: Run npm audit and fail on high/critical vulnerabilities
# This can be disabled during development by setting SKIP_AUDIT build arg
ARG SKIP_AUDIT=false
RUN if [ "$SKIP_AUDIT" = "false" ]; then \
      echo "Running npm audit..."; \
      npm audit --audit-level=high || { \
        echo "❌ Security vulnerabilities found! Run 'npm audit fix' or set --build-arg SKIP_AUDIT=true"; \
        exit 1; \
      }; \
    else \
      echo "⚠️  Skipping npm audit (SKIP_AUDIT=true)"; \
    fi

# Copy source code
COPY . .

# Build argument to select configuration (development or production)
# Defaults to development for local testing (localhost API)
ARG BUILD_CONFIGURATION=development
RUN echo "Building with configuration: $BUILD_CONFIGURATION" && \
    npm run build -- --configuration $BUILD_CONFIGURATION

# Stage 2: Serve with nginx
FROM nginx:alpine

# Copy custom nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Copy built application
COPY --from=build /app/dist/grooveapp-ui/browser /usr/share/nginx/html

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser && \
    chown -R appuser:appuser /usr/share/nginx/html && \
    chown -R appuser:appuser /var/cache/nginx && \
    chown -R appuser:appuser /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown appuser:appuser /var/run/nginx.pid

# Switch to non-root user
USER appuser

# Expose port 8080 (non-privileged port for non-root user)
EXPOSE 8080

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
