/**
 * Unit Tests: ConfigLoader.bs
 * 
 * Tests configuration loading, validation, merging, and default config
 * by re-implementing the BrightScript logic in JavaScript.
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = path.resolve(__dirname, '..');

export default async function runTests({ describe, it, assertions }) {
  const { equal, deepEqual, truthy, falsy, isString, isNumber, 
           isArray, isObject, includes, hasProperty, match, 
           greaterThan, lessThan, exists } = assertions;

  // Load the actual config file
  const defaultConfigPath = path.join(ROOT_DIR, '..', 'config', 'default.json');
  const defaultConfig = JSON.parse(fs.readFileSync(defaultConfigPath, 'utf-8'));

  // ============================================================
  // LoadDefaultConfig tests
  // ============================================================

  function loadDefaultConfig() {
    return {
      version: '1.0.0',
      channel: { name: 'Roku Channel', description: 'Roku App Template Service', language: 'en', copyright: '' },
      branding: {
        colors: {
          background: '0x1A1A2E', surface: '0x16213E', accent: '0xE8B931',
          textPrimary: '0xFFFFFF', textSecondary: '0xA0A0B0', focus: '0xE8B931', error: '0xFF4444',
        },
        images: { overhangLogo: 'pkg:/images/hd_overhang_logo.png', backgroundImage: 'pkg:/images/background.png', iconFocus: 'pkg:/images/icon_focus_hd.png' },
        fonts: { title: 'font:BoldSystemFont', body: 'font:MediumSystemFont', caption: 'font:SmallSystemFont', heading: 'font:ExtraBoldSystemFont' },
        spacing: { marginHorizontal: 80, marginVertical: 40 },
        animation: { cardScale: 1.05, transitionDuration: 0.25 },
      },
      content: { sourceUrl: '', userAgent: 'Roku/Template', maxRows: 6, maxItemsPerRow: 12, retryAttempts: 3, retryDelayMs: 2000, sslCertificates: 'common:/certs/ca-bundle.crt' },
      features: { search: true, deepLinking: true, analytics: true, crashReporting: true, overhangLogo: true, overhangClock: false, overhangOptions: false },
      ui: { backgroundColor: '0x1A1A2E', welcome: { enabled: true, title: 'Loading...', subtitle: 'Please wait' }, error: { title: 'Connection Error', message: 'Unable to load content.', retryLabel: 'Retry' }, loading: { message: 'Loading...' } },
      analytics: { enabled: true, exportUrl: '', exportIntervalSeconds: 300, maxEventsPerBatch: 50, flushOnError: true },
      cardStyle: { showTitle: true, showDescription: true, titleFont: 'font:SmallBoldSystemFont', descriptionFont: 'font:SmallSystemFont', titleColor: '0xFFFFFF', descriptionColor: '0xA0A0B0', titleNumLines: 1, descriptionNumLines: 1 },
    };
  }

  describe('LoadDefaultConfig', () => {
    it('returns valid config object', () => {
      const config = loadDefaultConfig();
      isObject(config);
      hasProperty(config, 'version');
      hasProperty(config, 'channel');
      hasProperty(config, 'branding');
    });

    it('has correct default version', () => {
      const config = loadDefaultConfig();
      equal(config.version, '1.0.0');
    });

    it('has all required top-level fields', () => {
      const config = loadDefaultConfig();
      hasProperty(config, 'version');
      hasProperty(config, 'channel');
      hasProperty(config, 'branding');
      hasProperty(config, 'content');
      hasProperty(config, 'features');
    });

    it('has default channel name', () => {
      const config = loadDefaultConfig();
      equal(config.channel.name, 'Roku Channel');
    });
  });

  // ============================================================
  // ValidateConfig tests
  // ============================================================

  function validateConfig(config) {
    const errors = [];

    if (!config || typeof config !== 'object' || Array.isArray(config)) {
      errors.push('Config must be a valid associative array');
      return errors;
    }

    // Check required top-level fields
    const requiredFields = ['version', 'channel', 'branding', 'content', 'features'];
    for (const field of requiredFields) {
      if (!(field in config)) {
        errors.push(`Missing required field: ${field}`);
      }
    }

    // Validate channel.name
    if (config.channel && typeof config.channel === 'object' && !Array.isArray(config.channel)) {
      if (!('name' in config.channel) || config.channel.name === '') {
        errors.push('channel.name is required and cannot be empty');
      }
    } else {
      errors.push('channel object is required');
    }

    // Validate branding.colors
    if (config.branding && typeof config.branding === 'object' && !Array.isArray(config.branding)) {
      if (config.branding.colors) {
        const colorFields = ['background', 'surface', 'accent', 'textPrimary', 'textSecondary', 'focus', 'error'];
        for (const colorField of colorFields) {
          if (!(colorField in config.branding.colors)) {
            errors.push(`Missing branding.colors.${colorField}`);
          }
        }
      }
    }

    // Validate content.maxRows
    if (config.content && typeof config.content === 'object' && !Array.isArray(config.content)) {
      if (config.content.maxRows !== undefined) {
        if (typeof config.content.maxRows !== 'number' || config.content.maxRows < 1 || config.content.maxRows > 20) {
          errors.push('content.maxRows must be a number between 1 and 20');
        }
      }
    }

    return errors;
  }

  describe('ValidateConfig', () => {
    it('validates complete config', () => {
      const errors = validateConfig(loadDefaultConfig());
      equal(errors.length, 0, 'Default config should have no validation errors');
    });

    it('detects missing version field', () => {
      const config = { channel: { name: 'Test' }, branding: {}, content: {}, features: {} };
      const errors = validateConfig(config);
      includes(errors[0], 'Missing required field: version');
    });

    it('detects missing channel', () => {
      const config = { version: '1.0.0', branding: {}, content: {}, features: {} };
      const errors = validateConfig(config);
      includes(errors[0], 'Missing required field: channel');
    });

    it('detects empty channel name', () => {
      const config = { version: '1.0.0', channel: { name: '' }, branding: {}, content: {}, features: {} };
      const errors = validateConfig(config);
      includes(errors[0], 'channel.name is required');
    });

    it('detects invalid maxRows', () => {
      const config = { version: '1.0.0', channel: { name: 'T' }, branding: {}, content: { maxRows: 0 }, features: {} };
      const errors = validateConfig(config);
      includes(errors[0], 'content.maxRows');
    });

    it('returns errors for null config', () => {
      const errors = validateConfig(null);
      greaterThan(errors.length, 0);
    });

    it('returns errors for array config', () => {
      const errors = validateConfig([]);
      greaterThan(errors.length, 0);
    });
  });

  // ============================================================
  // MergeConfig tests
  // ============================================================

  function mergeConfig(defaults, overrides) {
    const result = { ...defaults };
    for (const [key, value] of Object.entries(overrides)) {
      if (value !== undefined && typeof value === 'object' && !Array.isArray(value) && value !== null) {
        if (result[key] && typeof result[key] === 'object' && !Array.isArray(result[key])) {
          result[key] = mergeConfig(result[key], value);
        } else {
          result[key] = value;
        }
      } else if (value !== undefined) {
        result[key] = value;
      }
    }
    return result;
  }

  describe('MergeConfig', () => {
    it('merges top-level fields', () => {
      const defaults = { a: 1, b: 2, c: 3 };
      const overrides = { b: 20, d: 4 };
      const merged = mergeConfig(defaults, overrides);
      equal(merged.a, 1);
      equal(merged.b, 20);
      equal(merged.c, 3);
      equal(merged.d, 4);
    });

    it('merges nested objects', () => {
      const defaults = { channel: { name: 'Default', desc: 'Default desc' } };
      const overrides = { channel: { name: 'Override' } };
      const merged = mergeConfig(defaults, overrides);
      equal(merged.channel.name, 'Override');
      equal(merged.channel.desc, 'Default desc');
    });

    it('handles missing override fields', () => {
      const defaults = { a: 1, b: 2 };
      const overrides = { a: 10 };
      const merged = mergeConfig(defaults, overrides);
      equal(merged.a, 10);
      equal(merged.b, 2);
    });
  });

  // ============================================================
  // LoadConfig integration tests (with actual config file)
  // ============================================================

  describe('LoadConfig (actual file)', () => {
    it('reads valid config file', () => {
      exists(defaultConfigPath);
    });

    it('parses default.json correctly', () => {
      isObject(defaultConfig);
      hasProperty(defaultConfig, 'version');
      equal(defaultConfig.version, '1.0.0');
    });

    it('has valid channel config', () => {
      isObject(defaultConfig.channel);
      isString(defaultConfig.channel.name);
      greaterThan(defaultConfig.channel.name.length, 0);
    });

    it('has valid branding colors', () => {
      isObject(defaultConfig.branding.colors);
      hasProperty(defaultConfig.branding.colors, 'background');
      hasProperty(defaultConfig.branding.colors, 'accent');
      match(defaultConfig.branding.colors.background, /^0x[0-9A-Fa-f]{6}$/);
    });

    it('has valid content config', () => {
      isObject(defaultConfig.content);
      isNumber(defaultConfig.content.maxRows);
      greaterThan(defaultConfig.content.maxRows, 0);
      lessThan(defaultConfig.content.maxRows, 50);
      isNumber(defaultConfig.content.retryAttempts);
    });

    it('has valid feature flags', () => {
      isObject(defaultConfig.features);
      truthy(typeof defaultConfig.features.search === 'boolean', 'search should be boolean');
      truthy(typeof defaultConfig.features.deepLinking === 'boolean', 'deepLinking should be boolean');
    });
  });

  // ============================================================
  // Config Schema validation tests
  // ============================================================

  describe('Config Schema Compliance', () => {
    it('all color values are valid hex', () => {
      const hexRegex = /^0x[0-9A-Fa-f]{6}$/;
      for (const [key, value] of Object.entries(defaultConfig.branding.colors)) {
        match(value, hexRegex, `${key} should be valid hex color`);
      }
    });

    it('font references are valid', () => {
      const fontRegex = /^font:(\w+SystemFont)$/;
      for (const [key, value] of Object.entries(defaultConfig.branding.fonts)) {
        match(value, fontRegex, `${key} should be valid font reference`);
      }
    });

    it('spacing values are positive numbers', () => {
      for (const [key, value] of Object.entries(defaultConfig.branding.spacing)) {
        isNumber(value);
        greaterThan(value, 0);
      }
    });

    it('animation values are valid', () => {
      greaterThan(defaultConfig.branding.animation.cardScale, 0);
      greaterThan(defaultConfig.branding.animation.transitionDuration, 0);
      lessThan(defaultConfig.branding.animation.transitionDuration, 2);
    });
  });
}
