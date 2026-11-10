/**
 * Unit Tests: Live Service Indicator
 * 
 * Tests live service indicator functionality
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = path.resolve(__dirname, '..');

export default async function runTests({ describe, it, assertions }) {
  const { equal, truthy, falsy, isString, isNumber, isArray, isObject } = assertions;

  function fileExists(testPath) {
    try {
      return fs.existsSync(testPath);
    } catch (e) {
      return false;
    }
  }

  function readFile(testPath) {
    try {
      return fs.readFileSync(testPath, 'utf-8');
    } catch (e) {
      return '';
    }
  }

  describe('Live Service Indicator', () => {
    it('LiveServiceIndicator.brs file exists', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'LiveServiceIndicator.brs');
      truthy(fileExists(testPath), 'LiveServiceIndicator.brs should exist');
    });

    it('LiveServiceIndicator has required functions', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'LiveServiceIndicator.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('IsLiveServiceActive'), 'Should have IsLiveServiceActive function');
      truthy(content.includes('GetLiveStreamUrl'), 'Should have GetLiveStreamUrl function');
      truthy(content.includes('IsLiveService'), 'Should have IsLiveService function');
    });
  });
}
