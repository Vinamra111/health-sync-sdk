/**
 * Event Emitter
 *
 * Simple event emitter implementation for SDK event subscriptions.
 * Zero dependencies, type-safe event handling.
 *
 * @module utils/event-emitter
 */

/**
 * Event listener function type
 *
 * @callback EventListener
 * @template T
 * @param {T} data - Event data
 * @returns {void | Promise<void>}
 */
export type EventListener<T = unknown> = (data: T) => void | Promise<void>;

/**
 * Event subscription
 *
 * @interface EventSubscription
 */
export interface EventSubscription {
  /** Unique subscription ID */
  id: string;

  /** Unsubscribe from the event */
  unsubscribe: () => void;

  /** Whether the subscription is active */
  isActive: () => boolean;
}

/**
 * Event Emitter
 *
 * Provides type-safe event emission and subscription.
 *
 * @class EventEmitter
 * @template TEvents - Map of event names to event data types
 */
export class EventEmitter<TEvents extends Record<string, unknown> = Record<string, unknown>> {
  /** Map of event names to listeners */
  private listeners: Map<keyof TEvents, Set<EventListener>> = new Map();

  /** Subscription counter for unique IDs */
  private subscriptionCounter = 0;

  /** Map of subscription IDs to unsubscribe functions */
  private subscriptions: Map<string, () => void> = new Map();

  /**
   * Subscribe to an event
   *
   * @template K - Event name type
   * @param {K} event - Event name
   * @param {EventListener<TEvents[K]>} listener - Event listener function
   * @returns {EventSubscription} Subscription object
   */
  on<K extends keyof TEvents>(
    event: K,
    listener: EventListener<TEvents[K]>
  ): EventSubscription {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }

    const listeners = this.listeners.get(event);
    if (listeners) {
      listeners.add(listener as EventListener);
    }

    // Generate unique subscription ID
    const subscriptionId = `sub_${++this.subscriptionCounter}_${String(event)}`;

    // Create unsubscribe function
    const unsubscribe = (): void => {
      this.off(event, listener);
      this.subscriptions.delete(subscriptionId);
    };

    this.subscriptions.set(subscriptionId, unsubscribe);

    return {
      id: subscriptionId,
      unsubscribe,
      isActive: () => this.subscriptions.has(subscriptionId),
    };
  }

  /**
   * Subscribe to an event (alias for `on`)
   *
   * @template K - Event name type
   * @param {K} event - Event name
   * @param {EventListener<TEvents[K]>} listener - Event listener function
   * @returns {EventSubscription} Subscription object
   */
  subscribe<K extends keyof TEvents>(
    event: K,
    listener: EventListener<TEvents[K]>
  ): EventSubscription {
    return this.on(event, listener);
  }

  /**
   * Unsubscribe from an event
   *
   * @template K - Event name type
   * @param {K} event - Event name
   * @param {EventListener<TEvents[K]>} listener - Event listener function to remove
   * @returns {void}
   */
  off<K extends keyof TEvents>(event: K, listener: EventListener<TEvents[K]>): void {
    const listeners = this.listeners.get(event);
    if (listeners) {
      listeners.delete(listener as EventListener);

      // Clean up empty listener sets
      if (listeners.size === 0) {
        this.listeners.delete(event);
      }
    }
  }

  /**
   * Subscribe to an event once (automatically unsubscribes after first emission)
   *
   * @template K - Event name type
   * @param {K} event - Event name
   * @param {EventListener<TEvents[K]>} listener - Event listener function
   * @returns {EventSubscription} Subscription object
   */
  once<K extends keyof TEvents>(
    event: K,
    listener: EventListener<TEvents[K]>
  ): EventSubscription {
    const wrappedListener: EventListener<TEvents[K]> = async (data) => {
      subscription.unsubscribe();
      const result = listener(data);
      if (result instanceof Promise) {
        await result;
      }
    };

    const subscription = this.on(event, wrappedListener);
    return subscription;
  }

  /**
   * Emit an event
   *
   * Calls all listeners registered for the event with the provided data.
   * Errors in listeners are caught and logged but do not stop other listeners.
   *
   * @template K - Event name type
   * @param {K} event - Event name
   * @param {TEvents[K]} data - Event data
   * @returns {Promise<void>}
   */
  async emit<K extends keyof TEvents>(event: K, data: TEvents[K]): Promise<void> {
    const listeners = this.listeners.get(event);
    if (!listeners || listeners.size === 0) {
      return;
    }

    // Call all listeners
    const promises = Array.from(listeners).map(async (listener) => {
      try {
        const result = listener(data);
        if (result instanceof Promise) {
          await result;
        }
      } catch (error) {
        // Log error but don't stop other listeners
        console.error(`Error in event listener for '${String(event)}':`, error);
      }
    });

    await Promise.all(promises);
  }

  /**
   * Emit an event synchronously (does not wait for promises)
   *
   * @template K - Event name type
   * @param {K} event - Event name
   * @param {TEvents[K]} data - Event data
   * @returns {void}
   */
  emitSync<K extends keyof TEvents>(event: K, data: TEvents[K]): void {
    const listeners = this.listeners.get(event);
    if (!listeners || listeners.size === 0) {
      return;
    }

    // Call all listeners without awaiting
    listeners.forEach((listener) => {
      try {
        listener(data);
      } catch (error) {
        console.error(`Error in event listener for '${String(event)}':`, error);
      }
    });
  }

  /**
   * Remove all listeners for a specific event
   *
   * @template K - Event name type
   * @param {K} event - Event name
   * @returns {void}
   */
  removeAllListeners<K extends keyof TEvents>(event: K): void {
    // Remove subscriptions
    const listeners = this.listeners.get(event);
    if (listeners) {
      this.subscriptions.forEach((_unsubscribe, id) => {
        if (id.endsWith(`_${String(event)}`)) {
          this.subscriptions.delete(id);
        }
      });
    }

    this.listeners.delete(event);
  }

  /**
   * Remove all listeners for all events
   *
   * @returns {void}
   */
  clear(): void {
    this.listeners.clear();
    this.subscriptions.clear();
  }

  /**
   * Get the number of listeners for an event
   *
   * @template K - Event name type
   * @param {K} event - Event name
   * @returns {number} Number of listeners
   */
  listenerCount<K extends keyof TEvents>(event: K): number {
    return this.listeners.get(event)?.size ?? 0;
  }

  /**
   * Get all event names that have listeners
   *
   * @returns {Array<keyof TEvents>} Array of event names
   */
  eventNames(): Array<keyof TEvents> {
    return Array.from(this.listeners.keys());
  }

  /**
   * Check if there are any listeners for an event
   *
   * @template K - Event name type
   * @param {K} event - Event name
   * @returns {boolean} True if there are listeners
   */
  hasListeners<K extends keyof TEvents>(event: K): boolean {
    return this.listenerCount(event) > 0;
  }
}
