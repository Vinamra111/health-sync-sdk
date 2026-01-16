/**
 * Event Emitter Tests
 *
 * Tests for type-safe event emitter
 */

import { EventEmitter } from '../../src/utils/event-emitter';

type TestEvents = {
  message: { text: string };
  count: { value: number };
  data: { id: string; payload: unknown };
};

describe('EventEmitter', () => {
  let emitter: EventEmitter<TestEvents>;

  beforeEach(() => {
    emitter = new EventEmitter<TestEvents>();
  });

  afterEach(() => {
    emitter.clear();
  });

  describe('on / emit', () => {
    it('should emit and receive events', async () => {
      const handler = jest.fn();

      emitter.on('message', handler);
      await emitter.emit('message', { text: 'hello' });

      expect(handler).toHaveBeenCalledWith({ text: 'hello' });
      expect(handler).toHaveBeenCalledTimes(1);
    });

    it('should call multiple listeners for same event', async () => {
      const handler1 = jest.fn();
      const handler2 = jest.fn();

      emitter.on('message', handler1);
      emitter.on('message', handler2);

      await emitter.emit('message', { text: 'hello' });

      expect(handler1).toHaveBeenCalledTimes(1);
      expect(handler2).toHaveBeenCalledTimes(1);
    });

    it('should handle multiple event types', async () => {
      const messageHandler = jest.fn();
      const countHandler = jest.fn();

      emitter.on('message', messageHandler);
      emitter.on('count', countHandler);

      await emitter.emit('message', { text: 'hello' });
      await emitter.emit('count', { value: 42 });

      expect(messageHandler).toHaveBeenCalledWith({ text: 'hello' });
      expect(countHandler).toHaveBeenCalledWith({ value: 42 });
    });

    it('should handle async listeners', async () => {
      const handler = jest.fn(async (data: { text: string }) => {
        await new Promise(resolve => setTimeout(resolve, 10));
        return data.text;
      });

      emitter.on('message', handler);
      await emitter.emit('message', { text: 'async' });

      expect(handler).toHaveBeenCalled();
    });

    it('should handle listener errors gracefully', async () => {
      const errorHandler = jest.fn(() => {
        throw new Error('Handler error');
      });
      const normalHandler = jest.fn();

      emitter.on('message', errorHandler);
      emitter.on('message', normalHandler);

      // Should not throw
      await expect(emitter.emit('message', { text: 'test' })).resolves.not.toThrow();

      expect(errorHandler).toHaveBeenCalled();
      expect(normalHandler).toHaveBeenCalled();
    });
  });

  describe('once', () => {
    it('should only fire listener once', async () => {
      const handler = jest.fn();

      emitter.once('message', handler);

      await emitter.emit('message', { text: 'first' });
      await emitter.emit('message', { text: 'second' });

      expect(handler).toHaveBeenCalledTimes(1);
      expect(handler).toHaveBeenCalledWith({ text: 'first' });
    });

    it('should auto-unsubscribe after first emit', async () => {
      const handler = jest.fn();

      const subscription = emitter.once('message', handler);

      await emitter.emit('message', { text: 'test' });

      expect(subscription.isActive()).toBe(false);
    });
  });

  describe('off / unsubscribe', () => {
    it('should remove listener with off', async () => {
      const handler = jest.fn();

      emitter.on('message', handler);
      emitter.off('message', handler);

      await emitter.emit('message', { text: 'test' });

      expect(handler).not.toHaveBeenCalled();
    });

    it('should remove listener via subscription', async () => {
      const handler = jest.fn();

      const subscription = emitter.on('message', handler);
      subscription.unsubscribe();

      await emitter.emit('message', { text: 'test' });

      expect(handler).not.toHaveBeenCalled();
      expect(subscription.isActive()).toBe(false);
    });

    it('should handle unsubscribe multiple times safely', () => {
      const handler = jest.fn();

      const subscription = emitter.on('message', handler);

      subscription.unsubscribe();
      subscription.unsubscribe();

      expect(subscription.isActive()).toBe(false);
    });

    it('should remove only specified listener', async () => {
      const handler1 = jest.fn();
      const handler2 = jest.fn();

      emitter.on('message', handler1);
      emitter.on('message', handler2);

      emitter.off('message', handler1);

      await emitter.emit('message', { text: 'test' });

      expect(handler1).not.toHaveBeenCalled();
      expect(handler2).toHaveBeenCalled();
    });
  });

  describe('clear', () => {
    it('should remove all listeners', async () => {
      const handler1 = jest.fn();
      const handler2 = jest.fn();

      emitter.on('message', handler1);
      emitter.on('count', handler2);

      emitter.clear();

      await emitter.emit('message', { text: 'test' });
      await emitter.emit('count', { value: 1 });

      expect(handler1).not.toHaveBeenCalled();
      expect(handler2).not.toHaveBeenCalled();
    });

    it('should mark all subscriptions as inactive', () => {
      const sub1 = emitter.on('message', jest.fn());
      const sub2 = emitter.on('count', jest.fn());

      emitter.clear();

      expect(sub1.isActive()).toBe(false);
      expect(sub2.isActive()).toBe(false);
    });
  });

  describe('listenerCount', () => {
    it('should return correct listener count', () => {
      expect(emitter.listenerCount('message')).toBe(0);

      emitter.on('message', jest.fn());
      expect(emitter.listenerCount('message')).toBe(1);

      emitter.on('message', jest.fn());
      expect(emitter.listenerCount('message')).toBe(2);
    });

    it('should update count after unsubscribe', () => {
      const sub = emitter.on('message', jest.fn());

      expect(emitter.listenerCount('message')).toBe(1);

      sub.unsubscribe();

      expect(emitter.listenerCount('message')).toBe(0);
    });
  });

  describe('hasListeners', () => {
    it('should return true when listeners exist', () => {
      expect(emitter.hasListeners('message')).toBe(false);

      emitter.on('message', jest.fn());

      expect(emitter.hasListeners('message')).toBe(true);
    });

    it('should return false after all listeners removed', () => {
      const sub1 = emitter.on('message', jest.fn());
      const sub2 = emitter.on('message', jest.fn());

      expect(emitter.hasListeners('message')).toBe(true);

      sub1.unsubscribe();
      sub2.unsubscribe();

      expect(emitter.hasListeners('message')).toBe(false);
    });
  });

  describe('Edge Cases', () => {
    it('should handle emitting with no listeners', async () => {
      await expect(emitter.emit('message', { text: 'test' })).resolves.not.toThrow();
    });

    it('should handle removing non-existent listener', () => {
      const handler = jest.fn();

      expect(() => emitter.off('message', handler)).not.toThrow();
    });

    it.skip('should handle same listener added multiple times', async () => {
      const handler = jest.fn();

      emitter.on('message', handler);
      emitter.on('message', handler);
      emitter.on('message', handler);

      await emitter.emit('message', { text: 'test' });

      expect(handler).toHaveBeenCalledTimes(3);
    });

    it('should maintain listener order', async () => {
      const callOrder: number[] = [];

      emitter.on('message', () => callOrder.push(1));
      emitter.on('message', () => callOrder.push(2));
      emitter.on('message', () => callOrder.push(3));

      await emitter.emit('message', { text: 'test' });

      expect(callOrder).toEqual([1, 2, 3]);
    });
  });
});
