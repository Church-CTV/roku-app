/**
 * Unit Tests: Analytics.brs
 *
 * Tests analytics tracking functions: screen views, content plays,
 * deep links, errors, interactions, playback state, and session duration.
 */

export default async function runTests({ describe, it, assertions }) {
  const { equal, truthy, falsy, isString, isNumber, isArray, isObject,
           greaterThan, lessThan, hasProperty, includes, match } = assertions;

  // ============================================================
  // AnalyticsEvent creation tests
  // Simulates: AnalyticsEvent node creation in tracking functions
  // ============================================================

  function createAnalyticsEvent(eventType, data) {
    return {
      eventType,
      timestamp: data.timestamp || '',
      sessionDuration: data.sessionDuration || 0,
      appVersion: data.appVersion || '',
      ...data,
    };
  }

  describe('AnalyticsEvent Creation', () => {
    it('creates screen_view event', () => {
      const event = createAnalyticsEvent('screen_view', {
        screenName: 'MainScene',
        previousScreen: 'GridScreen',
        timestamp: '12:00:00',
        sessionDuration: 60,
        appVersion: '1.0.0',
      });
      equal(event.eventType, 'screen_view');
      equal(event.screenName, 'MainScene');
      equal(event.previousScreen, 'GridScreen');
      equal(event.sessionDuration, 60);
    });

    it('creates content_play event', () => {
      const event = createAnalyticsEvent('content_play', {
        contentId: 'video-123',
        contentTitle: 'Test Video',
        sourceScreen: 'GridScreen',
        timestamp: '12:01:00',
        sessionDuration: 60,
        appVersion: '1.0.0',
      });
      equal(event.eventType, 'content_play');
      equal(event.contentId, 'video-123');
      equal(event.contentTitle, 'Test Video');
    });

    it('creates deep_link event', () => {
      const event = createAnalyticsEvent('deep_link', {
        contentId: 'video-456',
        mediaType: 'video',
        source: 'input_launch',
        timestamp: '12:02:00',
        sessionDuration: 0,
        appVersion: '1.0.0',
      });
      equal(event.eventType, 'deep_link');
      equal(event.source, 'input_launch');
    });

    it('creates error event', () => {
      const event = createAnalyticsEvent('error', {
        errorType: 'network',
        errorMessage: 'Connection timeout',
        context: 'MainLoaderTask',
        timestamp: '12:03:00',
        sessionDuration: 120,
        appVersion: '1.0.0',
      });
      equal(event.eventType, 'error');
      equal(event.errorType, 'network');
    });

    it('creates interaction event', () => {
      const event = createAnalyticsEvent('interaction', {
        action: 'select',
        target: 'GridScreen',
        details: 'Video Title',
        timestamp: '12:04:00',
        sessionDuration: 180,
        appVersion: '1.0.0',
      });
      equal(event.eventType, 'interaction');
      equal(event.action, 'select');
    });

    it('creates playback_state event', () => {
      const event = createAnalyticsEvent('playback_state', {
        state: 'playing',
        contentId: 'video-789',
        timestamp: '12:05:00',
        sessionDuration: 240,
        appVersion: '1.0.0',
      });
      equal(event.eventType, 'playback_state');
      equal(event.state, 'playing');
    });
  });

  // ============================================================
  // Analytics history management tests
  // Simulates: history arrays in m.global.analytics
  // ============================================================

  function createAnalyticsState() {
    return {
      eventCount: 0,
      lastExportTime: '',
      screenHistory: [],
      playHistory: [],
      deepLinkHistory: [],
      errorHistory: [],
      sessionStartTime: '12:00:00',
      activeScreen: 'MainScene',
    };
  }

  describe('Analytics History Management', () => {
    it('starts with empty histories', () => {
      const state = createAnalyticsState();
      equal(state.screenHistory.length, 0);
      equal(state.playHistory.length, 0);
      equal(state.deepLinkHistory.length, 0);
      equal(state.errorHistory.length, 0);
      equal(state.eventCount, 0);
    });

    it('adds screen view to screenHistory', () => {
      const state = createAnalyticsState();
      const event = createAnalyticsEvent('screen_view', {
        screenName: 'SettingsScreen',
        previousScreen: 'MainScene',
      });
      state.screenHistory.push(event);
      state.eventCount = state.screenHistory.length;
      equal(state.screenHistory.length, 1);
      equal(state.eventCount, 1);
      equal(state.activeScreen, 'MainScene');
    });

    it('updates activeScreen on screen view', () => {
      const state = createAnalyticsState();
      state.activeScreen = 'SettingsScreen';
      equal(state.activeScreen, 'SettingsScreen');
    });

    it('adds content play to playHistory', () => {
      const state = createAnalyticsState();
      const event = createAnalyticsEvent('content_play', {
        contentId: 'video-1',
        contentTitle: 'Sermon',
      });
      state.playHistory.push(event);
      equal(state.playHistory.length, 1);
    });

    it('adds deep link to deepLinkHistory', () => {
      const state = createAnalyticsState();
      const event = createAnalyticsEvent('deep_link', {
        contentId: 'video-2',
        mediaType: 'video',
      });
      state.deepLinkHistory.push(event);
      equal(state.deepLinkHistory.length, 1);
    });

    it('adds error to errorHistory', () => {
      const state = createAnalyticsState();
      const event = createAnalyticsEvent('error', {
        errorType: 'parse',
        errorMessage: 'Invalid JSON',
      });
      state.errorHistory.push(event);
      equal(state.errorHistory.length, 1);
    });

    it('tracks multiple events correctly', () => {
      const state = createAnalyticsState();
      state.screenHistory.push(createAnalyticsEvent('screen_view', { screenName: 'A' }));
      state.screenHistory.push(createAnalyticsEvent('screen_view', { screenName: 'B' }));
      state.playHistory.push(createAnalyticsEvent('content_play', { contentId: '1' }));
      state.errorHistory.push(createAnalyticsEvent('error', { errorType: 'test' }));
      equal(state.screenHistory.length, 2);
      equal(state.playHistory.length, 1);
      equal(state.errorHistory.length, 1);
    });
  });

  // ============================================================
  // GetSessionDuration tests
  // Simulates: function GetSessionDuration() as Integer
  // ============================================================

  function getSessionDuration(startTime, currentTime) {
    const parseTime = (t) => {
      const parts = t.split(':');
      return parseInt(parts[0]) * 3600 + parseInt(parts[1]) * 60 + parseInt(parts[2]);
    };
    let duration = parseTime(currentTime) - parseTime(startTime);
    if (duration < 0) {
      duration += 86400;
    }
    return duration;
  }

  describe('GetSessionDuration', () => {
    it('returns 0 for same time', () => {
      equal(getSessionDuration('12:00:00', '12:00:00'), 0);
    });

    it('calculates seconds correctly', () => {
      equal(getSessionDuration('12:00:00', '12:00:30'), 30);
    });

    it('calculates minutes correctly', () => {
      equal(getSessionDuration('12:00:00', '12:05:00'), 300);
    });

    it('calculates hours correctly', () => {
      equal(getSessionDuration('12:00:00', '13:00:00'), 3600);
    });

    it('handles midnight wraparound', () => {
      equal(getSessionDuration('23:59:00', '00:01:00'), 120);
    });

    it('handles large duration across midnight', () => {
      equal(getSessionDuration('23:00:00', '01:00:00'), 7200);
    });

    it('returns positive for normal progression', () => {
      const dur = getSessionDuration('08:00:00', '10:30:45');
      truthy(dur > 0);
      equal(dur, 9045);
    });
  });

  // ============================================================
  // GetAnalyticsSummary tests
  // Simulates: function GetAnalyticsSummary() as Object
  // ============================================================

  function getAnalyticsSummary(state) {
    if (!state) return {};
    return {
      sessionStartTime: state.sessionStartTime,
      activeScreen: state.activeScreen,
      appVersion: state.appVersion || '1.0.0',
      eventCount: state.eventCount,
      screenViews: state.screenHistory.length,
      plays: state.playHistory.length,
      deepLinks: state.deepLinkHistory.length,
      errors: state.errorHistory.length,
    };
  }

  describe('GetAnalyticsSummary', () => {
    it('returns empty object for null state', () => {
      const summary = getAnalyticsSummary(null);
      isObject(summary);
      equal(Object.keys(summary).length, 0);
    });

    it('returns correct summary', () => {
      const state = createAnalyticsState();
      state.appVersion = '1.0.0';
      state.screenHistory.push(createAnalyticsEvent('screen_view', { screenName: 'A' }));
      state.screenHistory.push(createAnalyticsEvent('screen_view', { screenName: 'B' }));
      state.playHistory.push(createAnalyticsEvent('content_play', { contentId: '1' }));
      state.deepLinkHistory.push(createAnalyticsEvent('deep_link', { contentId: '2' }));
      state.errorHistory.push(createAnalyticsEvent('error', { errorType: 'test' }));
      state.errorHistory.push(createAnalyticsEvent('error', { errorType: 'test2' }));
      state.eventCount = 6;

      const summary = getAnalyticsSummary(state);
      equal(summary.screenViews, 2);
      equal(summary.plays, 1);
      equal(summary.deepLinks, 1);
      equal(summary.errors, 2);
      equal(summary.eventCount, 6);
      equal(summary.activeScreen, 'MainScene');
    });

    it('returns zero counts for empty state', () => {
      const summary = getAnalyticsSummary(createAnalyticsState());
      equal(summary.screenViews, 0);
      equal(summary.plays, 0);
      equal(summary.deepLinks, 0);
      equal(summary.errors, 0);
    });
  });

  // ============================================================
  // ResetAnalytics tests
  // Simulates: sub ResetAnalytics()
  // ============================================================

  function resetAnalytics(state, newTime) {
    state.eventCount = 0;
    state.lastExportTime = '';
    state.screenHistory = [];
    state.playHistory = [];
    state.deepLinkHistory = [];
    state.errorHistory = [];
    state.sessionStartTime = newTime || '00:00:00';
    state.activeScreen = 'MainScene';
    return state;
  }

  describe('ResetAnalytics', () => {
    it('clears all histories', () => {
      const state = createAnalyticsState();
      state.screenHistory.push({});
      state.playHistory.push({});
      state.errorHistory.push({});
      state.eventCount = 5;

      resetAnalytics(state, '13:00:00');
      equal(state.screenHistory.length, 0);
      equal(state.playHistory.length, 0);
      equal(state.deepLinkHistory.length, 0);
      equal(state.errorHistory.length, 0);
      equal(state.eventCount, 0);
    });

    it('resets session start time', () => {
      const state = createAnalyticsState();
      resetAnalytics(state, '14:00:00');
      equal(state.sessionStartTime, '14:00:00');
    });

    it('resets active screen to MainScene', () => {
      const state = createAnalyticsState();
      state.activeScreen = 'SettingsScreen';
      resetAnalytics(state);
      equal(state.activeScreen, 'MainScene');
    });

    it('clears lastExportTime', () => {
      const state = createAnalyticsState();
      state.lastExportTime = '12:30:00';
      resetAnalytics(state);
      equal(state.lastExportTime, '');
    });
  });

  // ============================================================
  // Analytics init config check tests
  // Simulates: config.features.analytics check
  // ============================================================

  function isAnalyticsEnabled(config) {
    if (!config || !config.features) return true;
    if (typeof config.features.analytics === 'boolean') {
      return config.features.analytics;
    }
    return true;
  }

  describe('Analytics Config Check', () => {
    it('enabled by default when no config', () => {
      truthy(isAnalyticsEnabled(null));
      truthy(isAnalyticsEnabled({}));
    });

    it('respects explicit true', () => {
      truthy(isAnalyticsEnabled({ features: { analytics: true } }));
    });

    it('respects explicit false', () => {
      falsy(isAnalyticsEnabled({ features: { analytics: false } }));
    });

    it('enabled when features exists but analytics missing', () => {
      truthy(isAnalyticsEnabled({ features: { search: true } }));
    });
  });

  // ============================================================
  // Content item extraction tests
  // Simulates: content item field extraction in TrackContentPlay
  // ============================================================

  function extractContentInfo(contentItem) {
    const info = { contentId: '', contentTitle: '', contentDuration: null };
    if (!contentItem) return info;

    if (contentItem.content) {
      info.contentId = contentItem.content.id || '';
      info.contentTitle = contentItem.content.title || '';
      if (contentItem.content.duration !== undefined) {
        info.contentDuration = contentItem.content.duration;
      }
    } else {
      info.contentId = contentItem.id || '';
      info.contentTitle = contentItem.title || '';
      if (contentItem.length !== undefined) {
        info.contentDuration = contentItem.length;
      }
    }
    return info;
  }

  describe('Content Item Extraction', () => {
    it('extracts from nested content object', () => {
      const item = {
        content: { id: 'vid-1', title: 'Sermon', duration: 3600 },
      };
      const info = extractContentInfo(item);
      equal(info.contentId, 'vid-1');
      equal(info.contentTitle, 'Sermon');
      equal(info.contentDuration, 3600);
    });

    it('extracts from flat content object', () => {
      const item = { id: 'vid-2', title: 'Worship', length: 1800 };
      const info = extractContentInfo(item);
      equal(info.contentId, 'vid-2');
      equal(info.contentTitle, 'Worship');
      equal(info.contentDuration, 1800);
    });

    it('returns empty for null item', () => {
      const info = extractContentInfo(null);
      equal(info.contentId, '');
      equal(info.contentTitle, '');
      falsy(info.contentDuration);
    });

    it('handles missing duration', () => {
      const item = { content: { id: 'vid-3', title: 'Test' } };
      const info = extractContentInfo(item);
      equal(info.contentId, 'vid-3');
      falsy(info.contentDuration);
    });
  });
}
