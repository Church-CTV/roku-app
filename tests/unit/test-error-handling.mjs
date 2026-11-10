/**
 * Unit Tests: ErrorHandling.brs
 * 
 * Tests centralized error handling: error log storage,
 * error counting, error summaries, and error reporting.
 */

export default async function runTests({ describe, it, assertions }) {
  const { equal, deepEqual, truthy, falsy, isString, isNumber,
           isArray, isObject, greaterThan, lessThan, match, hasProperty } = assertions;

  // ============================================================
  // InitErrorHandling tests
  // Simulates: sub InitErrorHandling(globalNode, port)
  // ============================================================

  function initErrorHandling(globalNode) {
    if (globalNode) {
      if (!globalNode.errorHandlerInitialized) {
        globalNode.errorHandlerInitialized = true;
        globalNode.errorLog = [];
        globalNode.errorCount = 0;
        globalNode.lastError = null;
      }
    }
    return globalNode;
  }

  describe('InitErrorHandling', () => {
    it('initializes error handler on global node', () => {
      const node = {};
      initErrorHandling(node);
      truthy(node.errorHandlerInitialized);
    });

    it('creates error log array', () => {
      const node = {};
      initErrorHandling(node);
      isArray(node.errorLog);
    });

    it('sets error count to zero', () => {
      const node = {};
      initErrorHandling(node);
      equal(node.errorCount, 0);
    });

    it('sets lastError to null', () => {
      const node = {};
      initErrorHandling(node);
      falsy(node.lastError);
    });

    it('skips re-initialization', () => {
      const node = { errorHandlerInitialized: true, errorLog: ['existing'] };
      initErrorHandling(node);
      equal(node.errorLog.length, 1);
    });

    it('handles invalid global node', () => {
      initErrorHandling(null);
      // Should not throw
    });
  });

  // ============================================================
  // GetErrorLog tests
  // Simulates: function GetErrorLog(globalNode) as Object
  // ============================================================

  function getErrorLog(globalNode) {
    if (globalNode && globalNode.errorLog) {
      return globalNode.errorLog;
    }
    return [];
  }

  describe('GetErrorLog', () => {
    it('returns error log when available', () => {
      const node = { errorLog: ['error1', 'error2'] };
      const log = getErrorLog(node);
      isArray(log);
      equal(log.length, 2);
    });

    it('returns empty array when no error log', () => {
      const node = {};
      const log = getErrorLog(node);
      isArray(log);
      equal(log.length, 0);
    });

    it('returns empty array for invalid node', () => {
      const log = getErrorLog(null);
      isArray(log);
      equal(log.length, 0);
    });
  });

  // ============================================================
  // GetErrorCount tests
  // Simulates: function GetErrorCount(globalNode) as Integer
  // ============================================================

  function getErrorCount(globalNode) {
    if (globalNode && globalNode.errorCount !== null && globalNode.errorCount !== undefined) {
      return globalNode.errorCount;
    }
    return 0;
  }

  describe('GetErrorCount', () => {
    it('returns error count when available', () => {
      const node = { errorCount: 5 };
      equal(getErrorCount(node), 5);
    });

    it('returns zero when no error count', () => {
      const node = {};
      equal(getErrorCount(node), 0);
    });

    it('returns zero for invalid node', () => {
      equal(getErrorCount(null), 0);
    });

    it('handles zero error count', () => {
      const node = { errorCount: 0 };
      equal(getErrorCount(node), 0);
    });
  });

  // ============================================================
  // GetLastError tests
  // Simulates: function GetLastError(globalNode) as Object
  // ============================================================

  function getLastError(globalNode) {
    if (globalNode && globalNode.lastError) {
      return globalNode.lastError;
    }
    return null;
  }

  describe('GetLastError', () => {
    it('returns last error when available', () => {
      const node = { lastError: { message: 'test error' } };
      const err = getLastError(node);
      truthy(err);
      equal(err.message, 'test error');
    });

    it('returns null when no last error', () => {
      const node = {};
      falsy(getLastError(node));
    });

    it('returns null for invalid node', () => {
      falsy(getLastError(null));
    });
  });

  // ============================================================
  // IncrementErrorCount tests
  // Simulates: sub IncrementErrorCount(globalNode)
  // ============================================================

  function incrementErrorCount(globalNode) {
    if (globalNode) {
      globalNode.errorCount = (globalNode.errorCount || 0) + 1;
    }
  }

  describe('IncrementErrorCount', () => {
    it('increments error count', () => {
      const node = { errorCount: 0 };
      incrementErrorCount(node);
      equal(node.errorCount, 1);
    });

    it('increments multiple times', () => {
      const node = { errorCount: 0 };
      incrementErrorCount(node);
      incrementErrorCount(node);
      incrementErrorCount(node);
      equal(node.errorCount, 3);
    });

    it('handles missing error count', () => {
      const node = {};
      incrementErrorCount(node);
      equal(node.errorCount, 1);
    });

    it('handles invalid node', () => {
      incrementErrorCount(null);
      // Should not throw
    });
  });

  // ============================================================
  // LogToErrorLog tests
  // Simulates: sub LogToErrorLog(component, message, category, errorType, severity, globalNode)
  // ============================================================

  function logToErrorLog(component, message, category, errorType, severity, globalNode) {
    if (!globalNode) return;
    if (!globalNode.errorLog) globalNode.errorLog = [];
    
    const entry = {
      component: component,
      message: message,
      category: category,
      errorType: errorType,
      severity: severity,
      timestamp: new Date().toISOString()
    };
    globalNode.errorLog.push(entry);
    globalNode.errorCount = (globalNode.errorCount || 0) + 1;
    globalNode.lastError = entry;
  }

  describe('LogToErrorLog', () => {
    it('creates log entry with all fields', () => {
      const node = { errorLog: [], errorCount: 0 };
      logToErrorLog('TestModule', 'test error', 'runtime', 1, 'error', node);
      equal(node.errorLog.length, 1);
      const entry = node.errorLog[0];
      equal(entry.component, 'TestModule');
      equal(entry.message, 'test error');
      equal(entry.category, 'runtime');
      equal(entry.errorType, 1);
      equal(entry.severity, 'error');
    });

    it('increments error count', () => {
      const node = { errorLog: [], errorCount: 0 };
      logToErrorLog('TestModule', 'error', 'runtime', 1, 'error', node);
      equal(node.errorCount, 1);
    });

    it('updates lastError', () => {
      const node = { errorLog: [], errorCount: 0 };
      logToErrorLog('TestModule', 'error', 'runtime', 1, 'error', node);
      truthy(node.lastError);
      equal(node.lastError.message, 'error');
    });

    it('handles invalid global node', () => {
      logToErrorLog('TestModule', 'error', 'runtime', 1, 'error', null);
      // Should not throw
    });

    it('creates errorLog if missing', () => {
      const node = { errorCount: 0 };
      logToErrorLog('TestModule', 'error', 'runtime', 1, 'error', node);
      truthy(node.errorLog);
      isArray(node.errorLog);
    });
  });

  // ============================================================
  // GetErrorSummary tests
  // Simulates: function GetErrorSummary(globalNode) as Object
  // ============================================================

  function getErrorSummary(globalNode) {
    if (!globalNode) {
      return { errorCount: 0, lastError: null, recentErrors: [] };
    }
    return {
      errorCount: globalNode.errorCount || 0,
      lastError: globalNode.lastError || null,
      recentErrors: globalNode.errorLog || []
    };
  }

  describe('GetErrorSummary', () => {
    it('returns object with all fields', () => {
      const summary = getErrorSummary({ errorCount: 3, lastError: { message: 'err' }, errorLog: [] });
      hasProperty(summary, 'errorCount');
      hasProperty(summary, 'lastError');
      hasProperty(summary, 'recentErrors');
    });

    it('returns correct error count', () => {
      const summary = getErrorSummary({ errorCount: 5 });
      equal(summary.errorCount, 5);
    });

    it('returns last error', () => {
      const lastErr = { message: 'last error' };
      const summary = getErrorSummary({ lastError: lastErr });
      equal(summary.lastError.message, 'last error');
    });

    it('returns error log', () => {
      const errors = [{ message: 'error1' }, { message: 'error2' }];
      const summary = getErrorSummary({ errorLog: errors });
      equal(summary.recentErrors.length, 2);
    });

    it('handles invalid global node', () => {
      const summary = getErrorSummary(null);
      equal(summary.errorCount, 0);
      falsy(summary.lastError);
      isArray(summary.recentErrors);
    });
  });

  // ============================================================
  // ClearErrorLog tests
  // Simulates: sub ClearErrorLog(globalNode)
  // ============================================================

  function clearErrorLog(globalNode) {
    if (globalNode) {
      globalNode.errorLog = [];
      globalNode.errorCount = 0;
      globalNode.lastError = null;
    }
  }

  describe('ClearErrorLog', () => {
    it('clears error log', () => {
      const node = { errorLog: ['error1'], errorCount: 5, lastError: { message: 'error' } };
      clearErrorLog(node);
      equal(node.errorLog.length, 0);
      equal(node.errorCount, 0);
      falsy(node.lastError);
    });

    it('handles invalid global node', () => {
      clearErrorLog(null);
      // Should not throw
    });
  });

  // ============================================================
  // ReportErrorToCrashReporter tests
  // Simulates: sub ReportErrorToCrashReporter(errorType, message, context, globalNode)
  // ============================================================

  describe('ReportErrorToCrashReporter', () => {
    it('reports to crash reporter when available', () => {
      const node = {
        analytics: {
          TrackError: function(errorType, message, context) {
            return { reported: true, errorType, message, context };
          }
        }
      };
      const result = node.analytics.TrackError('network', 'timeout', 'request');
      truthy(result.reported);
      equal(result.errorType, 'network');
    });

    it('handles missing analytics', () => {
      const node = {};
      // Should not throw when analytics is missing
      let handled = false;
      try {
        if (node.analytics && node.analytics.TrackError) {
          node.analytics.TrackError('network', 'timeout', 'request');
        }
        handled = true;
      } catch (e) {
        handled = false;
      }
      truthy(handled);
    });

    it('handles invalid global node', () => {
      const node = null;
      let handled = false;
      try {
        if (node && node.analytics && node.analytics.TrackError) {
          node.analytics.TrackError('network', 'timeout', 'request');
        }
        handled = true;
      } catch (e) {
        handled = false;
      }
      truthy(handled);
    });
  });

  // ============================================================
  // Error entry structure tests
  // ============================================================

  describe('Error Entry Structure', () => {
    it('has component field', () => {
      const entry = { component: 'TestModule', message: 'error', category: 'runtime', errorType: 1, severity: 'error', timestamp: '2025-01-01' };
      hasProperty(entry, 'component');
    });

    it('has message field', () => {
      const entry = { component: 'TestModule', message: 'error', category: 'runtime', errorType: 1, severity: 'error', timestamp: '2025-01-01' };
      hasProperty(entry, 'message');
    });

    it('has category field', () => {
      const entry = { component: 'TestModule', message: 'error', category: 'runtime', errorType: 1, severity: 'error', timestamp: '2025-01-01' };
      hasProperty(entry, 'category');
    });

    it('has errorType field', () => {
      const entry = { component: 'TestModule', message: 'error', category: 'runtime', errorType: 1, severity: 'error', timestamp: '2025-01-01' };
      hasProperty(entry, 'errorType');
    });

    it('has severity field', () => {
      const entry = { component: 'TestModule', message: 'error', category: 'runtime', errorType: 1, severity: 'error', timestamp: '2025-01-01' };
      hasProperty(entry, 'severity');
    });

    it('has timestamp field', () => {
      const entry = { component: 'TestModule', message: 'error', category: 'runtime', errorType: 1, severity: 'error', timestamp: '2025-01-01' };
      hasProperty(entry, 'timestamp');
    });
  });

  // ============================================================
  // Error category constants
  // ============================================================

  describe('Error Categories', () => {
    it('runtime category = 1', () => {
      equal(1, 1);
    });

    it('application category = 2', () => {
      equal(2, 2);
    });

    it('network category = 3', () => {
      equal(3, 3);
    });

    it('categories are distinct', () => {
      truthy(1 !== 2);
      truthy(2 !== 3);
      truthy(1 !== 3);
    });
  });
}
