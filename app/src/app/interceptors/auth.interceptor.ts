import { HttpInterceptorFn } from '@angular/common/http';
import { environment } from '../../environments/environment';

/**
 * HTTP Interceptor to include credentials (cookies/auth tokens) with cross-origin requests
 * This enables Easy Auth token sharing between frontend and API web apps
 */
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  // Only add credentials for requests to our API
  if (req.url.startsWith(environment.apiUrl)) {
    const authReq = req.clone({
      withCredentials: true
    });
    return next(authReq);
  }

  return next(req);
};
