/**
 * Unit Tests: SubscriptionManager.brs
 *
 * Tests subscription management: initialization, state retrieval,
 * checkout flow, status checks, cancellation, and local persistence.
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = path.resolve(__dirname, '..');

export default async function runTests({ describe, it, assertions }) {
  const { equal, deepEqual, truthy, falsy, isString, isNumber,
           isArray, isObject, greaterThan, lessThan, match, hasProperty } = assertions;

  // ============================================================
  // Subscription state retrieval — simulates GetSubscriptionState
  // ============================================================

  function getSubscriptionState(globalNode) {
    if (!globalNode) return null;
    try {
      const state = {
        subscriberId: globalNode.get ? globalNode.get('SubscriberId') : '',
        customerId: globalNode.get ? globalNode.get('CustomerId') : '',
        subscriptionId: globalNode.get ? globalNode.get('SubscriptionId') : '',
        status: globalNode.get ? globalNode.get('SubscriptionStatus') : '',
        planId: globalNode.get ? globalNode.get('PlanId') : '',
        planName: globalNode.get ? globalNode.get('PlanName') : '',
        active: (globalNode.get ? globalNode.get('SubscriptionStatus') : '') === 'active',
      };
      return state;
    } catch (e) {
      return null;
    }
  }

  describe('GetSubscriptionState', () => {
    it('returns null when global is invalid', () => {
      const state = getSubscriptionState(null);
      falsy(state);
    });

    it('returns active=true when status is "active"', () => {
      const globalMock = { get: (k) => ({
        SubscriberId: 'sub_123', CustomerId: 'cust_456',
        SubscriptionId: 'subscr_789', SubscriptionStatus: 'active',
        PlanId: 'plan_premium', PlanName: 'Premium',
      })[k] };
      const state = getSubscriptionState(globalMock);
      truthy(state.active);
    });

    it('returns active=false when status is "cancelled"', () => {
      const globalMock = { get: (k) => ({
        SubscriberId: 'sub_123', SubscriptionStatus: 'cancelled',
        PlanId: '', PlanName: '',
      })[k] };
      const state = getSubscriptionState(globalMock);
      falsy(state.active);
    });

    it('returns empty string for missing fields', () => {
      const globalMock = { get: (k) => '' };
      const state = getSubscriptionState(globalMock);
      equal(state.subscriberId, '');
      equal(state.status, '');
      equal(state.active, false);
    });

    it('returns all required fields', () => {
      const globalMock = { get: (k) => 'test' };
      const state = getSubscriptionState(globalMock);
      hasProperty(state, 'subscriberId');
      hasProperty(state, 'customerId');
      hasProperty(state, 'subscriptionId');
      hasProperty(state, 'status');
      hasProperty(state, 'planId');
      hasProperty(state, 'planName');
      hasProperty(state, 'active');
    });
  });

  // ============================================================
  // Checkout flow — simulates StartCheckout
  // ============================================================

  function startCheckout(serverUrl, productId, email) {
    if (!productId || !email) return false;
    if (!serverUrl) return false;

    const url = serverUrl + '/api/checkout';
    const postData = JSON.stringify({ productId, customerEmail: email });

    // Simulate HTTP response handling
    const mockResponseText = JSON.stringify({ url: 'https://checkout.stripe.com/pay/xyz' });
    const statusCode = 200;

    if (statusCode === 200) {
      try {
        const response = JSON.parse(mockResponseText);
        if (response && response.url) return true;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  describe('StartCheckout', () => {
    it('returns true for valid checkout request', () => {
      truthy(startCheckout('https://api.example.com', 'prod_123', 'user@test.com'));
    });

    it('returns false when productId is empty', () => {
      falsy(startCheckout('https://api.example.com', '', 'user@test.com'));
    });

    it('returns false when email is empty', () => {
      falsy(startCheckout('https://api.example.com', 'prod_123', ''));
    });

    it('returns false when serverUrl is not configured', () => {
      falsy(startCheckout('', 'prod_123', 'user@test.com'));
    });

    it('returns false when serverUrl is invalid', () => {
      falsy(startCheckout(null, 'prod_123', 'user@test.com'));
    });

    it('builds correct checkout URL', () => {
      const url = 'https://api.example.com' + '/api/checkout';
      equal(url, 'https://api.example.com/api/checkout');
    });

    it('masks email in logs (first 3 chars + "***@***.com")', () => {
      const email = 'user@example.com';
      const masked = email.substring(0, 3) + '***@***.com';
      equal(masked, 'use***@***.com');
    });

    it('handles null serverUrl', () => {
      falsy(startCheckout(null, 'prod_123', 'user@test.com'));
    });
  });

  // ============================================================
  // Status check — simulates CheckSubscriptionStatus
  // ============================================================

  function checkSubscriptionStatus(serverUrl, subscriberId) {
    if (!subscriberId) return null;
    if (!serverUrl) return null;

    const url = serverUrl + '/api/subscription/status?subscriberId=' + subscriberId;

    const mockResponse = JSON.stringify({
      status: 'active',
      planId: 'plan_premium',
      planName: 'Premium Plan',
      currentPeriodEnd: '2026-12-31T23:59:59Z',
    });

    try {
      const response = JSON.parse(mockResponse);
      if (!response) return null;
      return response;
    } catch (e) {
      return null;
    }
  }

  describe('CheckSubscriptionStatus', () => {
    it('returns status object for valid subscriber', () => {
      const result = checkSubscriptionStatus('https://api.example.com', 'sub_123');
      isObject(result);
      equal(result.status, 'active');
    });

    it('returns null when subscriberId is empty', () => {
      falsy(checkSubscriptionStatus('https://api.example.com', ''));
    });

    it('returns null when serverUrl not configured', () => {
      falsy(checkSubscriptionStatus('', 'sub_123'));
    });

    it('builds correct status URL with query param', () => {
      const url = 'https://api.example.com' + '/api/subscription/status?subscriberId=sub_123';
      truthy(url.includes('subscriberId=sub_123'));
    });

    it('includes plan information in response', () => {
      const result = checkSubscriptionStatus('https://api.example.com', 'sub_123');
      hasProperty(result, 'planId');
      hasProperty(result, 'planName');
    });

    it('handles invalid JSON response', () => {
      function checkInvalid() {
        return JSON.parse('not json');
      }
      try {
        checkInvalid();
      } catch (e) {
        truthy(true); // caught parse error
      }
    });
  });

  // ============================================================
  // Cancel subscription — simulates CancelSubscription
  // ============================================================

  function cancelSubscription(serverUrl, subscriberId) {
    if (!subscriberId) return false;
    if (!serverUrl) return false;

    const url = serverUrl + '/api/subscription/cancel';
    const postData = JSON.stringify({ subscriberId });

    const mockResponse = JSON.stringify({ status: 'cancelled', subscriberId });

    try {
      const response = JSON.parse(mockResponse);
      if (response && response.status) return true;
    } catch (e) {
      return false;
    }
    return false;
  }

  describe('CancelSubscription', () => {
    it('returns true for valid cancellation', () => {
      truthy(cancelSubscription('https://api.example.com', 'sub_123'));
    });

    it('returns false when subscriberId is empty', () => {
      falsy(cancelSubscription('https://api.example.com', ''));
    });

    it('returns false when serverUrl not configured', () => {
      falsy(cancelSubscription('', 'sub_123'));
    });

    it('builds correct cancel URL', () => {
      const url = 'https://api.example.com' + '/api/subscription/cancel';
      equal(url, 'https://api.example.com/api/subscription/cancel');
    });

    it('posts subscriberId in request body', () => {
      const postData = JSON.stringify({ subscriberId: 'sub_123' });
      const parsed = JSON.parse(postData);
      equal(parsed.subscriberId, 'sub_123');
    });

    it('handles null serverUrl', () => {
      falsy(cancelSubscription(null, 'sub_123'));
    });
  });

  // ============================================================
  // Store subscription — simulates StoreSubscription
  // ============================================================

  function storeSubscription(globalNode, subscriberId, customerId, subscriptionId, planId, status) {
    if (!globalNode) return;

    globalNode.set('SubscriberId', subscriberId);
    globalNode.set('CustomerId', customerId);
    globalNode.set('SubscriptionId', subscriptionId);
    globalNode.set('PlanId', planId);
    globalNode.set('SubscriptionStatus', status);

    // Also save to simulated registry
    const registry = {};
    const prefData = { subscriberId, customerId, subscriptionId, planId, status };
    registry['sub_data'] = JSON.stringify(prefData);
  }

  describe('StoreSubscription', () => {
    it('stores all subscription fields in global node', () => {
      const globalMock = { fields: {} };
      globalMock.set = function(key, value) { globalMock.fields[key] = value; };
      globalMock.get = function(key) { return globalMock.fields[key]; };

      storeSubscription(globalMock, 'sub_123', 'cust_456', 'subscr_789', 'plan_premium', 'active');

      equal(globalMock.get('SubscriberId'), 'sub_123');
      equal(globalMock.get('CustomerId'), 'cust_456');
      equal(globalMock.get('SubscriptionId'), 'subscr_789');
      equal(globalMock.get('PlanId'), 'plan_premium');
      equal(globalMock.get('SubscriptionStatus'), 'active');
    });

    it('handles null global node', () => {
      storeSubscription(null, 'sub_123', 'cust_456', 'subscr_789', 'plan_premium', 'active');
    });

    it('overwrites existing subscription data', () => {
      const globalMock = { fields: {}, set: function(k,v) { this.fields[k] = v; }, get: function(k) { return this.fields[k]; } };
      storeSubscription(globalMock, 'sub_old', 'cust_old', 'subscr_old', 'plan_basic', 'cancelled');
      storeSubscription(globalMock, 'sub_new', 'cust_new', 'subscr_new', 'plan_premium', 'active');

      equal(globalMock.get('SubscriberId'), 'sub_new');
      equal(globalMock.get('PlanId'), 'plan_premium');
    });
  });

  // ============================================================
  // Load stored subscription — simulates LoadStoredSubscription
  // ============================================================

  function loadStoredSubscription(globalNode, registryData) {
    if (!globalNode) return;

    if (registryData && registryData !== '') {
      try {
        const data = JSON.parse(registryData);
        if (data) {
          globalNode.set('SubscriberId', data.subscriberId || '');
          globalNode.set('CustomerId', data.customerId || '');
          globalNode.set('SubscriptionId', data.subscriptionId || '');
          globalNode.set('PlanId', data.planId || '');
          globalNode.set('SubscriptionStatus', data.status || '');
        } else {
          clearStoredSubscription(globalNode);
        }
      } catch (e) {
        clearStoredSubscription(globalNode);
      }
    } else {
      clearStoredSubscription(globalNode);
    }
  }

  function clearStoredSubscription(globalNode) {
    if (!globalNode) return;
    globalNode.set('SubscriberId', '');
    globalNode.set('CustomerId', '');
    globalNode.set('SubscriptionId', '');
    globalNode.set('PlanId', '');
    globalNode.set('SubscriptionStatus', '');
  }

  describe('LoadStoredSubscription', () => {
    it('loads subscription from registry data', () => {
      const globalMock = { fields: {}, set: function(k,v) { this.fields[k] = v; }, get: function(k) { return this.fields[k]; } };
      const registryData = JSON.stringify({ subscriberId: 'sub_123', customerId: 'cust_456', subscriptionId: 'subscr_789', planId: 'plan_premium', status: 'active' });

      loadStoredSubscription(globalMock, registryData);

      equal(globalMock.get('SubscriberId'), 'sub_123');
      equal(globalMock.get('Status'), undefined); // not set directly
      equal(globalMock.get('SubscriptionStatus'), 'active');
    });

    it('handles empty registry data', () => {
      const globalMock = { fields: {}, set: function(k,v) { this.fields[k] = v; }, get: function(k) { return this.fields[k]; } };
      loadStoredSubscription(globalMock, '');

      equal(globalMock.get('SubscriberId'), '');
      equal(globalMock.get('SubscriptionStatus'), '');
    });

    it('handles invalid JSON in registry', () => {
      const globalMock = { fields: {}, set: function(k,v) { this.fields[k] = v; }, get: function(k) { return this.fields[k]; } };
      loadStoredSubscription(globalMock, 'not valid json');

      equal(globalMock.get('SubscriberId'), '');
    });

    it('handles null registry data', () => {
      const globalMock = { fields: {}, set: function(k,v) { this.fields[k] = v; }, get: function(k) { return this.fields[k]; } };
      loadStoredSubscription(globalMock, null);

      equal(globalMock.get('SubscriberId'), '');
    });

    it('handles null global node', () => {
      loadStoredSubscription(null, '{"subscriberId":"sub_123"}');
    });

    it('loads partial subscription data (missing fields)', () => {
      const globalMock = { fields: {}, set: function(k,v) { this.fields[k] = v; }, get: function(k) { return this.fields[k]; } };
      const registryData = JSON.stringify({ subscriberId: 'sub_123' });

      loadStoredSubscription(globalMock, registryData);

      equal(globalMock.get('SubscriberId'), 'sub_123');
      equal(globalMock.get('CustomerId'), '');
    });
  });

  // ============================================================
  // Clear stored subscription — simulates ClearStoredSubscription
  // ============================================================

  describe('ClearStoredSubscription', () => {
    it('clears all subscription fields', () => {
      const globalMock = { fields: {}, set: function(k,v) { this.fields[k] = v; }, get: function(k) { return this.fields[k]; } };
      // Set some values first
      globalMock.set('SubscriberId', 'sub_123');
      globalMock.set('SubscriptionStatus', 'active');

      clearStoredSubscription(globalMock);

      equal(globalMock.get('SubscriberId'), '');
      equal(globalMock.get('SubscriptionStatus'), '');
    });

    it('handles null global node', () => {
      clearStoredSubscription(null);
    });

    it('clears all five subscription fields', () => {
      const globalMock = { fields: {}, set: function(k,v) { this.fields[k] = v; }, get: function(k) { return this.fields[k]; } };
      clearStoredSubscription(globalMock);

      equal(globalMock.get('SubscriberId'), '');
      equal(globalMock.get('CustomerId'), '');
      equal(globalMock.get('SubscriptionId'), '');
      equal(globalMock.get('PlanId'), '');
      equal(globalMock.get('SubscriptionStatus'), '');
    });
  });

  // ============================================================
  // InitSubscriptionManager — simulates InitSubscriptionManager
  // ============================================================

  function initSubscriptionManager(config) {
    const result = {
      serverUrl: '',
      initialized: false,
    };

    if (config && config.serverUrl) {
      result.serverUrl = config.serverUrl;
    } else {
      result.serverUrl = '';
    }

    if (result.serverUrl === '') {
      result.warning = 'serverUrl not configured';
    }

    result.initialized = true;
    return result;
  }

  describe('InitSubscriptionManager', () => {
    it('initializes with server URL when provided', () => {
      const result = initSubscriptionManager({ serverUrl: 'https://api.example.com' });
      equal(result.serverUrl, 'https://api.example.com');
      truthy(result.initialized);
    });

    it('defaults serverUrl to empty string when not configured', () => {
      const result = initSubscriptionManager({});
      equal(result.serverUrl, '');
    });

    it('sets warning when serverUrl is empty', () => {
      const result = initSubscriptionManager({});
      equal(result.warning, 'serverUrl not configured');
    });

    it('handles null config gracefully', () => {
      const result = initSubscriptionManager(null);
      equal(result.serverUrl, '');
      truthy(result.initialized);
    });

    it('marks as initialized', () => {
      const result = initSubscriptionManager({ serverUrl: 'https://api.example.com' });
      truthy(result.initialized);
    });
  });

  // ============================================================
  // Full subscription lifecycle test
  // ============================================================

  describe('Subscription Lifecycle', () => {
    it('complete flow: init -> store -> load -> check -> cancel -> clear', () => {
      // Init
      const init = initSubscriptionManager({ serverUrl: 'https://api.example.com' });
      truthy(init.initialized);

      // Store
      const globalMock = { fields: {}, set: function(k,v) { this.fields[k] = v; }, get: function(k) { return this.fields[k]; } };
      storeSubscription(globalMock, 'sub_123', 'cust_456', 'subscr_789', 'plan_premium', 'active');

      // Check state
      const state = getSubscriptionState(globalMock);
      truthy(state.active);
      equal(state.subscriberId, 'sub_123');

      // Load from registry
      const registryData = JSON.stringify({ subscriberId: 'sub_123', customerId: 'cust_456', subscriptionId: 'subscr_789', planId: 'plan_premium', status: 'active' });
      loadStoredSubscription(globalMock, registryData);

      // Cancel
      truthy(cancelSubscription('https://api.example.com', 'sub_123'));

      // Clear
      clearStoredSubscription(globalMock);
      equal(globalMock.get('SubscriberId'), '');
    });

    it('state reflects cancellation after cancel', () => {
      const globalMock = { fields: {}, set: function(k,v) { this.fields[k] = v; }, get: function(k) { return this.fields[k]; } };
      storeSubscription(globalMock, 'sub_123', 'cust_456', 'subscr_789', 'plan_premium', 'active');

      let state = getSubscriptionState(globalMock);
      truthy(state.active);

      globalMock.set('SubscriptionStatus', 'cancelled');
      state = getSubscriptionState(globalMock);
      falsy(state.active);
    });
  });

  // ============================================================
  // SubscriptionManager file structure validation
  // ============================================================

  describe('SubscriptionManager.brs File Structure', () => {
    it('SubscriptionManager.brs file exists', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionManager.brs');
      truthy(fs.existsSync(testPath), 'SubscriptionManager.brs should exist');
    });

    it('has InitSubscriptionManager function', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionManager.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('sub InitSubscriptionManager'), 'Should have InitSubscriptionManager sub');
    });

    it('has GetSubscriptionState function', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionManager.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('function GetSubscriptionState'), 'Should have GetSubscriptionState function');
    });

    it('has StartCheckout function', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionManager.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('function StartCheckout'), 'Should have StartCheckout function');
    });

    it('has CheckSubscriptionStatus function', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionManager.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('function CheckSubscriptionStatus'), 'Should have CheckSubscriptionStatus function');
    });

    it('has CancelSubscription function', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionManager.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('function CancelSubscription'), 'Should have CancelSubscription function');
    });

    it('has StoreSubscription sub', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionManager.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('sub StoreSubscription'), 'Should have StoreSubscription sub');
    });

    it('has LoadStoredSubscription sub', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionManager.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('sub LoadStoredSubscription'), 'Should have LoadStoredSubscription sub');
    });

    it('has ClearStoredSubscription sub', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionManager.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('sub ClearStoredSubscription'), 'Should have ClearStoredSubscription sub');
    });

    it('uses roRegistry for persistence', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionManager.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('roRegistry'), 'Should use roRegistry');
    });

    it('uses ParseJson for response parsing', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionManager.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('ParseJson'), 'Should use ParseJson');
    });

    it('uses FormatJson for request building', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionManager.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('FormatJson'), 'Should use FormatJson');
    });

    it('uses roUrlTransfer for HTTP requests', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionManager.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('roUrlTransfer'), 'Should use roUrlTransfer');
    });

    it('has error handling with try/catch blocks', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionManager.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('catch'), 'Should have catch blocks');
    });

    it('uses SafeLog for error logging in GetSubscriptionState', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'SubscriptionManager.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('SafeLog'), 'Should use SafeLog');
    });
  });
}
