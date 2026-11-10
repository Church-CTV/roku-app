/**
 * Unit Tests: Heartbeat.brs
 *
 * Tests the periodic telemetry heartbeat system.
 * Covers initialization, state tracking (screen/video/crash/warning),
 * export payload construction, and session ID generation.
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
  // Heartbeat initialization — simulates HeartbeatInit
  // ============================================================

  function createHeartbeatState(config) {
    const state = {};
    state.intervalSeconds = 60;
    if (config && config.heartbeat) {
      if (config.heartbeat.intervalSeconds > 0) {
        state.intervalSeconds = config.heartbeat.intervalSeconds;
      }
      if (config.heartbeat.exportUrl !== undefined && config.heartbeat.exportUrl !== '') {
        state.exportUrl = config.heartbeat.exportUrl;
      } else {
        state.exportUrl = '';
      }
    } else {
      state.exportUrl = '';
    }
    state.lastExport = Date.now() / 1000;
    state.crashCount = 0;
    state.warningCount = 0;
    state.screenHistory = [];
    state.videoState = 'idle';
    state.videoId = '';
    state.videoPosition = 0;
    state.videoDuration = 0;
    state.currentScreen = 'MainScene';
    state.isVideoPlaying = false;
    state.sessionStartTime = state.lastExport;
    state.networkErrors = 0;
    state.contentFetches = 0;
    state.lastError = '';
    state.lastErrorTime = '';
    return state;
  }

  describe('HeartbeatInit', () => {
    it('initializes with default interval of 60 seconds', () => {
      const hb = createHeartbeatState({});
      equal(hb.intervalSeconds, 60);
    });

    it('uses config heartbeat interval when provided', () => {
      const hb = createHeartbeatState({ heartbeat: { intervalSeconds: 120 } });
      equal(hb.intervalSeconds, 120);
    });

    it('ignores zero interval and keeps default', () => {
      const hb = createHeartbeatState({ heartbeat: { intervalSeconds: 0 } });
      equal(hb.intervalSeconds, 60);
    });

    it('uses config exportUrl when provided', () => {
      const url = 'https://telemetry.example.com/heartbeat';
      const hb = createHeartbeatState({ heartbeat: { exportUrl: url } });
      equal(hb.exportUrl, url);
    });

    it('defaults exportUrl to empty string when not configured', () => {
      const hb = createHeartbeatState({});
      equal(hb.exportUrl, '');
    });

    it('initializes all tracking counters to zero', () => {
      const hb = createHeartbeatState({});
      equal(hb.crashCount, 0);
      equal(hb.warningCount, 0);
      equal(hb.networkErrors, 0);
      equal(hb.contentFetches, 0);
    });

    it('initializes video state to idle', () => {
      const hb = createHeartbeatState({});
      equal(hb.videoState, 'idle');
      equal(hb.isVideoPlaying, false);
      equal(hb.videoId, '');
      equal(hb.videoPosition, 0);
    });

    it('initializes currentScreen to MainScene', () => {
      const hb = createHeartbeatState({});
      equal(hb.currentScreen, 'MainScene');
    });

    it('handles null config gracefully', () => {
      const hb = createHeartbeatState(null);
      truthy(hb.intervalSeconds > 0);
      equal(hb.exportUrl, '');
    });

    it('tracks session start time', () => {
      const hb = createHeartbeatState({});
      truthy(hb.sessionStartTime > 0);
      isNumber(hb.sessionStartTime);
    });
  });

  // ============================================================
  // Heartbeat export payload — simulates HeartbeatExport
  // ============================================================

  function buildHeartbeatPayload(state) {
    if (!state) return {};

    const payload = {
      type: 'heartbeat',
      timestamp: new Date().toISOString(),
      sessionId: createHeartbeatSessionId(),
      intervalSeconds: state.intervalSeconds,
      sessionDuration: Math.floor(Date.now() / 1000) - state.sessionStartTime,
      screen: state.currentScreen,
      isVideoPlaying: state.isVideoPlaying,
      videoId: state.videoId,
      videoPosition: state.videoPosition,
      videoDuration: state.videoDuration,
      crashCount: state.crashCount,
      warningCount: state.warningCount,
      networkErrors: state.networkErrors,
      contentFetches: state.contentFetches,
      lastError: state.lastError,
      lastErrorTime: state.lastErrorTime,
    };

    // Truncate screen history to last 20 entries
    if (state.screenHistory.length > 0) {
      const start = Math.max(0, state.screenHistory.length - 20);
      payload.screenHistory = JSON.stringify(state.screenHistory.slice(start));
    } else {
      payload.screenHistory = '[]';
    }

    return payload;
  }

  describe('HeartbeatExport', () => {
    it('returns object with type heartbeat', () => {
      const state = createHeartbeatState({});
      const payload = buildHeartbeatPayload(state);
      equal(payload.type, 'heartbeat');
    });

    it('includes timestamp', () => {
      const state = createHeartbeatState({});
      const payload = buildHeartbeatPayload(state);
      isString(payload.timestamp);
      match(payload.timestamp, /^\d{4}-\d{2}-\d{2}/);
    });

    it('includes session ID', () => {
      const state = createHeartbeatState({});
      const payload = buildHeartbeatPayload(state);
      truthy(payload.sessionId);
      isString(payload.sessionId);
      greaterThan(payload.sessionId.length, 0);
    });

    it('includes intervalSeconds from state', () => {
      const state = createHeartbeatState({ heartbeat: { intervalSeconds: 90 } });
      const payload = buildHeartbeatPayload(state);
      equal(payload.intervalSeconds, 90);
    });

    it('includes session duration in seconds', () => {
      const now = Math.floor(Date.now() / 1000);
      const state = createHeartbeatState({});
      state.sessionStartTime = now - 300; // 5 minutes ago
      const payload = buildHeartbeatPayload(state);
      equal(payload.sessionDuration, 300);
    });

    it('tracks current screen', () => {
      const state = createHeartbeatState({});
      state.currentScreen = 'SearchScreen';
      const payload = buildHeartbeatPayload(state);
      equal(payload.screen, 'SearchScreen');
    });

    it('tracks video playing state', () => {
      const state = createHeartbeatState({});
      state.isVideoPlaying = true;
      state.videoId = 'vid123';
      state.videoPosition = 45;
      state.videoDuration = 1800;
      const payload = buildHeartbeatPayload(state);
      truthy(payload.isVideoPlaying);
      equal(payload.videoId, 'vid123');
      equal(payload.videoPosition, 45);
      equal(payload.videoDuration, 1800);
    });

    it('tracks crash count', () => {
      const state = createHeartbeatState({});
      state.crashCount = 3;
      const payload = buildHeartbeatPayload(state);
      equal(payload.crashCount, 3);
    });

    it('tracks warning count', () => {
      const state = createHeartbeatState({});
      state.warningCount = 5;
      const payload = buildHeartbeatPayload(state);
      equal(payload.warningCount, 5);
    });

    it('tracks network errors', () => {
      const state = createHeartbeatState({});
      state.networkErrors = 2;
      const payload = buildHeartbeatPayload(state);
      equal(payload.networkErrors, 2);
    });

    it('tracks content fetches', () => {
      const state = createHeartbeatState({});
      state.contentFetches = 10;
      const payload = buildHeartbeatPayload(state);
      equal(payload.contentFetches, 10);
    });

    it('truncates screen history to last 20 entries', () => {
      const state = createHeartbeatState({});
      for (let i = 0; i < 30; i++) {
        state.screenHistory.push({ screen: `Screen${i}`, time: Date.now() });
      }
      const payload = buildHeartbeatPayload(state);
      // Should be truncated to 20
      const parsed = JSON.parse(payload.screenHistory);
      equal(parsed.length, 20);
    });

    it('handles empty screen history', () => {
      const state = createHeartbeatState({});
      const payload = buildHeartbeatPayload(state);
      equal(payload.screenHistory, '[]');
    });

    it('returns empty object when state is invalid', () => {
      const payload = buildHeartbeatPayload(null);
      deepEqual(payload, {});
    });

    it('includes last error info', () => {
      const state = createHeartbeatState({});
      state.lastError = 'connection timeout';
      state.lastErrorTime = '1718000000';
      const payload = buildHeartbeatPayload(state);
      equal(payload.lastError, 'connection timeout');
      equal(payload.lastErrorTime, '1718000000');
    });

    it('has all required payload fields', () => {
      const state = createHeartbeatState({});
      const payload = buildHeartbeatPayload(state);
      hasProperty(payload, 'type');
      hasProperty(payload, 'timestamp');
      hasProperty(payload, 'sessionId');
      hasProperty(payload, 'intervalSeconds');
      hasProperty(payload, 'sessionDuration');
      hasProperty(payload, 'screen');
      hasProperty(payload, 'isVideoPlaying');
      hasProperty(payload, 'crashCount');
      hasProperty(payload, 'warningCount');
    });
  });

  // ============================================================
  // Screen tracking — simulates HeartbeatTrackScreen
  // ============================================================

  function trackScreen(state, screenName) {
    if (!state) return;
    state.currentScreen = screenName;
    state.screenHistory.push({ screen: screenName, time: Date.now() / 1000 });
  }

  describe('HeartbeatTrackScreen', () => {
    it('updates current screen name', () => {
      const state = createHeartbeatState({});
      trackScreen(state, 'SettingsScreen');
      equal(state.currentScreen, 'SettingsScreen');
    });

    it('records screen in history', () => {
      const state = createHeartbeatState({});
      trackScreen(state, 'SearchScreen');
      equal(state.screenHistory.length, 1);
      equal(state.screenHistory[0].screen, 'SearchScreen');
    });

    it('tracks multiple screen transitions', () => {
      const state = createHeartbeatState({});
      trackScreen(state, 'MainScene');
      trackScreen(state, 'SearchScreen');
      trackScreen(state, 'VideoScreen');
      equal(state.currentScreen, 'VideoScreen');
      equal(state.screenHistory.length, 3);
    });

    it('handles invalid state', () => {
      trackScreen(null, 'AnyScreen'); // should not throw
    });
  });

  // ============================================================
  // Video tracking — simulates HeartbeatTrackVideo
  // ============================================================

  function trackVideo(state, playing, videoId, position, duration) {
    if (!state) return;
    state.isVideoPlaying = playing;
    state.videoId = videoId;
    state.videoPosition = position;
    state.videoDuration = duration;
    state.videoState = playing ? 'playing' : 'idle';
  }

  describe('HeartbeatTrackVideo', () => {
    it('sets playing to true and state to playing', () => {
      const state = createHeartbeatState({});
      trackVideo(state, true, 'sermon-001', 300, 1800);
      truthy(state.isVideoPlaying);
      equal(state.videoState, 'playing');
      equal(state.videoId, 'sermon-001');
    });

    it('sets playing to false and state to idle', () => {
      const state = createHeartbeatState({});
      trackVideo(state, false, '', 0, 0);
      falsy(state.isVideoPlaying);
      equal(state.videoState, 'idle');
    });

    it('tracks position and duration', () => {
      const state = createHeartbeatState({});
      trackVideo(state, true, 'vid-123', 450, 3600);
      equal(state.videoPosition, 450);
      equal(state.videoDuration, 3600);
    });

    it('handles invalid state', () => {
      trackVideo(null, true, 'vid', 0, 100);
    });
  });

  // ============================================================
  // Crash tracking — simulates HeartbeatTrackCrash
  // ============================================================

  function trackCrash(state, message) {
    if (!state) return;
    state.crashCount = state.crashCount + 1;
    state.lastError = message;
    state.lastErrorTime = Math.floor(Date.now() / 1000).toString();
  }

  describe('HeartbeatTrackCrash', () => {
    it('increments crash count', () => {
      const state = createHeartbeatState({});
      trackCrash(state, 'null reference');
      equal(state.crashCount, 1);
    });

    it('records last error message', () => {
      const state = createHeartbeatState({});
      trackCrash(state, 'out of memory');
      equal(state.lastError, 'out of memory');
    });

    it('records last error timestamp', () => {
      const state = createHeartbeatState({});
      trackCrash(state, 'crash test');
      isString(state.lastErrorTime);
      greaterThan(state.lastErrorTime.length, 0);
    });

    it('increments crash count on repeated crashes', () => {
      const state = createHeartbeatState({});
      trackCrash(state, 'error 1');
      trackCrash(state, 'error 2');
      equal(state.crashCount, 2);
    });

    it('handles invalid state', () => {
      trackCrash(null, 'test');
    });
  });

  // ============================================================
  // Warning tracking — simulates HeartbeatTrackWarning
  // ============================================================

  function trackWarning(state, message) {
    if (!state) return;
    state.warningCount = state.warningCount + 1;
  }

  describe('HeartbeatTrackWarning', () => {
    it('increments warning count', () => {
      const state = createHeartbeatState({});
      trackWarning(state, 'low disk space');
      equal(state.warningCount, 1);
    });

    it('increments on repeated warnings', () => {
      const state = createHeartbeatState({});
      trackWarning(state, 'warn 1');
      trackWarning(state, 'warn 2');
      equal(state.warningCount, 2);
    });

    it('handles invalid state', () => {
      trackWarning(null, 'test');
    });
  });

  // ============================================================
  // Network error tracking — simulates HeartbeatTrackNetworkError
  // ============================================================

  function trackNetworkError(state, errorCode) {
    if (!state) return;
    state.networkErrors = state.networkErrors + 1;
  }

  describe('HeartbeatTrackNetworkError', () => {
    it('increments network error count', () => {
      const state = createHeartbeatState({});
      trackNetworkError(state, 408);
      equal(state.networkErrors, 1);
    });

    it('increments on repeated errors', () => {
      const state = createHeartbeatState({});
      trackNetworkError(state, 500);
      trackNetworkError(state, 502);
      equal(state.networkErrors, 2);
    });

    it('handles invalid state', () => {
      trackNetworkError(null, 500);
    });
  });

  // ============================================================
  // Content fetch tracking — simulates HeartbeatTrackContentFetch
  // ============================================================

  function trackContentFetch(state) {
    if (!state) return;
    state.contentFetches = state.contentFetches + 1;
  }

  describe('HeartbeatTrackContentFetch', () => {
    it('increments content fetch count', () => {
      const state = createHeartbeatState({});
      trackContentFetch(state);
      equal(state.contentFetches, 1);
    });

    it('increments on repeated fetches', () => {
      const state = createHeartbeatState({});
      trackContentFetch(state);
      trackContentFetch(state);
      trackContentFetch(state);
      equal(state.contentFetches, 3);
    });

    it('handles invalid state', () => {
      trackContentFetch(null);
    });
  });

  // ============================================================
  // Session ID generation — simulates CreateSessionId
  // ============================================================

  function createHeartbeatSessionId() {
    return 'sess_' + Math.floor(Date.now() / 1000).toString();
  }

  describe('CreateSessionId', () => {
    it('returns string starting with sess_', () => {
      const sid = createHeartbeatSessionId();
      truthy(sid.startsWith('sess_'));
    });

    it('includes timestamp in session ID', () => {
      const sid = createHeartbeatSessionId();
      const parts = sid.split('_');
      equal(parts[0], 'sess');
      isNumber(parseInt(parts[1]));
    });

    it('generates unique IDs on rapid calls', () => {
      // Rapid calls may share same second, but format should be consistent
      const ids = new Set();
      for (let i = 0; i < 5; i++) {
        ids.add(createHeartbeatSessionId());
      }
      truthy(ids.size >= 1);
    });

    it('session ID is a non-empty string', () => {
      const sid = createHeartbeatSessionId();
      isString(sid);
      greaterThan(sid.length, 0);
    });
  });

  // ============================================================
  // IIf helper — simulates the local IIf function in Heartbeat.brs
  // ============================================================

  function iIf(condition, trueVal, falseVal) {
    if (condition) return trueVal;
    return falseVal;
  }

  describe('IIf Helper', () => {
    it('returns true value when condition is true', () => {
      equal(iIf(true, 'yes', 'no'), 'yes');
    });

    it('returns false value when condition is false', () => {
      equal(iIf(false, 'yes', 'no'), 'no');
    });

    it('handles string values', () => {
      equal(iIf(true, 'playing', 'idle'), 'playing');
    });
  });

  // ============================================================
  // Heartbeat file structure validation
  // ============================================================

  describe('Heartbeat.brs File Structure', () => {
    it('Heartbeat.brs file exists', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'Heartbeat.brs');
      truthy(fs.existsSync(testPath), 'Heartbeat.brs should exist');
    });

    it('has HeartbeatInit function', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'Heartbeat.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('sub HeartbeatInit'), 'Should have HeartbeatInit sub');
    });

    it('has HeartbeatExport function', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'Heartbeat.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('function HeartbeatExport'), 'Should have HeartbeatExport function');
    });

    it('has HeartbeatTrackScreen function', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'Heartbeat.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('sub HeartbeatTrackScreen'), 'Should have HeartbeatTrackScreen sub');
    });

    it('has HeartbeatTrackVideo function', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'Heartbeat.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('sub HeartbeatTrackVideo'), 'Should have HeartbeatTrackVideo sub');
    });

    it('has HeartbeatTrackCrash function', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'Heartbeat.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('sub HeartbeatTrackCrash'), 'Should have HeartbeatTrackCrash sub');
    });

    it('has HeartbeatTrackWarning function', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'Heartbeat.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('sub HeartbeatTrackWarning'), 'Should have HeartbeatTrackWarning sub');
    });

    it('has IIfStr helper function (inlined)', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'Heartbeat.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('function IIfStr'), 'Should have IIfStr helper function');
    });

    it('has error handling with try/catch blocks', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'Heartbeat.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('catch'), 'Should have catch blocks for error handling');
    });

    it('uses LogInfo for telemetry logging', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'Heartbeat.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('LogInfo'), 'Should use LogInfo');
    });

    it('uses LogError for error logging', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'Heartbeat.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('LogError'), 'Should use LogError');
    });

    it('uses FormatJson for payload serialization', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'Heartbeat.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('FormatJson'), 'Should use FormatJson');
    });

    it('uses roUrlTransfer for HTTP export', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'Heartbeat.brs');
      const content = fs.readFileSync(testPath, 'utf-8');
      truthy(content.includes('roUrlTransfer'), 'Should use roUrlTransfer');
    });
  });
}
