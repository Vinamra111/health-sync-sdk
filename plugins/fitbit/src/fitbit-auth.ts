/**
 * Fitbit OAuth 2.0 Authentication Module
 *
 * Implements Authorization Code Grant Flow with PKCE (RFC 7636)
 * Handles token management, refresh, and secure storage
 */

import { AuthenticationError } from '@healthsync/core';
import type {
  FitbitCredentials,
  FitbitApiConfig,
  FitbitTokenResponse,
  FitbitScope,
} from './fitbit-types';

/**
 * Token storage interface - implement based on environment
 */
export interface TokenStorage {
  saveTokens(credentials: FitbitCredentials): Promise<void>;
  loadTokens(): Promise<FitbitCredentials | null>;
  clearTokens(): Promise<void>;
}

/**
 * In-memory token storage (for testing/examples)
 * IMPORTANT: Use secure storage in production!
 */
export class InMemoryTokenStorage implements TokenStorage {
  private tokens: FitbitCredentials | null = null;

  async saveTokens(credentials: FitbitCredentials): Promise<void> {
    this.tokens = credentials;
  }

  async loadTokens(): Promise<FitbitCredentials | null> {
    return this.tokens;
  }

  async clearTokens(): Promise<void> {
    this.tokens = null;
  }
}

/**
 * PKCE utilities for OAuth 2.0
 */
export class PKCEGenerator {
  /**
   * Generate cryptographically random code verifier (43-128 characters)
   */
  static generateCodeVerifier(): string {
    const length = 128;
    const possible = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    const randomValues = new Uint8Array(length);

    // Use crypto.getRandomValues for cryptographic randomness
    if (typeof crypto !== 'undefined' && crypto.getRandomValues) {
      crypto.getRandomValues(randomValues);
    } else {
      // Fallback for Node.js
      const nodeCrypto = require('crypto');
      nodeCrypto.randomFillSync(randomValues);
    }

    let verifier = '';
    for (let i = 0; i < length; i++) {
      verifier += possible[randomValues[i] % possible.length];
    }

    return verifier;
  }

  /**
   * Generate code challenge from verifier using SHA-256
   * Returns base64url encoded hash
   */
  static async generateCodeChallenge(verifier: string): Promise<string> {
    // Convert verifier to ArrayBuffer
    const encoder = new TextEncoder();
    const data = encoder.encode(verifier);

    // Hash with SHA-256
    let hash: ArrayBuffer;
    if (typeof crypto !== 'undefined' && crypto.subtle) {
      // Browser
      hash = await crypto.subtle.digest('SHA-256', data);
    } else {
      // Node.js
      const nodeCrypto = require('crypto');
      const hashBuffer = nodeCrypto.createHash('sha256').update(verifier).digest();
      hash = hashBuffer.buffer.slice(
        hashBuffer.byteOffset,
        hashBuffer.byteOffset + hashBuffer.byteLength
      );
    }

    // Base64url encode (without padding)
    return this.base64UrlEncode(new Uint8Array(hash));
  }

  /**
   * Base64url encode without padding
   */
  private static base64UrlEncode(buffer: Uint8Array): string {
    const base64 = btoa(String.fromCharCode(...buffer));
    return base64
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '');
  }
}

/**
 * Fitbit OAuth 2.0 Authentication Handler
 */
export class FitbitAuth {
  private readonly config: Required<FitbitApiConfig>;
  private readonly storage: TokenStorage;
  private readonly authBaseUrl = 'https://www.fitbit.com/oauth2';
  private readonly apiBaseUrl = 'https://api.fitbit.com/oauth2';

  // Store code verifier temporarily during OAuth flow
  private pendingVerifier: string | null = null;

  constructor(
    config: FitbitApiConfig,
    storage?: TokenStorage
  ) {
    this.config = {
      clientId: config.clientId,
      clientSecret: config.clientSecret,
      redirectUri: config.redirectUri,
      scopes: config.scopes,
      baseUrl: config.baseUrl || 'https://api.fitbit.com',
      autoRefreshToken: config.autoRefreshToken !== false,
    };

    this.storage = storage || new InMemoryTokenStorage();
  }

  /**
   * Generate authorization URL for OAuth flow
   *
   * @returns Authorization URL and code verifier (store verifier securely!)
   */
  async generateAuthorizationUrl(
    scopes?: FitbitScope[],
    state?: string
  ): Promise<{ url: string; verifier: string }> {
    // Generate PKCE parameters
    const verifier = PKCEGenerator.generateCodeVerifier();
    const challenge = await PKCEGenerator.generateCodeChallenge(verifier);

    // Store verifier for token exchange
    this.pendingVerifier = verifier;

    // Build authorization URL
    const scopeString = (scopes || this.config.scopes).join(' ');
    const params = new URLSearchParams({
      client_id: this.config.clientId,
      response_type: 'code',
      code_challenge: challenge,
      code_challenge_method: 'S256',
      scope: scopeString,
      redirect_uri: this.config.redirectUri,
    });

    // Add optional state parameter for CSRF protection
    if (state) {
      params.append('state', state);
    }

    const url = `${this.authBaseUrl}/authorize?${params.toString()}`;

    return { url, verifier };
  }

  /**
   * Exchange authorization code for tokens
   *
   * @param code Authorization code from redirect
   * @param verifier Code verifier from generateAuthorizationUrl
   */
  async exchangeCodeForTokens(
    code: string,
    verifier?: string
  ): Promise<FitbitCredentials> {
    // Use provided verifier or pending one
    const codeVerifier = verifier || this.pendingVerifier;
    if (!codeVerifier) {
      throw new AuthenticationError(
        'Code verifier not found. Generate authorization URL first.',
        undefined,
        { code: 'MISSING_VERIFIER' }
      );
    }

    try {
      // Prepare token request
      const body = new URLSearchParams({
        client_id: this.config.clientId,
        grant_type: 'authorization_code',
        code: code,
        code_verifier: codeVerifier,
        redirect_uri: this.config.redirectUri,
      });

      // Make token request
      const response = await fetch(`${this.apiBaseUrl}/token`, {
        method: 'POST',
        headers: {
          'Authorization': `Basic ${this.encodeCredentials()}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body.toString(),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new AuthenticationError(
          error.errors?.[0]?.message || 'Token exchange failed',
          undefined,
          {
            code: 'TOKEN_EXCHANGE_FAILED',
            statusCode: response.status,
            fitbitError: error,
          }
        );
      }

      const tokenResponse: FitbitTokenResponse = await response.json();

      // Convert to credentials format
      const credentials = this.convertTokenResponse(tokenResponse);

      // Save tokens
      await this.storage.saveTokens(credentials);

      // Clear pending verifier
      this.pendingVerifier = null;

      return credentials;
    } catch (error) {
      this.pendingVerifier = null;

      if (error instanceof AuthenticationError) {
        throw error;
      }

      throw new AuthenticationError(
        `Failed to exchange code for tokens: ${(error as Error).message}`,
        error as Error,
        { code: 'TOKEN_EXCHANGE_ERROR' }
      );
    }
  }

  /**
   * Refresh access token using refresh token
   */
  async refreshAccessToken(refreshToken?: string): Promise<FitbitCredentials> {
    try {
      // Load current tokens if refresh token not provided
      let tokenToRefresh = refreshToken;
      if (!tokenToRefresh) {
        const stored = await this.storage.loadTokens();
        if (!stored) {
          throw new AuthenticationError(
            'No refresh token available',
            undefined,
            { code: 'NO_REFRESH_TOKEN' }
          );
        }
        tokenToRefresh = stored.refreshToken;
      }

      // Prepare refresh request
      const body = new URLSearchParams({
        grant_type: 'refresh_token',
        refresh_token: tokenToRefresh,
      });

      // Make refresh request
      const response = await fetch(`${this.apiBaseUrl}/token`, {
        method: 'POST',
        headers: {
          'Authorization': `Basic ${this.encodeCredentials()}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body.toString(),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new AuthenticationError(
          error.errors?.[0]?.message || 'Token refresh failed',
          undefined,
          {
            code: 'TOKEN_REFRESH_FAILED',
            statusCode: response.status,
            fitbitError: error,
          }
        );
      }

      const tokenResponse: FitbitTokenResponse = await response.json();

      // Convert to credentials format
      const credentials = this.convertTokenResponse(tokenResponse);

      // Save refreshed tokens
      await this.storage.saveTokens(credentials);

      return credentials;
    } catch (error) {
      if (error instanceof AuthenticationError) {
        throw error;
      }

      throw new AuthenticationError(
        `Failed to refresh token: ${(error as Error).message}`,
        error as Error,
        { code: 'TOKEN_REFRESH_ERROR' }
      );
    }
  }

  /**
   * Get valid access token (auto-refresh if expired)
   */
  async getValidAccessToken(): Promise<string> {
    const credentials = await this.storage.loadTokens();

    if (!credentials) {
      throw new AuthenticationError(
        'No tokens available. Please authenticate first.',
        undefined,
        { code: 'NOT_AUTHENTICATED' }
      );
    }

    // Check if token is expired (with 5 minute buffer)
    const expiresAt = new Date(credentials.expiresAt);
    const now = new Date();
    const bufferMs = 5 * 60 * 1000; // 5 minutes

    if (expiresAt.getTime() - now.getTime() < bufferMs) {
      // Token expired or expiring soon, refresh it
      if (this.config.autoRefreshToken) {
        const refreshed = await this.refreshAccessToken(credentials.refreshToken);
        return refreshed.accessToken;
      } else {
        throw new AuthenticationError(
          'Access token expired. Please refresh manually.',
          undefined,
          { code: 'TOKEN_EXPIRED' }
        );
      }
    }

    return credentials.accessToken;
  }

  /**
   * Check if we have valid tokens
   */
  async hasValidTokens(): Promise<boolean> {
    try {
      await this.getValidAccessToken();
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Check if token is expired
   */
  isTokenExpired(credentials: FitbitCredentials): boolean {
    const expiresAt = new Date(credentials.expiresAt);
    const now = new Date();
    return expiresAt.getTime() <= now.getTime();
  }

  /**
   * Revoke tokens (logout)
   */
  async revokeTokens(): Promise<void> {
    try {
      const credentials = await this.storage.loadTokens();
      if (!credentials) {
        return; // Already logged out
      }

      // Revoke access token
      await fetch(`${this.apiBaseUrl}/revoke`, {
        method: 'POST',
        headers: {
          'Authorization': `Basic ${this.encodeCredentials()}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          token: credentials.accessToken,
        }).toString(),
      });

      // Clear stored tokens
      await this.storage.clearTokens();
    } catch (error) {
      // Still clear tokens even if revocation fails
      await this.storage.clearTokens();

      throw new AuthenticationError(
        `Failed to revoke tokens: ${(error as Error).message}`,
        error as Error,
        { code: 'REVOKE_FAILED' }
      );
    }
  }

  /**
   * Get current credentials
   */
  async getCredentials(): Promise<FitbitCredentials | null> {
    return await this.storage.loadTokens();
  }

  // ============================================================================
  // Private Helper Methods
  // ============================================================================

  /**
   * Encode client credentials for Basic Auth
   */
  private encodeCredentials(): string {
    const credentials = `${this.config.clientId}:${this.config.clientSecret}`;

    // Base64 encode
    if (typeof btoa !== 'undefined') {
      return btoa(credentials);
    } else {
      // Node.js
      return Buffer.from(credentials).toString('base64');
    }
  }

  /**
   * Convert Fitbit token response to credentials format
   */
  private convertTokenResponse(response: FitbitTokenResponse): FitbitCredentials {
    const expiresInMs = response.expires_in * 1000;
    const expiresAt = new Date(Date.now() + expiresInMs);

    return {
      accessToken: response.access_token,
      refreshToken: response.refresh_token,
      expiresAt: expiresAt,
      userId: response.user_id,
      tokenType: response.token_type,
      scopes: response.scope.split(' ') as FitbitScope[],
    };
  }
}
