/**
 * Unit Tests: Service Schedule
 * 
 * Tests service schedule functionality.
 * NOTE: ServiceScheduleScreen was removed from the channel in favor of
 * server-driven schedule data via the feed. This test validates that
 * the schedule-related code paths have been properly cleaned up.
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

  describe('Service Scheduler', () => {
    it('ServiceScheduler.brs file exists', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'ServiceScheduler.brs');
      truthy(fileExists(testPath), 'ServiceScheduler.brs should exist');
    });

    it('ServiceScheduler has required functions', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'ServiceScheduler.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('FetchServiceSchedule'), 'Should have FetchServiceSchedule function');
      truthy(content.includes('GetNextService'), 'Should have GetNextService function');
      truthy(content.includes('IsServiceLive'), 'Should have IsServiceLive function');
      truthy(content.includes('FormatServiceTime'), 'Should have FormatServiceTime function');
    });
  });

  describe('Service Schedule Screen (removed)', () => {
    it('ServiceScheduleScreen files are removed', () => {
      const xmlPath = path.join(ROOT_DIR, '..', 'components', 'ServiceScheduleScreen.xml');
      const brsPath = path.join(ROOT_DIR, '..', 'components', 'ServiceScheduleScreen.brs');
      
      falsy(fileExists(xmlPath), 'ServiceScheduleScreen.xml should be removed');
      falsy(fileExists(brsPath), 'ServiceScheduleScreen.brs should be removed');
    });

    it('LeftNavScreen no longer references schedule panel functions', () => {
      const leftNavBrs = path.join(ROOT_DIR, '..', 'components', 'LeftNavScreen.brs');
      const content = readFile(leftNavBrs);
      
      falsy(content.includes('ShowSchedulePanel'), 'Should not reference ShowSchedulePanel');
      falsy(content.includes('CreateSchedulePanel'), 'Should not reference CreateSchedulePanel');
    });
  });
}
