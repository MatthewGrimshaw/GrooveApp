import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { environment } from '../../environments/environment';
import { ConfigService } from '../services/config.service';

/**
 * HTTP Interceptor to include credentials (cookies/auth tokens) with cross-origin requests
 * This enables Easy Auth token sharing between frontend and API web apps
 */
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const configService = inject(ConfigService);
  const apiUrl = configService.apiUrl || environment.apiUrl;

  // Only add credentials for requests to our API
  if (req.url.startsWith(apiUrl)) {
    const authReq = req.clone({
      withCredentials: true
    });
    return next(authReq);
  }

  return next(req);
};
