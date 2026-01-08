import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { APP_INITIALIZER, ApplicationConfig, ErrorHandler } from '@angular/core';
import { authInterceptor } from './interceptors/auth.interceptor';
import { loggingInterceptor } from './interceptors/logging.interceptor';
import { ConfigService } from './services/config.service';
import { GlobalErrorHandler } from './services/global-error-handler.service';

export function initializeApp(configService: ConfigService) {
  return () => configService.loadConfig();
}

export const appConfig: ApplicationConfig = {
  providers: [
    provideHttpClient(
      withInterceptors([
        loggingInterceptor,  // Add logging interceptor first for complete request tracking
        authInterceptor
      ])
    ),
    // Global error handler for unhandled exceptions
    { provide: ErrorHandler, useClass: GlobalErrorHandler },
    // Load runtime configuration before app starts
    {
      provide: APP_INITIALIZER,
      useFactory: initializeApp,
      deps: [ConfigService],
      multi: true
    }
  ]
};
