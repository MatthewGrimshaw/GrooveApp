import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { from, switchMap } from 'rxjs';
import { environment } from '../../environments/environment';
import { ConfigService } from '../services/config.service';

/**
 * HTTP Interceptor to include authentication token with API requests
 * Gets the access token from Easy Auth's /.auth/me endpoint and includes it as Bearer token
 */
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const configService = inject(ConfigService);
  const apiUrl = configService.apiUrl || environment.apiUrl;

  // Only add auth for requests to our API
  if (req.url.startsWith(apiUrl)) {
    // Get the access token from Easy Auth
    return from(getAccessToken()).pipe(
      switchMap(token => {
        const authReq = req.clone({
          withCredentials: true,
          setHeaders: token ? {
            'Authorization': `Bearer ${token}`
          } : {}
        });
        return next(authReq);
      })
    );
  }

  return next(req);
};

/**
 * Gets the access token from Easy Auth's /.auth/me endpoint
 * When login_parameters are configured to request API tokens,
 * the access_token will have the correct audience for the API
 */
async function getAccessToken(): Promise<string | null> {
  try {
    const response = await fetch('/.auth/me', {
      credentials: 'include'
    });

    if (!response.ok) {
      console.warn('Failed to get auth info from /.auth/me');
      return null;
    }

    const authInfo = await response.json();

    // The token is in the first item's access_token field
    if (authInfo && authInfo.length > 0 && authInfo[0].access_token) {
      const token = authInfo[0].access_token;
      console.log('Access token obtained for API call');
      return token;
    }

    console.warn('No access token found in /.auth/me response');
    return null;
  } catch (error) {
    console.error('Error fetching access token:', error);
    return null;
  }
}
