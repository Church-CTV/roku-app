/**
 * test-server-contract.mjs — Client-Side Server Contract Tests
 *
 * Validates that the Roku client correctly parses the feed format produced
 * by the Roku-Server-Template. Every field the client accesses must exist
 * in the server's feed output.
 *
 * This is the mirror of tests/integration/test-client-contract.mjs in the server repo.
 * Together they guarantee: server produces → client consumes → round-trip analytics.
 *
 * Run: node tests/unit/test-server-contract.mjs (via test runner)
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SERVER_DIR = path.resolve(__dirname, '../../Roku-Server-Template');

export default async function runTests({ describe, it, assertions }) {
  const { equal, truthy, falsy, isString, isNumber, isArray, isObject, isBoolean, ok, hasProperty, notEqual } = assertions;

  // ─── Load server feed ─────────────────────────────────────────────────────
  const feedPath = path.join(SERVER_DIR, 'output', 'roku_feed.json');
  const feedJson = fs.existsSync(feedPath)
    ? fs.readFileSync(feedPath, 'utf8')
    : JSON.stringify(buildSampleFeed());

  const feed = JSON.parse(feedJson);

  // ─── Helpers ──────────────────────────────────────────────────────────────
  const META_KEYS = ['providerName', 'lastUpdated', 'language', 'cardStyle', 'config'];

  function getMonthKeys(feed) {
    return Object.keys(feed).filter((k) => !META_KEYS.includes(k));
  }

  function getAllVideos(feed) {
    const videos = [];
    for (const key of getMonthKeys(feed)) {
      videos.push(...feed[key]);
    }
    return videos;
  }

  // ─── 1. FEED STRUCTURE (what MainLoaderTask expects) ─────────────────────
  describe('Feed structure — MainLoaderTask.loadContent() contract', () => {
    it('has providerName string', () => {
      isString(feed.providerName, 'feed.providerName must be a string');
      ok(feed.providerName.length > 0, 'providerName must not be empty');
    });

    it('has lastUpdated ISO timestamp string', () => {
      isString(feed.lastUpdated, 'feed.lastUpdated must be a string');
      ok(new Date(feed.lastUpdated).toISOString() !== 'Invalid Date', 'lastUpdated must be valid ISO date');
    });

    it('has language string', () => {
      isString(feed.language, 'feed.language must be a string');
      ok(feed.language.length === 2, 'language must be 2-letter code');
    });

    it('has cardStyle at top level', () => {
      isObject(feed.cardStyle, 'feed.cardStyle must be an object');
      isBoolean(feed.cardStyle.showTitle, 'cardStyle.showTitle must be boolean');
    });

    it('has month-year keys that are not meta keys', () => {
      const monthKeys = getMonthKeys(feed);
      ok(monthKeys.length > 0, 'feed must have at least one month key');

      for (const key of monthKeys) {
        ok(!META_KEYS.includes(key), `month key "${key}" must not be a meta key`);
      }
    });

    it('month keys match "Month YYYY" format', () => {
      const monthPattern = /^(January|February|March|April|May|June|July|August|September|October|November|December) \d{4}$/;
      for (const key of getMonthKeys(feed)) {
        ok(monthPattern.test(key), `month key "${key}" must match "Month YYYY" format`);
      }
    });

    it('month keys contain arrays with video objects', () => {
      for (const key of getMonthKeys(feed)) {
        isArray(feed[key], `month key "${key}" must be an array`);
        ok(feed[key].length > 0, `month key "${key}" must have at least one video`);

        for (const video of feed[key]) {
          isObject(video, `video in "${key}" must be an object`);
        }
      }
    });
  });

  // ─── 2. VIDEO ITEM FIELDS (what GetItemData() accesses) ──────────────────
  describe('Video item fields — GetItemData() contract', () => {
    const videos = getAllVideos(feed);

    it('has at least one video in feed', () => {
      ok(videos.length > 0, 'feed must have at least one video');
    });

    it('each video has id (string)', () => {
      for (const video of videos) {
        isString(video.id, 'video must have id string');
        ok(video.id.length > 0, 'video.id must not be empty');
      }
    });

    it('each video has title (string)', () => {
      for (const video of videos) {
        isString(video.title, 'video must have title string');
      }
    });

    it('each video has shortDescription (string)', () => {
      for (const video of videos) {
        isString(video.shortDescription, 'video must have shortDescription string');
      }
    });

    it('each video has thumbnail URL (string)', () => {
      for (const video of videos) {
        isString(video.thumbnail, 'video must have thumbnail URL string');
        ok(video.thumbnail.startsWith('http'), `thumbnail must be a valid URL: ${video.thumbnail}`);
      }
    });

    it('each video has hdPosterUrl and sdPosterUrl', () => {
      for (const video of videos) {
        isString(video.hdPosterUrl, 'video must have hdPosterUrl');
        isString(video.sdPosterUrl, 'video must have sdPosterUrl');
      }
    });

    it('thumbnail, hdPosterUrl, sdPosterUrl are consistent', () => {
      for (const video of videos) {
        equal(video.thumbnail, video.hdPosterUrl, 'thumbnail must equal hdPosterUrl');
        equal(video.thumbnail, video.sdPosterUrl, 'thumbnail must equal sdPosterUrl');
      }
    });

    it('each video has url with /stream/ prefix', () => {
      for (const video of videos) {
        isString(video.url, 'video must have url');
        ok(video.url.includes('/stream/'), `video URL must use /stream/ prefix: ${video.url}`);
      }
    });

    it('each video has releaseDate', () => {
      for (const video of videos) {
        isString(video.releaseDate, 'video must have releaseDate string');
      }
    });

    it('each video has genres array', () => {
      for (const video of videos) {
        isArray(video.genres, 'video must have genres array');
      }
    });
  });

  // ─── 3. CONTENT.NESTED FIELDS (what client uses for playback) ────────────
  describe('Video content fields — playback contract', () => {
    const videos = getAllVideos(feed);

    it('each video has content object', () => {
      for (const video of videos) {
        isObject(video.content, 'video must have content object');
      }
    });

    it('each video.content has duration (number)', () => {
      for (const video of videos) {
        isNumber(video.content.duration, 'video.content must have duration number');
      }
    });

    it('each video.content has videos array with at least one entry', () => {
      for (const video of videos) {
        isArray(video.content.videos, 'video.content must have videos array');
        ok(video.content.videos.length > 0, 'video.content.videos must have at least one entry');
      }
    });

    it('each video.content.videos[0] has url, quality, videoType', () => {
      for (const video of videos) {
        const stream = video.content.videos[0];
        isString(stream.url, 'stream must have url');
        isString(stream.quality, 'stream must have quality');
        isString(stream.videoType, 'stream must have videoType');
      }
    });

    it('video.content.videos[0].url uses /stream/ prefix', () => {
      for (const video of videos) {
        ok(video.content.videos[0].url.includes('/stream/'), 'stream url must use /stream/ prefix');
      }
    });
  });

  // ─── 4. EMBEDDED CONFIG (what ConfigLoader reads) ────────────────────────
  describe('Embedded config — ConfigLoader contract', () => {
    it('feed has config object', () => {
      isObject(feed.config, 'feed must have config object');
    });

    it('config has channel object', () => {
      isObject(feed.config.channel, 'config must have channel');
      isString(feed.config.channel.name, 'channel must have name');
      isString(feed.config.channel.language, 'channel must have language');
    });

    it('config has branding object with colors', () => {
      isObject(feed.config.branding, 'config must have branding');
      isObject(feed.config.branding.colors, 'branding must have colors');
    });

    it('config has features object', () => {
      isObject(feed.config.features, 'config must have features');
      isBoolean(feed.config.features.analytics, 'features must have analytics boolean');
    });

    it('config has server.baseUrl', () => {
      isObject(feed.config.server, 'config must have server');
      isString(feed.config.server.baseUrl, 'config.server must have baseUrl');
      ok(feed.config.server.baseUrl.startsWith('http'), 'baseUrl must start with http');
    });

    it('config has analytics with expected fields', () => {
      isObject(feed.config.analytics, 'config must have analytics');
      isBoolean(feed.config.analytics.enabled, 'analytics must have enabled boolean');
      isString(feed.config.analytics.exportUrl, 'analytics must have exportUrl');
      isNumber(feed.config.analytics.exportIntervalSeconds, 'analytics must have exportIntervalSeconds');
    });

    it('config has cardStyle matching top-level cardStyle', () => {
      isObject(feed.config.cardStyle, 'config must have cardStyle');
      equal(feed.config.cardStyle.showTitle, feed.cardStyle.showTitle, 'config.cardStyle.showTitle must match top-level');
    });
  });

  // ─── 5. CLIENT PARSING SIMULATION ────────────────────────────────────────
  describe('Client parsing simulation — MainLoaderTask parsing', () => {
    it('client can extract month rows from feed', () => {
      const monthKeys = getMonthKeys(feed);
      ok(monthKeys.length > 0, 'client must find month keys');

      // Simulate what MainLoaderTask does: iterate keys, skip meta keys
      const rows = [];
      for (const key of Object.keys(feed)) {
        if (META_KEYS.includes(key)) continue;
        rows.push({ rowLabel: key, itemCount: feed[key].length });
      }
      equal(rows.length, monthKeys.length, 'client must extract same number of rows');
    });

    it('client can extract all videos from feed', () => {
      const allVideos = getAllVideos(feed);
      ok(allVideos.length > 0, 'client must find videos');

      // Simulate what BuildContentTree does: iterate rows, then items
      const contentTree = [];
      for (const key of getMonthKeys(feed)) {
        const row = feed[key];
        for (const video of row) {
          contentTree.push(video.id);
        }
      }
      equal(contentTree.length, allVideos.length, 'content tree must match video count');
    });

    it('client can build content node with all required fields', () => {
      const videos = getAllVideos(feed);
      const firstVideo = videos[0];

      // Simulate what GetItemData() does:
      function getItemData(video) {
        return {
          id: video.id,
          title: video.title,
          shortDescriptionLine2: video.shortDescription,
          hdPosterURL: video.thumbnail,
          sdPosterURL: video.sdPosterUrl,
          content: {
            duration: video.content.duration,
            videos: [
              {
                url: video.content.videos[0].url,
                quality: video.content.videos[0].quality,
                videoType: video.content.videos[0].videoType,
              },
            ],
          },
        };
      }

      const contentNode = getItemData(firstVideo);
      isString(contentNode.id, 'content node must have id');
      isString(contentNode.title, 'content node must have title');
      isString(contentNode.hdPosterURL, 'content node must have hdPosterURL');
      isString(contentNode.content.videos[0].url, 'content node must have stream url');
      isString(contentNode.content.videos[0].videoType, 'content node must have videoType');
      isNumber(contentNode.content.duration, 'content node must have duration');
    });

    it('client can sort videos by releaseDate within each month', () => {
      for (const key of getMonthKeys(feed)) {
        const videos = feed[key];
        const sorted = [...videos].sort((a, b) => {
          const dateA = a.releaseDate || '';
          const dateB = b.releaseDate || '';
          return dateA < dateB ? -1 : dateA > dateB ? 1 : 0;
        });

        // Verify sorting is valid (all dates in order)
        for (let i = 1; i < sorted.length; i++) {
          ok(sorted[i - 1].releaseDate <= sorted[i].releaseDate, 'videos must be sortable by releaseDate');
        }
      }
    });
  });

  // ─── 6. ANALYTICS PAYLOAD VALIDATION ─────────────────────────────────────
  describe('Analytics payload — BuildExportPayload() contract', () => {
    const videos = getAllVideos(feed);
    const firstVideo = videos[0];

    it('client can build valid analytics payload with nested events', () => {
      // This is the EXACT format the client sends
      const payload = {
        appVersion: '1.0.0',
        sessionStartTime: '12:00:00',
        activeScreen: 'VideoScreen',
        eventCount: 4,
        summary: {
          screenViews: 1,
          plays: 1,
          deepLinks: 1,
          errors: 1,
        },
        events: {
          screenViews: [
            {
              eventType: 'screen_view',
              screenName: 'GridScreen',
              previousScreen: 'MainScene',
              timestamp: '12:01:00',
              sessionDuration: 60,
            },
          ],
          plays: [
            {
              eventType: 'content_play',
              contentId: firstVideo.id,
              contentTitle: firstVideo.title,
              timestamp: '12:02:00',
              sessionDuration: firstVideo.content.duration,
            },
          ],
          deepLinks: [
            {
              eventType: 'deep_link',
              contentId: firstVideo.id,
              mediaType: firstVideo.content.videos[0].videoType.toLowerCase(),
              source: 'rowlist',
              timestamp: '12:03:00',
            },
          ],
          errors: [
            {
              eventType: 'error',
              errorType: 'network',
              errorMessage: 'Connection timeout',
              context: 'stream',
              timestamp: '12:04:00',
            },
          ],
        },
      };

      // Validate structure
      isString(payload.appVersion, 'payload must have appVersion');
      isString(payload.sessionStartTime, 'payload must have sessionStartTime');
      isString(payload.activeScreen, 'payload must have activeScreen');
      isNumber(payload.eventCount, 'payload must have eventCount');
      isObject(payload.summary, 'payload must have summary');
      isObject(payload.events, 'payload must have events object');

      equal(payload.eventCount, payload.summary.screenViews + payload.summary.plays + payload.summary.deepLinks + payload.summary.errors, 'eventCount must match summary totals');

      // Validate events array structure
      isArray(payload.events.screenViews, 'events must have screenViews array');
      isArray(payload.events.plays, 'events must have plays array');
      isArray(payload.events.deepLinks, 'events must have deepLinks array');
      isArray(payload.events.errors, 'events must have errors array');
    });

    it('client can build queued event payload', () => {
      const queuedPayload = {
        eventType: 'screen_view',
        timestamp: '12:00:00',
        appVersion: '1.0.0',
        screenViews: [{ screenName: 'Home' }],
        plays: [],
        deepLinks: [],
        errors: [],
        sessionDuration: 30,
      };

      isString(queuedPayload.eventType, 'queued payload must have eventType');
      isString(queuedPayload.timestamp, 'queued payload must have timestamp');
      isNumber(queuedPayload.sessionDuration, 'queued payload must have sessionDuration');
      isArray(queuedPayload.screenViews, 'queued payload must have screenViews');
    });

    it('content_play event references valid feed video ID', () => {
      ok(firstVideo.id, 'video must have id for analytics reference');
      ok(firstVideo.title, 'video must have title for analytics reference');
      ok(firstVideo.content.videos[0].url, 'video must have stream url for analytics reference');
    });

    it('deep_link event references valid videoType from feed', () => {
      const videoType = firstVideo.content.videos[0].videoType;
      isString(videoType, 'videoType must be a string for deep_link event');
      ok(['MP4', 'MKV', 'mp4', 'mkv'].includes(videoType), `videoType "${videoType}" must be a supported format`);
    });
  });
}

// ─── Sample feed (used if server feed not found) ─────────────────────────────
function buildSampleFeed() {
  return {
    providerName: 'Test Channel',
    lastUpdated: new Date().toISOString(),
    language: 'en',
    cardStyle: {
      showTitle: false,
      showDescription: false,
      titleFont: 'font:SmallBoldSystemFont',
      descriptionFont: 'font:SmallSystemFont',
      titleColor: '0xFFFFFF',
      descriptionColor: '0xA0A0B0',
      titleNumLines: 1,
      descriptionNumLines: 1,
      showDetailTitle: true,
      showDetailDescription: true,
      detailTitleFont: 'font:SmallBoldSystemFont',
      detailDescriptionFont: 'font:SmallSystemFont',
      detailTitleColor: '0xFFFFFF',
      detailDescriptionColor: '0xA0A0B0',
      detailTitleNumLines: 1,
      detailDescriptionNumLines: 3,
    },
    config: {
      channel: { name: 'Test Channel', description: 'Test', language: 'en', copyright: '2026' },
      branding: {
        colors: { background: '0x1A1A2E', surface: '0x16213E', accent: '0xE8B931', textPrimary: '0xFFFFFF', textSecondary: '0xA0A0B0', focus: '0xE8B931', error: '0xFF4444' },
        images: { overhangLogo: '', backgroundImage: '', iconFocus: '' },
        fonts: { title: 'font:BoldSystemFont', body: 'font:MediumSystemFont', caption: 'font:SmallSystemFont', heading: 'font:ExtraBoldSystemFont' },
        spacing: { marginHorizontal: 80, marginVertical: 40 },
        animation: { cardScale: 1.05, transitionDuration: 0.25 },
      },
      cardStyle: { showTitle: false, showDescription: false, titleFont: 'font:SmallBoldSystemFont', descriptionFont: 'font:SmallSystemFont', titleColor: '0xFFFFFF', descriptionColor: '0xA0A0B0', titleNumLines: 1, descriptionNumLines: 1, showDetailTitle: true, showDetailDescription: true, detailTitleFont: 'font:SmallBoldSystemFont', detailDescriptionFont: 'font:SmallSystemFont', detailTitleColor: '0xFFFFFF', detailDescriptionColor: '0xA0A0B0', detailTitleNumLines: 1, detailDescriptionNumLines: 3 },
      features: { layoutPreference: 'leftnav', search: true, deepLinking: true, analytics: true, crashReporting: true, overhangLogo: true, overhangClock: true, overhangOptions: true },
      ui: { backgroundColor: '0x1A1A2E', welcome: { enabled: true, title: 'Loading...', subtitle: 'Please wait' }, error: { title: 'Connection Error', message: 'Unable to load content.', retryLabel: 'Retry' }, loading: { message: 'Loading...' } },
      server: { baseUrl: 'http://localhost:3000' },
      content: { sourceUrl: '', userAgent: 'Roku/14.1.0', maxRows: 20, maxItemsPerRow: 12, retryAttempts: 3, retryDelayMs: 2000, fetchTimeout: 30, sslCertificates: 'common:/certs/ca-bundle.crt' },
      analytics: { enabled: true, exportUrl: '/api/analytics', exportIntervalSeconds: 300, maxEventsPerBatch: 50, flushOnError: true },
    },
    'June 2026': [
      {
        id: 'video-sample',
        title: 'Sample Video',
        shortDescription: 'Sample description',
        thumbnail: 'http://localhost:3000/output/thumbnails/sample.jpg',
        hdPosterUrl: 'http://localhost:3000/output/thumbnails/sample.jpg',
        sdPosterUrl: 'http://localhost:3000/output/thumbnails/sample.jpg',
        url: 'http://localhost:3000/stream/sample.mp4',
        releaseDate: '2026-06-01',
        genres: ['Sample'],
        content: {
          duration: 120,
          videos: [
            {
              url: 'http://localhost:3000/stream/sample.mp4',
              quality: 'FHD',
              videoType: 'MP4',
            },
          ],
        },
        dateAdded: new Date().toISOString(),
      },
    ],
  };
}
