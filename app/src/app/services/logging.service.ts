/**
 * Logging Service for GrooveApp Frontend
 * Integrates with Azure Application Insights and provides structured logging
 */
import { Injectable } from '@angular/core';
import { ApplicationInsights, IEventTelemetry, IExceptionTelemetry, IMetricTelemetry, SeverityLevel } from '@microsoft/applicationinsights-web';
import { environment } from '../../environments/environment';

export type LogLevel = 'OFF' | 'ERROR' | 'WARNING' | 'INFO' | 'DEBUG';

export interface LogContext {
  operationId?: string;
  userId?: string;
  page?: string;
  component?: string;
  action?: string;
  [key: string]: any;
}

export interface HttpLog {
  timestamp: Date;
  type: 'request' | 'response' | 'error';
  method: string;
  url: string;
  status?: number;
  duration?: number;
  operationId: string;
  requestHeaders?: any;
  requestBody?: any;
  responseHeaders?: any;
  responseBody?: any;
  errorMessage?: string;
}

@Injectable({
  providedIn: 'root'
})
export class LoggingService {
  private appInsights?: ApplicationInsights;
  private logLevel: LogLevel;
  private currentOperationId?: string;
  private userId: string = 'anonymous';
  private httpLogs: HttpLog[] = [];
  private maxHttpLogs = 100; // Keep last 100 HTTP requests

  constructor() {
    this.logLevel = (environment.logLevel as LogLevel) || 'INFO';

    // Initialize Application Insights if connection string provided
    if (environment.appInsightsConnectionString &&
        environment.appInsightsConnectionString !== '${APPLICATIONINSIGHTS_CONNECTION_STRING}' &&
        environment.appInsightsConnectionString !== '') {
      try {
        this.appInsights = new ApplicationInsights({
          config: {
            connectionString: environment.appInsightsConnectionString,
            enableAutoRouteTracking: true, // Automatic page view tracking
            enableCorsCorrelation: true,   // Correlate with backend
            enableRequestHeaderTracking: true,
            enableResponseHeaderTracking: true,
            correlationHeaderExcludedDomains: ['*.queue.core.windows.net'],
            disableFetchTracking: false,
            enableAjaxErrorStatusText: true,
            autoTrackPageVisitTime: true
          }
        });

        this.appInsights.loadAppInsights();
        this.appInsights.trackPageView(); // Initial page view

        // Set cloud role name for filtering in Application Insights
        this.appInsights.context.application.ver = '1.0.0';
        this.appInsights.addTelemetryInitializer((envelope: any) => {
          envelope.tags = envelope.tags || {};
          envelope.tags['ai.cloud.role'] = 'grooveapp-frontend';
          envelope.tags['ai.cloud.roleInstance'] = window.location.hostname;
          return true;
        });

        this.info('Application Insights initialized', { component: 'LoggingService' });
      } catch (error) {
        console.warn('Failed to initialize Application Insights:', error);
        console.warn('Falling back to console logging only');
      }
    } else {
      this.info('Running in local mode - Application Insights disabled', { component: 'LoggingService' });
    }
  }

  /**
   * Set the current user ID for all subsequent logs
   */
  setUserId(userId: string): void {
    this.userId = userId;
    if (this.appInsights) {
      this.appInsights.setAuthenticatedUserContext(userId);
    }
  }

  /**
   * Get or generate an operation ID for request correlation
   */
  getOperationId(): string {
    if (!this.currentOperationId) {
      this.currentOperationId = this.generateOperationId();
    }
    return this.currentOperationId;
  }

  /**
   * Set operation ID (typically from X-Operation-ID response header)
   */
  setOperationId(operationId: string): void {
    this.currentOperationId = operationId;
  }

  /**
   * Clear operation ID (call after request completes)
   */
  clearOperationId(): void {
    this.currentOperationId = undefined;
  }

  /**
   * Log debug message
   */
  debug(message: string, context?: LogContext): void {
    if (this.shouldLog('DEBUG')) {
      this.log('DEBUG', message, context);
    }
  }

  /**
   * Log info message
   */
  info(message: string, context?: LogContext): void {
    if (this.shouldLog('INFO')) {
      this.log('INFO', message, context);
    }
  }

  /**
   * Log warning message
   */
  warning(message: string, context?: LogContext): void {
    if (this.shouldLog('WARNING')) {
      this.log('WARNING', message, context);
    }
  }

  /**
   * Log error message
   */
  error(message: string, error?: Error, context?: LogContext): void {
    if (this.shouldLog('ERROR')) {
      this.log('ERROR', message, context, error);

      // Track exception in Application Insights
      if (this.appInsights && error) {
        const exception: IExceptionTelemetry = {
          exception: error,
          severityLevel: SeverityLevel.Error,
          properties: {
            ...context,
            userId: this.userId,
            operationId: this.currentOperationId
          }
        };
        this.appInsights.trackException(exception);
      }
    }
  }

  /**
   * Track custom event
   */
  trackEvent(name: string, properties?: { [key: string]: any }, measurements?: { [key: string]: number }): void {
    if (this.shouldLog('INFO')) {
      this.info(`Event: ${name}`, { ...properties, eventType: 'custom_event' });

      if (this.appInsights) {
        const event: IEventTelemetry = {
          name,
          properties: {
            ...properties,
            userId: this.userId,
            operationId: this.currentOperationId
          },
          measurements
        };
        this.appInsights.trackEvent(event);
      }
    }
  }

  /**
   * Track metric
   */
  trackMetric(name: string, average: number, properties?: { [key: string]: any }): void {
    if (this.appInsights) {
      const metric: IMetricTelemetry = {
        name,
        average,
        properties: {
          ...properties,
          userId: this.userId,
          operationId: this.currentOperationId
        }
      };
      this.appInsights.trackMetric(metric);
    }
  }

  /**
   * Track page view
   */
  trackPageView(name?: string, uri?: string, properties?: { [key: string]: any }): void {
    if (this.shouldLog('INFO')) {
      this.info(`Page View: ${name || uri || window.location.pathname}`, {
        ...properties,
        eventType: 'page_view'
      });

      if (this.appInsights) {
        this.appInsights.trackPageView({
          name,
          uri,
          properties: {
            ...properties,
            userId: this.userId
          }
        });
      }
    }
  }

  /**
   * Track API dependency (HTTP request)
   */
  trackDependency(
    id: string,
    method: string,
    url: string,
    duration: number,
    success: boolean,
    resultCode?: number,
    properties?: { [key: string]: any }
  ): void {
    if (this.shouldLog('DEBUG')) {
      this.debug(`API ${method} ${url} - ${resultCode} (${duration}ms)`, {
        ...properties,
        method,
        url,
        duration,
        success,
        resultCode
      });
    }

    if (this.appInsights) {
      this.appInsights.trackDependencyData({
        id,
        target: url,
        name: `${method} ${url}`,
        duration,
        success,
        responseCode: resultCode || 0,
        type: 'HTTP',
        properties: {
          ...properties,
          userId: this.userId,
          operationId: this.currentOperationId
        }
      });
    }
  }

  /**
   * Create audit log entry
   */
  audit(eventType: string, details: any): void {
    const auditContext: LogContext = {
      eventType: 'AUDIT',
      auditType: eventType,
      userId: this.userId,
      operationId: this.currentOperationId,
      timestamp: new Date().toISOString(),
      ...details
    };

    this.info(`AUDIT: ${eventType}`, auditContext);

    if (this.appInsights) {
      this.appInsights.trackEvent({
        name: `Audit_${eventType}`,
        properties: auditContext
      });
    }
  }

  /**
   * Flush all pending telemetry (useful before page unload)
   */
  flush(): void {
    if (this.appInsights) {
      this.appInsights.flush();
    }
  }

  // Private helper methods

  private shouldLog(level: LogLevel): boolean {
    if (this.logLevel === 'OFF') return false;

    const levels: LogLevel[] = ['ERROR', 'WARNING', 'INFO', 'DEBUG'];
    const currentLevelIndex = levels.indexOf(this.logLevel);
    const messageLevelIndex = levels.indexOf(level);

    return messageLevelIndex <= currentLevelIndex;
  }

  private log(level: LogLevel, message: string, context?: LogContext, error?: Error): void {
    const logContext = {
      ...context,
      userId: this.userId,
      operationId: this.currentOperationId || this.getOperationId(),
      timestamp: new Date().toISOString()
    };

    const logMessage = `[${level}] ${message}`;
    const consoleArgs: any[] = [logMessage, logContext];
    if (error) {
      consoleArgs.push(error);
    }

    // Console output
    switch (level) {
      case 'ERROR':
        console.error(...consoleArgs);
        break;
      case 'WARNING':
        console.warn(...consoleArgs);
        break;
      case 'DEBUG':
        console.debug(...consoleArgs);
        break;
      default:
        console.log(...consoleArgs);
    }

    // Application Insights trace
    if (this.appInsights && level !== 'DEBUG') { // Don't send DEBUG to App Insights to reduce noise
      const severityLevel = this.getSeverityLevel(level);
      this.appInsights.trackTrace({
        message: logMessage,
        severityLevel,
        properties: logContext
      });
    }
  }

  private getSeverityLevel(level: LogLevel): SeverityLevel {
    switch (level) {
      case 'ERROR':
        return SeverityLevel.Error;
      case 'WARNING':
        return SeverityLevel.Warning;
      case 'INFO':
        return SeverityLevel.Information;
      case 'DEBUG':
        return SeverityLevel.Verbose;
      default:
        return SeverityLevel.Information;
    }
  }

  private generateOperationId(): string {
    return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Log HTTP request
   */
  logHttpRequest(method: string, url: string, operationId: string, headers?: any, body?: any): void {
    const log: HttpLog = {
      timestamp: new Date(),
      type: 'request',
      method,
      url,
      operationId,
      requestHeaders: headers,
      requestBody: body
    };
    this.addHttpLog(log);
  }

  /**
   * Log HTTP response
   */
  logHttpResponse(
    method: string,
    url: string,
    status: number,
    duration: number,
    operationId: string,
    headers?: any,
    body?: any
  ): void {
    const log: HttpLog = {
      timestamp: new Date(),
      type: 'response',
      method,
      url,
      status,
      duration,
      operationId,
      responseHeaders: headers,
      responseBody: body
    };
    this.addHttpLog(log);
  }

  /**
   * Log HTTP error
   */
  logHttpError(
    method: string,
    url: string,
    status: number,
    duration: number,
    operationId: string,
    errorMessage: string,
    headers?: any
  ): void {
    const log: HttpLog = {
      timestamp: new Date(),
      type: 'error',
      method,
      url,
      status,
      duration,
      operationId,
      errorMessage,
      responseHeaders: headers
    };
    this.addHttpLog(log);
  }

  /**
   * Get all HTTP logs
   */
  getHttpLogs(): HttpLog[] {
    return [...this.httpLogs];
  }

  /**
   * Clear HTTP logs
   */
  clearHttpLogs(): void {
    this.httpLogs = [];
  }

  /**
   * Add HTTP log with circular buffer
   */
  private addHttpLog(log: HttpLog): void {
    this.httpLogs.push(log);
    // Keep only the last N logs
    if (this.httpLogs.length > this.maxHttpLogs) {
      this.httpLogs = this.httpLogs.slice(-this.maxHttpLogs);
    }
  }
}
