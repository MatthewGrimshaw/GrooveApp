/**
 * Logging Interceptor for HTTP requests
 * Automatically logs all API calls with timing and correlation
 */
import { HttpErrorResponse, HttpInterceptorFn, HttpResponse } from '@angular/common/http';
import { inject } from '@angular/core';
import { tap } from 'rxjs/operators';
import { LoggingService } from '../services/logging.service';

export const loggingInterceptor: HttpInterceptorFn = (req, next) => {
  const loggingService = inject(LoggingService);
  const startTime = Date.now();
  const operationId = loggingService.getOperationId();

  // Add operation ID to request headers for backend correlation
  const modifiedReq = req.clone({
    setHeaders: {
      'X-Operation-ID': operationId
    }
  });

  loggingService.debug(`HTTP Request: ${req.method} ${req.url}`, {
    method: req.method,
    url: req.url,
    operationId: operationId,
    component: 'HttpInterceptor'
  });

  // Log HTTP request details
  loggingService.logHttpRequest(
    req.method,
    req.url,
    operationId,
    Object.fromEntries(
      req.headers.keys().map(key => [key, req.headers.get(key)])
    ),
    req.body
  );

  return next(modifiedReq).pipe(
    tap({
      next: (event) => {
        if (event instanceof HttpResponse) {
          const duration = Date.now() - startTime;

          // Extract operation ID from response if backend provides it
          const backendOperationId = event.headers.get('X-Operation-ID');
          if (backendOperationId) {
            loggingService.setOperationId(backendOperationId);
          }

          loggingService.debug(`HTTP Response: ${req.method} ${req.url} - ${event.status} (${duration}ms)`, {
            method: req.method,
            url: req.url,
            statusCode: event.status,
            duration: duration,
            operationId: backendOperationId || operationId,
            component: 'HttpInterceptor'
          });

          // Log HTTP response details
          loggingService.logHttpResponse(
            req.method,
            req.url,
            event.status,
            duration,
            backendOperationId || operationId,
            Object.fromEntries(
              event.headers.keys().map(key => [key, event.headers.get(key)])
            ),
            event.body
          );

          // Track dependency in Application Insights
          loggingService.trackDependency(
            operationId,
            req.method,
            req.url,
            duration,
            event.status >= 200 && event.status < 400,
            event.status,
            {
              backendOperationId: backendOperationId
            }
          );

          // Clear operation ID after request completes
          loggingService.clearOperationId();
        }
      },
      error: (error: any) => {
        const duration = Date.now() - startTime;

        if (error instanceof HttpErrorResponse) {
          const backendOperationId = error.headers?.get('X-Operation-ID');

          loggingService.error(
            `HTTP Error: ${req.method} ${req.url} - ${error.status} (${duration}ms)`,
            error,
            {
              method: req.method,
              url: req.url,
              statusCode: error.status,
              statusText: error.statusText,
              duration: duration,
              operationId: backendOperationId || operationId,
              errorMessage: error.message,
              component: 'HttpInterceptor'
            }
          );

          // Log HTTP error details
          loggingService.logHttpError(
            req.method,
            req.url,
            error.status,
            duration,
            backendOperationId || operationId,
            error.message,
            error.headers ? Object.fromEntries(
              error.headers.keys().map(key => [key, error.headers.get(key)])
            ) : undefined
          );

          // Track failed dependency
          loggingService.trackDependency(
            operationId,
            req.method,
            req.url,
            duration,
            false,
            error.status,
            {
              backendOperationId: backendOperationId,
              errorMessage: error.message
            }
          );
        } else {
          loggingService.error(
            `HTTP Error: ${req.method} ${req.url} (${duration}ms)`,
            error,
            {
              method: req.method,
              url: req.url,
              duration: duration,
              operationId: operationId,
              component: 'HttpInterceptor'
            }
          );
        }

        // Clear operation ID after error
        loggingService.clearOperationId();
      }
    })
  );
};
