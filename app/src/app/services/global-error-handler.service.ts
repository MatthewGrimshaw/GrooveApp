/**
 * Global Error Handler for Angular Application
 * Catches unhandled errors and logs them to Application Insights
 */
import { ErrorHandler, Injectable, inject } from '@angular/core';
import { LoggingService } from '../services/logging.service';

@Injectable()
export class GlobalErrorHandler implements ErrorHandler {
  private loggingService = inject(LoggingService);

  handleError(error: Error): void {
    // Log the error with full details
    this.loggingService.error(
      `Unhandled Error: ${error.message}`,
      error,
      {
        component: 'GlobalErrorHandler',
        stack: error.stack,
        errorType: error.name
      }
    );

    // Still log to console for development
    console.error('Unhandled error:', error);
  }
}
