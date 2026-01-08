import { Injectable } from '@angular/core';

export interface RuntimeConfig {
  apiUrl: string;
  appInsightsConnectionString: string;
  logLevel: string;
}

declare global {
  interface Window {
    runtimeConfig?: RuntimeConfig;
  }
}

@Injectable({
  providedIn: 'root'
})
export class ConfigService {
  private config: RuntimeConfig | null = null;

  constructor() {}

  async loadConfig(): Promise<void> {
    // Check if runtime config is available from index.html
    if (window.runtimeConfig) {
      this.config = window.runtimeConfig;
      console.log('Runtime configuration loaded:', this.config);
    } else {
      console.warn('No runtime configuration found');
      this.config = null;
    }
  }

  get apiUrl(): string {
    return this.config?.apiUrl || '';
  }

  get appInsightsConnectionString(): string {
    return this.config?.appInsightsConnectionString || '';
  }

  get logLevel(): string {
    return this.config?.logLevel || 'INFO';
  }
}
