/**
 * Plugin Registry
 *
 * This module manages the registration, lifecycle, and retrieval of health data plugins.
 *
 * @module plugins/plugin-registry
 */

import { HealthSource } from '../models/unified-data';
import { IHealthDataPlugin, PluginInfo, ConnectionStatus } from './plugin-interface';
import { PluginError, ConfigurationError } from '../types/config';

/**
 * Plugin registry entry
 *
 * @interface PluginEntry
 */
interface PluginEntry {
  /** The plugin instance */
  plugin: IHealthDataPlugin;

  /** Whether the plugin is initialized */
  initialized: boolean;

  /** Current connection status */
  connectionStatus: ConnectionStatus;

  /** Timestamp when plugin was registered (ISO 8601) */
  registeredAt: string;

  /** Timestamp when plugin was last initialized (ISO 8601) */
  lastInitializedAt?: string;
}

/**
 * Plugin Registry
 *
 * Manages the lifecycle and organization of health data plugins.
 *
 * @class PluginRegistry
 */
export class PluginRegistry {
  /** Map of plugin ID to plugin entry */
  private plugins: Map<string, PluginEntry> = new Map();

  /** Map of health source to plugin ID */
  private sourceToPlugin: Map<HealthSource, string> = new Map();

  /**
   * Register a new plugin
   *
   * @param {IHealthDataPlugin} plugin - The plugin to register
   * @throws {PluginError} If plugin with same ID already exists
   * @returns {void}
   */
  register(plugin: IHealthDataPlugin): void {
    if (this.plugins.has(plugin.id)) {
      throw new PluginError(
        `Plugin with ID '${plugin.id}' is already registered`,
        plugin.id,
        400
      );
    }

    // Validate plugin implements required properties
    if (!plugin.id || !plugin.name || !plugin.version) {
      throw new ConfigurationError(
        'Plugin must have id, name, and version properties',
        { pluginId: plugin.id }
      );
    }

    const entry: PluginEntry = {
      plugin,
      initialized: false,
      connectionStatus: ConnectionStatus.DISCONNECTED,
      registeredAt: new Date().toISOString(),
    };

    this.plugins.set(plugin.id, entry);

    // Map health source to plugin (assuming plugin ID matches source for now)
    // This can be enhanced to support multiple sources per plugin
    const source = this.pluginIdToHealthSource(plugin.id);
    if (source) {
      this.sourceToPlugin.set(source, plugin.id);
    }
  }

  /**
   * Unregister a plugin
   *
   * @param {string} pluginId - ID of the plugin to unregister
   * @returns {Promise<void>}
   * @throws {PluginError} If plugin is not found
   */
  async unregister(pluginId: string): Promise<void> {
    const entry = this.plugins.get(pluginId);
    if (!entry) {
      throw new PluginError(`Plugin '${pluginId}' not found`, pluginId, 404);
    }

    // Dispose plugin if initialized
    if (entry.initialized) {
      try {
        await entry.plugin.dispose();
      } catch (error) {
        // Log error but continue with unregistration
        console.error(`Error disposing plugin '${pluginId}':`, error);
      }
    }

    // Remove from maps
    this.plugins.delete(pluginId);

    // Remove source mapping
    for (const [source, id] of this.sourceToPlugin.entries()) {
      if (id === pluginId) {
        this.sourceToPlugin.delete(source);
      }
    }
  }

  /**
   * Get a plugin by ID
   *
   * @param {string} pluginId - ID of the plugin
   * @returns {IHealthDataPlugin | undefined} The plugin instance or undefined
   */
  getPlugin(pluginId: string): IHealthDataPlugin | undefined {
    return this.plugins.get(pluginId)?.plugin;
  }

  /**
   * Get a plugin by health source
   *
   * @param {HealthSource} source - Health source
   * @returns {IHealthDataPlugin | undefined} The plugin instance or undefined
   */
  getPluginBySource(source: HealthSource): IHealthDataPlugin | undefined {
    const pluginId = this.sourceToPlugin.get(source);
    if (!pluginId) {
      return undefined;
    }
    return this.getPlugin(pluginId);
  }

  /**
   * Get all registered plugins
   *
   * @returns {IHealthDataPlugin[]} Array of all plugins
   */
  getAllPlugins(): IHealthDataPlugin[] {
    return Array.from(this.plugins.values()).map((entry) => entry.plugin);
  }

  /**
   * Get all initialized plugins
   *
   * @returns {IHealthDataPlugin[]} Array of initialized plugins
   */
  getInitializedPlugins(): IHealthDataPlugin[] {
    return Array.from(this.plugins.values())
      .filter((entry) => entry.initialized)
      .map((entry) => entry.plugin);
  }

  /**
   * Get all connected plugins
   *
   * @returns {IHealthDataPlugin[]} Array of connected plugins
   */
  getConnectedPlugins(): IHealthDataPlugin[] {
    return Array.from(this.plugins.values())
      .filter((entry) => entry.connectionStatus === ConnectionStatus.CONNECTED)
      .map((entry) => entry.plugin);
  }

  /**
   * Get plugin info for all plugins
   *
   * @returns {Promise<PluginInfo[]>} Array of plugin info
   */
  async getPluginInfo(): Promise<PluginInfo[]> {
    const plugins = this.getAllPlugins();
    const infoPromises = plugins.map(async (plugin) => {
      if (plugin.getInfo) {
        return plugin.getInfo();
      }
      // Fallback to basic info
      return {
        id: plugin.id,
        name: plugin.name,
        version: plugin.version,
        supportedDataTypes: plugin.supportedDataTypes,
        requiresAuthentication: plugin.requiresAuthentication,
        isCloudBased: plugin.isCloudBased,
      };
    });

    return Promise.all(infoPromises);
  }

  /**
   * Check if a plugin is initialized
   *
   * @param {string} pluginId - ID of the plugin
   * @returns {boolean} True if plugin is initialized
   */
  isInitialized(pluginId: string): boolean {
    return this.plugins.get(pluginId)?.initialized ?? false;
  }

  /**
   * Mark a plugin as initialized
   *
   * @param {string} pluginId - ID of the plugin
   * @returns {void}
   * @throws {PluginError} If plugin is not found
   */
  markInitialized(pluginId: string): void {
    const entry = this.plugins.get(pluginId);
    if (!entry) {
      throw new PluginError(`Plugin '${pluginId}' not found`, pluginId, 404);
    }

    entry.initialized = true;
    entry.lastInitializedAt = new Date().toISOString();
  }

  /**
   * Update plugin connection status
   *
   * @param {string} pluginId - ID of the plugin
   * @param {ConnectionStatus} status - New connection status
   * @returns {void}
   * @throws {PluginError} If plugin is not found
   */
  updateConnectionStatus(pluginId: string, status: ConnectionStatus): void {
    const entry = this.plugins.get(pluginId);
    if (!entry) {
      throw new PluginError(`Plugin '${pluginId}' not found`, pluginId, 404);
    }

    entry.connectionStatus = status;
  }

  /**
   * Get plugin connection status
   *
   * @param {string} pluginId - ID of the plugin
   * @returns {ConnectionStatus} Connection status
   * @throws {PluginError} If plugin is not found
   */
  getConnectionStatus(pluginId: string): ConnectionStatus {
    const entry = this.plugins.get(pluginId);
    if (!entry) {
      throw new PluginError(`Plugin '${pluginId}' not found`, pluginId, 404);
    }

    return entry.connectionStatus;
  }

  /**
   * Get the number of registered plugins
   *
   * @returns {number} Number of plugins
   */
  count(): number {
    return this.plugins.size;
  }

  /**
   * Clear all plugins
   *
   * Disposes all plugins and clears the registry.
   *
   * @returns {Promise<void>}
   */
  async clear(): Promise<void> {
    const disposePromises = Array.from(this.plugins.values()).map(async (entry) => {
      if (entry.initialized) {
        try {
          await entry.plugin.dispose();
        } catch (error) {
          console.error(`Error disposing plugin '${entry.plugin.id}':`, error);
        }
      }
    });

    await Promise.all(disposePromises);

    this.plugins.clear();
    this.sourceToPlugin.clear();
  }

  /**
   * Convert plugin ID to health source
   *
   * This is a helper method that maps plugin IDs to health sources.
   * Can be extended to support custom mappings.
   *
   * @param {string} pluginId - Plugin ID
   * @returns {HealthSource | undefined} Corresponding health source
   * @private
   */
  private pluginIdToHealthSource(pluginId: string): HealthSource | undefined {
    const mapping: Record<string, HealthSource> = {
      'health-connect': HealthSource.HEALTH_CONNECT,
      'health_connect': HealthSource.HEALTH_CONNECT,
      'apple-health': HealthSource.APPLE_HEALTH,
      'apple_health': HealthSource.APPLE_HEALTH,
      'healthkit': HealthSource.APPLE_HEALTH,
      fitbit: HealthSource.FITBIT,
      garmin: HealthSource.GARMIN,
      oura: HealthSource.OURA,
      whoop: HealthSource.WHOOP,
      strava: HealthSource.STRAVA,
      myfitnesspal: HealthSource.MYFITNESSPAL,
    };

    return mapping[pluginId.toLowerCase()];
  }
}
