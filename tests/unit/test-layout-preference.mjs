/**
 * Unit Tests: Layout Preference Configuration
 *
 * Tests the layout preference config option, schema compliance,
 * and config consistency.
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = path.resolve(__dirname, '..');

export default async function runTests({ describe, it, assertions }) {
  const { equal, truthy, isString, includes, hasProperty, match, exists, isBoolean, greaterThan } = assertions;

  const defaultConfigPath = path.join(ROOT_DIR, '..', 'config', 'default.json');
  const schemaPath = path.join(ROOT_DIR, '..', 'config', 'schema.json');

  const defaultConfig = JSON.parse(fs.readFileSync(defaultConfigPath, 'utf-8'));
  const schema = JSON.parse(fs.readFileSync(schemaPath, 'utf-8'));

  // ============================================================
  // Config default.json Tests
  // ============================================================

  describe('default.json layoutPreference', () => {
    it('has features object', () => {
      hasProperty(defaultConfig, 'features');
      truthy(defaultConfig.features);
    });

    it('has layoutPreference in features', () => {
      hasProperty(defaultConfig.features, 'layoutPreference');
    });

    it('layoutPreference is a valid value', () => {
      isString(defaultConfig.features.layoutPreference);
      includes(['grid', 'leftnav'], defaultConfig.features.layoutPreference,
        'layoutPreference should be either "grid" or "leftnav"');
    });

    it('layout Preference defaults to leftnav', () => {
      equal(defaultConfig.features.layoutPreference, 'leftnav',
        'Default layout should be leftnav');
    });
  });

  // ============================================================
  // Schema Compliance Tests
  // ============================================================

  describe('schema.json layoutPreference', () => {
    it('schema has features section', () => {
      hasProperty(schema.properties, 'features');
    });

    it('features has layoutPreference property', () => {
      hasProperty(schema.properties.features.properties, 'layoutPreference');
    });

    it('layoutPreference is string type', () => {
      equal(schema.properties.features.properties.layoutPreference.type, 'string',
        'layoutPreference should be type string');
    });

    it('layoutPreference has enum constraint', () => {
      const layoutProp = schema.properties.features.properties.layoutPreference;
      hasProperty(layoutProp, 'enum');
      includes(layoutProp.enum, 'grid');
      includes(layoutProp.enum, 'leftnav');
    });
  });

  // ============================================================
  // Config Consistency Tests
  // ============================================================

  describe('config consistency', () => {
    it('config value matches schema enum', () => {
      const allowedValues = schema.properties.features.properties.layoutPreference.enum;
      includes(allowedValues, defaultConfig.features.layoutPreference,
        'Config value should be in schema enum');
    });

    it('config is valid JSON', () => {
      exists(defaultConfigPath);
      const raw = fs.readFileSync(defaultConfigPath, 'utf-8');
      truthy(raw.trim().startsWith('{'), 'Config should be valid JSON object');
    });

    it('schema is valid JSON Schema', () => {
      exists(schemaPath);
      hasProperty(schema, '$schema');
      hasProperty(schema, 'properties');
    });
  });
}
