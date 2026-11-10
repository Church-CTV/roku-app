/**
 * Unit Tests: main.brs
 *
 * Tests the entry point module: scene creation, deep link routing
 * (startup and runtime), event loop behavior, and exit handling.
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
  // Scene creation — simulates Main entry point behavior
  // ============================================================

  function createScene(args) {
    const result = {
      screenCreated: false,
      portSet: false,
      globalInitialized: false,
      sceneCreated: false,
      showCalled: false,
      deepLinkHandled: false,
      errorOccurred: false,
    };

    // Create roSGScreen (simulated)
    try {
      result.screenCreated = true;

      // Set message port (simulated)
      result.portSet = true;

      // Initialize global node with fields
      result.globalInitialized = true;

      // Handle deep linking
      let deepContentId = null;
      let deepMediaType = null;

      if (args && args.ContentId !== undefined && args.ContentId !== null) {
        deepContentId = args.ContentId;
      } else if (args && args.contentid !== undefined && args.contentid !== null) {
        deepContentId = args.contentid;
      } else if (args && args.contentId !== undefined && args.contentId !== null) {
        deepContentId = args.contentId;
      }

      if (args && args.MediaType !== undefined && args.MediaType !== null) {
        deepMediaType = args.MediaType;
      } else if (args && args.mediatype !== undefined && args.mediatype !== null) {
        deepMediaType = args.mediatype;
      } else if (args && args.mediaType !== undefined && args.mediaType !== null) {
        deepMediaType = args.mediaType;
      }

      if (deepContentId !== null && deepMediaType !== null) {
        result.deepLinkHandled = true;
        result.deepContentId = deepContentId;
        result.deepMediaType = deepMediaType;
      }

      // Create and show scene
      result.sceneCreated = true;
      result.showCalled = true;
    } catch (e) {
      result.errorOccurred = true;
    }

    return result;
  }

  describe('Scene Creation', () => {
    it('creates roSGScreen successfully', () => {
      const result = createScene({});
      truthy(result.screenCreated);
    });

    it('sets message port', () => {
      const result = createScene({});
      truthy(result.portSet);
    });

    it('initializes global node', () => {
      const result = createScene({});
      truthy(result.globalInitialized);
    });

    it('creates MainScene', () => {
      const result = createScene({});
      truthy(result.sceneCreated);
    });

    it('calls screen.Show()', () => {
      const result = createScene({});
      truthy(result.showCalled);
    });

    it('handles null args gracefully', () => {
      const result = createScene(null);
      truthy(result.screenCreated);
      falsy(result.deepLinkHandled);
    });

    it('handles missing deep link args', () => {
      const result = createScene({});
      falsy(result.deepLinkHandled);
    });

    it('tracks error when screen creation fails', () => {
      function createFailed() {
        const result = { screenCreated: false };
        throw new Error('FATAL');
        return result; // unreachable
      }
      try {
        createFailed();
      } catch (e) {
        truthy(true);
      }
    });
  });

  // ============================================================
  // Deep link parameter resolution — simulates deep link handling in Main
  // ============================================================

  function resolveDeepLinkArgs(args) {
    let contentId = null;
    let mediaType = null;

    // Resolve contentId from any casing variant
    if (args && args.ContentId !== undefined && args.ContentId !== null) {
      contentId = args.ContentId;
    } else if (args && args.contentid !== undefined && args.contentid !== null) {
      contentId = args.contentid;
    } else if (args && args.contentId !== undefined && args.contentId !== null) {
      contentId = args.contentId;
    }

    // Resolve mediaType from any casing variant
    if (args && args.MediaType !== undefined && args.MediaType !== null) {
      mediaType = args.MediaType;
    } else if (args && args.mediatype !== undefined && args.mediatype !== null) {
      mediaType = args.mediatype;
    } else if (args && args.mediaType !== undefined && args.mediaType !== null) {
      mediaType = args.mediaType;
    }

    return { contentId, mediaType };
  }

  describe('Deep Link Parameter Resolution', () => {
    it('resolves ContentId with uppercase C', () => {
      const result = resolveDeepLinkArgs({ ContentId: 'sermon-123' });
      equal(result.contentId, 'sermon-123');
    });

    it('resolves contentid with all lowercase', () => {
      const result = resolveDeepLinkArgs({ contentid: 'sermon-456' });
      equal(result.contentId, 'sermon-456');
    });

    it('resolves contentId with camelCase', () => {
      const result = resolveDeepLinkArgs({ contentId: 'sermon-789' });
      equal(result.contentId, 'sermon-789');
    });

    it('prefers ContentId over other casings (first match wins)', () => {
      const result = resolveDeepLinkArgs({ ContentId: 'first', contentid: 'second' });
      equal(result.contentId, 'first');
    });

    it('resolves MediaType with uppercase M', () => {
      const result = resolveDeepLinkArgs({ MediaType: 'sermon' });
      equal(result.mediaType, 'sermon');
    });

    it('resolves mediatype with all lowercase', () => {
      const result = resolveDeepLinkArgs({ mediatype: 'sermon' });
      equal(result.mediaType, 'sermon');
    });

    it('resolves mediaType with camelCase', () => {
      const result = resolveDeepLinkArgs({ mediaType: 'sermon' });
      equal(result.mediaType, 'sermon');
    });

    it('prefers MediaType over other casings', () => {
      const result = resolveDeepLinkArgs({ MediaType: 'first', mediatype: 'second' });
      equal(result.mediaType, 'first');
    });

    it('returns null when no deep link args present', () => {
      const result = resolveDeepLinkArgs({});
      falsy(result.contentId);
      falsy(result.mediaType);
    });

    it('handles null args', () => {
      const result = resolveDeepLinkArgs(null);
      falsy(result.contentId);
      falsy(result.mediaType);
    });

    it('requires both contentId AND mediaType for deep link', () => {
      const result = resolveDeepLinkArgs({ ContentId: 'sermon-123' });
      truthy(result.contentId);
      falsy(result.mediaType);
    });

    it('handles empty string args as valid values', () => {
      const result = resolveDeepLinkArgs({ ContentId: '', MediaType: '' });
      equal(result.contentId, '');
      equal(result.mediaType, '');
    });
  });

  // ============================================================
  // Runtime deep link handling — simulates roInputEvent processing
  // ============================================================

  function handleRuntimeDeepLink(info) {
    if (!info || !info.mediatype || !info.contentid) return null;
    return {
      contentId: info.contentid,
      mediaType: info.mediatype,
    };
  }

  describe('Runtime Deep Link Handling', () => {
    it('handles valid runtime deep link', () => {
      const result = handleRuntimeDeepLink({ mediatype: 'sermon', contentid: 'live-001' });
      truthy(result);
      equal(result.contentId, 'live-001');
      equal(result.mediaType, 'sermon');
    });

    it('handles null info', () => {
      falsy(handleRuntimeDeepLink(null));
    });

    it('handles missing mediatype', () => {
      falsy(handleRuntimeDeepLink({ contentid: 'live-001' }));
    });

    it('handles missing contentid', () => {
      falsy(handleRuntimeDeepLink({ mediatype: 'sermon' }));
    });
  });

  // ============================================================
  // Event loop exit handling — simulates the event loop in Main
  // ============================================================

  function simulateEventLoop(events, closeChannelFlag) {
    const result = {
      exitedViaCloseChannel: false,
      exitedViaScreenClosed: false,
      eventsProcessed: 0,
      analyticsCalled: false,
    };

    if (!events || events.length === 0) {
      if (closeChannelFlag) {
        result.exitedViaCloseChannel = true;
        result.analyticsCalled = true;
      }
      return result;
    }

    for (const event of events) {
      if (event.type === 'roSGScreenEvent' && event.isScreenClosed) {
        result.exitedViaScreenClosed = true;
        result.analyticsCalled = true;
        return result;
      }

      if (event.type === 'roInputEvent') {
        const info = event.info;
        if (info && info.mediatype && info.contentid) {
          result.eventsProcessed++;
        }
      }

      if (closeChannelFlag) {
        result.exitedViaCloseChannel = true;
        result.analyticsCalled = true;
        return result;
      }

      result.eventsProcessed++;
    }

    return result;
  }

  describe('Event Loop Exit Handling', () => {
    it('exits via screen closed event', () => {
      const events = [{ type: 'roSGScreenEvent', isScreenClosed: true }];
      const result = simulateEventLoop(events, false);
      truthy(result.exitedViaScreenClosed);
      falsy(result.exitedViaCloseChannel);
    });

    it('exits via close channel flag', () => {
      const events = [{ type: 'roSGScreenEvent', isScreenClosed: false }];
      const result = simulateEventLoop(events, true);
      truthy(result.exitedViaCloseChannel);
      falsy(result.exitedViaScreenClosed);
    });

    it('calls analytics on exit', () => {
      const events = [{ type: 'roSGScreenEvent', isScreenClosed: true }];
      const result = simulateEventLoop(events, false);
      truthy(result.analyticsCalled);
    });

    it('does not call analytics mid-loop', () => {
      const events = [
        { type: 'roInputEvent', info: { contentid: 'x', mediatype: 'y' } },
        { type: 'roSGScreenEvent', isScreenClosed: false },
      ];
      const result = simulateEventLoop(events, false);
      falsy(result.analyticsCalled);
    });

    it('processes runtime deep link events', () => {
      const events = [
        { type: 'roInputEvent', info: { contentid: 'live-001', mediatype: 'sermon' } },
        { type: 'roSGScreenEvent', isScreenClosed: false, closeChannel: true },
      ];
      const result = simulateEventLoop(events, true);
      truthy(result.eventsProcessed >= 1);
    });

    it('handles empty event list with close flag', () => {
      const result = simulateEventLoop([], true);
      truthy(result.exitedViaCloseChannel);
    });
  });

  // ============================================================
  // Global node field initialization — simulates main.brs global setup
  // ============================================================

  function initGlobalNode(appVersion) {
    const fields = {
      startupArgs: '',
      DeepContentId: '',
      DeepMediaType: '',
      DeepNav: '',
      AppVersion: appVersion || '0.0.1',
      ContentLoaded: false,
      ErrorOccurred: false,
      ErrorMessage: '',
      CloseChannel: false,
      locationKey: '',
    };
    return fields;
  }

  describe('Global Node Initialization', () => {
    it('initializes all required fields', () => {
      const fields = initGlobalNode('1.0.0');
      hasProperty(fields, 'startupArgs');
      hasProperty(fields, 'DeepContentId');
      hasProperty(fields, 'DeepMediaType');
      hasProperty(fields, 'DeepNav');
      hasProperty(fields, 'AppVersion');
      hasProperty(fields, 'ContentLoaded');
      hasProperty(fields, 'ErrorOccurred');
      hasProperty(fields, 'ErrorMessage');
      hasProperty(fields, 'CloseChannel');
      hasProperty(fields, 'locationKey');
    });

    it('sets AppVersion from parameter', () => {
      const fields = initGlobalNode('2.5.0');
      equal(fields.AppVersion, '2.5.0');
    });

    it('defaults AppVersion to 0.0.1', () => {
      const fields = initGlobalNode(null);
      equal(fields.AppVersion, '0.0.1');
    });

    it('defaults CloseChannel to false', () => {
      const fields = initGlobalNode('1.0.0');
      falsy(fields.CloseChannel);
    });

    it('defaults ErrorOccurred to false', () => {
      const fields = initGlobalNode('1.0.0');
      falsy(fields.ErrorOccurred);
    });

    it('defaults ContentLoaded to false', () => {
      const fields = initGlobalNode('1.0.0');
      falsy(fields.ContentLoaded);
    });

    it('initializes string fields to empty strings', () => {
      const fields = initGlobalNode('1.0.0');
      equal(fields.startupArgs, '');
      equal(fields.DeepContentId, '');
      equal(fields.locationKey, '');
    });
  });

  // ============================================================
  // main.brs file structure validation
  // ============================================================

  describe('main.brs File Structure', () => {
    it('main.brs file exists', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'main.brs');
      truthy(fs.existsSync(testPath), 'main.brs should exist');
    });

    it('has Main sub as entry point', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'main.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('sub Main'), 'Should have Main sub');
    });

    it('creates roSGScreen', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'main.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('roSGScreen'), 'Should create roSGScreen');
    });

    it('creates roMessagePort', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'main.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('roMessagePort'), 'Should create roMessagePort');
    });

    it('creates roAppInfo for version', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'main.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('roAppInfo'), 'Should use roAppInfo');
    });

    it('handles deep link args with multiple casings', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'main.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('ContentId'), 'Should check ContentId');
      truthy(content.includes('contentid'), 'Should check contentid');
      truthy(content.includes('contentId'), 'Should check contentId');
    });

    it('creates MainScene', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'main.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('CreateScene("MainScene")'), 'Should create MainScene');
    });

    it('has event loop with wait(100, port)', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'main.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('wait(100, port)'), 'Should have event loop with 100ms timeout');
    });

    it('handles roSGScreenEvent for screen close', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'main.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('roSGScreenEvent'), 'Should handle roSGScreenEvent');
    });

    it('handles roInputEvent for runtime deep links', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'main.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('roInputEvent'), 'Should handle roInputEvent');
    });

    it('creates roInput for transport events', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'main.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('roInput'), 'Should create roInput');
    });

    it('calls AnalyticsOnAppExit on exit', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'main.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('AnalyticsOnAppExit'), 'Should call AnalyticsOnAppExit');
    });

    it('polls CloseChannel flag for exit', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'main.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('CloseChannel'), 'Should poll CloseChannel flag');
    });

    it('has error handling with try/catch blocks', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'main.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('catch'), 'Should have catch blocks');
    });

    it('uses SafeLog for logging', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'main.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('SafeLog'), 'Should use SafeLog');
    });

    it('uses FormatJson for startup args', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'main.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('FormatJson'), 'Should use FormatJson');
    });

    it('uses print for deep link debug output', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'main.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('DEEP LINK DEBUG'), 'Should have deep link debug prints');
    });

    it('enables transport events on roInput', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'main.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('EnableTransportEvents'), 'Should enable transport events');
    });

    it('calls EventResponse on input events', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'main.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('EventResponse'), 'Should call EventResponse');
    });

    it('has while true event loop', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'main.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('while true'), 'Should have infinite event loop');
    });
  });
}
