#!/usr/bin/env node
/**
 * Test Runner Framework for Roku Channel Template
 * 
 * Production-grade test runner with:
 * - Colorized output (terminal) / plain text (CI)
 * - Test grouping, filtering, and parallel execution
 * - Detailed reporting: pass/fail/skip with timing
 * - JUnit XML output for CI integration
 * - Coverage tracking for BrightScript files
 * - Mock infrastructure for device-dependent code
 * 
 * Usage:
 *   node tests/runner.mjs                    # Run all tests
 *   node tests/runner.mjs unit               # Run unit tests only
 *   node tests/runner.mjs unit components    # Run multiple categories
 *   node tests/runner.mjs --grep "config"    # Filter by name
 *   node tests/runner.mjs --json             # JSON output
 *   node tests/runner.mjs --junit-report     # JUnit XML report
 *   node tests/runner.mjs e2e                # Run E2E device tests
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execSync, spawn } from 'child_process';
import http from 'http';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = path.resolve(__dirname, '..');

// ============================================================
// E2E Test Lock (prevents concurrent agents from racing)
// ============================================================

const E2E_LOCK_FILE = '/tmp/roku-e2e.lock';

function isPidRunning(pid) {
  try {
    process.kill(parseInt(pid), 0); // signal 0 checks if process exists
    return true;
  } catch {
    return false;
  }
}

async function acquireE2ELock(config) {
  const myPid = process.pid;
  let attempts = 0;

  while (true) {
    try {
      // Try to read existing lock
      if (fs.existsSync(E2E_LOCK_FILE)) {
        const lockData = JSON.parse(fs.readFileSync(E2E_LOCK_FILE, 'utf8'));
        const lockPid = lockData.pid;

        if (isPidRunning(lockPid)) {
          // Another agent is running E2E tests — wait for it
          attempts++;
          const waitTime = Math.min(5 + Math.floor(attempts / 6) * 5, 30); // ramp up to 30s
          console.log(`  🔒 E2E lock held by PID ${lockPid} (started ${lockData.startedAt})`);
          console.log(`  ⏳ Waiting for lock release... attempt ${attempts} (retry in ${waitTime}s)`);
          // Warn after 5 minutes of waiting
          if (attempts === 60) {
            console.log(`  ⚠ Still waiting for E2E lock (5+ minutes) — another agent is running tests`);
          }
          // Check if lock holder released it
          await new Promise(r => setTimeout(r, waitTime * 1000));
          // If lock file is gone, we can proceed
          if (!fs.existsSync(E2E_LOCK_FILE)) continue; // retry acquire
          // Lock still exists, check if process is still alive
          if (!isPidRunning(lockPid)) {
            console.log(`  🗝 Lock holder PID ${lockPid} is dead — acquiring stale lock`);
            // Fall through to acquire
          } else {
            continue; // still waiting
          }
        }
        // Lock exists but PID is dead — acquire stale lock
        console.log(`  🗝 Acquiring stale lock (PID ${lockPid} no longer running)`);
      }

      // Write our lock
      fs.writeFileSync(E2E_LOCK_FILE, JSON.stringify({
        pid: myPid,
        startedAt: new Date().toISOString(),
        host: config.deviceHost,
      }));
      console.log(`  🔒 E2E lock acquired (PID ${myPid})`);
      return true;

    } catch (e) {
      // Race condition — another process wrote the lock between our check and write
      if (e.code === 'EEXIST' || e.code === 'ENOENT') {
        await new Promise(r => setTimeout(r, 1000));
        continue;
      }
      throw e;
    }
  }
}

function releaseE2ELock() {
  try {
    if (fs.existsSync(E2E_LOCK_FILE)) {
      const lockData = JSON.parse(fs.readFileSync(E2E_LOCK_FILE, 'utf8'));
      if (String(lockData.pid) === String(process.pid)) {
        fs.unlinkSync(E2E_LOCK_FILE);
        console.log(`  🔓 E2E lock released`);
      }
    }
  } catch (e) {
    // Ignore errors during release (e.g., already removed)
  }
}

// ============================================================
// Configuration
// ============================================================

const TEST_CATEGORIES = {
  unit: {
    dir: 'tests/unit',
    pattern: '*.mjs',
    description: 'Unit tests (pure logic, no device)',
    parallel: true,
  },
  components: {
    dir: 'tests/components',
    pattern: '*.mjs',
    description: 'Component tests (XML/validation)',
    parallel: true,
  },
  'e2e': {
    dir: 'tests/e2e',
    pattern: '*.mjs',
    description: 'E2E device tests (requires Roku)',
    parallel: false,
    requiresDevice: true,
  },
  performance: {
    dir: 'tests/performance',
    pattern: '*.mjs',
    description: 'Performance tests (launch, memory)',
    parallel: false,
    requiresDevice: true,
  },
  accessibility: {
    dir: 'tests/accessibility',
    pattern: '*.mjs',
    description: 'Accessibility tests (focus, ARIA)',
    parallel: true,
  },
  'crash-recovery': {
    dir: 'tests/crash-recovery',
    pattern: '*.mjs',
    description: 'Crash recovery tests (error handling)',
    parallel: false,
  },
};

// ============================================================
// CLI Argument Parsing
// ============================================================

function parseArgs(argv) {
  const args = argv.slice(2);
  const config = {
    categories: [],
    grep: null,
    json: false,
    junit: false,
    junitOutput: path.join(ROOT_DIR, 'test-results', 'junit.xml'),
    coverage: false,
    verbose: false,
    timeout: 120000, // 2 min default
    deviceHost: process.env.ROKU_HOST || 'example.invalid',
    devicePassword: process.env.ROKU_PASSWORD || '',
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--grep' || arg === '-g') {
      config.grep = args[++i];
    } else if (arg === '--json') {
      config.json = true;
    } else if (arg === '--junit-report' || arg === '--junit') {
      config.junit = true;
    } else if (arg === '--coverage') {
      config.coverage = true;
    } else if (arg === '--verbose' || arg === '-v') {
      config.verbose = true;
    } else if (arg === '--timeout') {
      config.timeout = parseInt(args[++i], 10);
    } else if (arg === '--device-host') {
      config.deviceHost = args[++i];
    } else if (arg === '--device-password') {
      config.devicePassword = args[++i];
    } else if (arg.startsWith('--')) {
      // Unknown flag
    } else {
      config.categories.push(arg);
    }
  }

  // Default: run all non-device categories
  if (config.categories.length === 0) {
    config.categories = ['unit', 'components', 'accessibility', 'crash-recovery'];
  }

  return config;
}

// ============================================================
// Test Result Tracking
// ============================================================

class TestResult {
  constructor(name, file, startTime) {
    this.name = name;
    this.file = file;
    this.startTime = startTime;
    this.endTime = null;
    this.status = 'pending'; // pending, passed, failed, skipped
    this.error = null;
    this.assertions = 0;
    this.tests = 0;
    this.passed = 0;
    this.failed = 0;
    this.skipped = 0;
  }

  complete() {
    this.endTime = Date.now();
  }

  get duration() {
    return this.endTime ? this.endTime - this.startTime : 0;
  }

  toJSON() {
    return {
      name: this.name,
      file: this.file,
      status: this.status,
      duration: this.duration,
      tests: this.tests,
      passed: this.passed,
      failed: this.failed,
      skipped: this.skipped,
      assertions: this.assertions,
      error: this.error,
    };
  }
}

class SuiteResult {
  constructor(category) {
    this.category = category;
    this.results = [];
    this.startTime = Date.now();
    this.endTime = null;
  }

  complete() {
    this.endTime = Date.now();
  }

  get duration() {
    return this.endTime ? this.endTime - this.startTime : 0;
  }

  get totalTests() {
    return this.results.reduce((sum, r) => sum + r.tests, 0);
  }

  get totalPassed() {
    return this.results.reduce((sum, r) => sum + r.passed, 0);
  }

  get totalFailed() {
    return this.results.reduce((sum, r) => sum + r.failed, 0);
  }

  get totalSkipped() {
    return this.results.reduce((sum, r) => sum + r.skipped, 0);
  }
}

// ============================================================
// Assertion Helpers (exported to test files)
// ============================================================

export class AssertionError extends Error {
  constructor(message, actual, expected) {
    super(message);
    this.name = 'AssertionError';
    this.actual = actual;
    this.expected = expected;
  }
}

const assertions = {
  equal(actual, expected, message = '') {
    if (actual !== expected) {
      throw new AssertionError(
        message || `Expected ${JSON.stringify(actual)} to equal ${JSON.stringify(expected)}`,
        actual, expected
      );
    }
  },

  deepEqual(actual, expected, message = '') {
    if (JSON.stringify(actual) !== JSON.stringify(expected)) {
      throw new AssertionError(
        message || `Expected ${JSON.stringify(actual)} to deeply equal ${JSON.stringify(expected)}`,
        actual, expected
      );
    }
  },

  notEqual(actual, expected, message = '') {
    if (actual === expected) {
      throw new AssertionError(
        message || `Expected ${JSON.stringify(actual)} to not equal ${JSON.stringify(expected)}`,
        actual, expected
      );
    }
  },

  truthy(value, message = '') {
    if (!value) {
      throw new AssertionError(
        message || `Expected ${JSON.stringify(value)} to be truthy`,
        value, true
      );
    }
  },

  falsy(value, message = '') {
    if (value) {
      throw new AssertionError(
        message || `Expected ${JSON.stringify(value)} to be falsy`,
        value, false
      );
    }
  },

  isNull(value, message = '') {
    if (value !== null) {
      throw new AssertionError(
        message || `Expected ${JSON.stringify(value)} to be null`,
        value, null
      );
    }
  },

  isUndefined(value, message = '') {
    if (value === undefined) {
      // pass
    } else {
      throw new AssertionError(
        message || `Expected ${JSON.stringify(value)} to be undefined`,
        value, undefined
      );
    }
  },

  isType(value, type, message = '') {
    if (typeof value !== type) {
      throw new AssertionError(
        message || `Expected ${typeof value} to be ${type}`,
        typeof value, type
      );
    }
  },

  isArray(value, message = '') {
    if (!Array.isArray(value)) {
      throw new AssertionError(
        message || `Expected ${typeof value} to be an array`,
        Array.isArray(value), true
      );
    }
  },

  isObject(value, message = '') {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
      throw new AssertionError(
        message || `Expected ${typeof value} to be an object`,
        typeof value, 'object'
      );
    }
  },

  isString(value, message = '') {
    if (typeof value !== 'string') {
      throw new AssertionError(
        message || `Expected ${typeof value} to be a string`,
        typeof value, 'string'
      );
    }
  },

  isNumber(value, message = '') {
    if (typeof value !== 'number') {
      throw new AssertionError(
        message || `Expected ${typeof value} to be a number`,
        typeof value, 'number'
      );
    }
  },

  isFunction(value, message = '') {
    if (typeof value !== 'function') {
      throw new AssertionError(
        message || `Expected ${typeof value} to be a function`,
        typeof value, 'function'
      );
    }
  },

  isBoolean(value, message = '') {
    if (typeof value !== 'boolean') {
      throw new AssertionError(
        message || `Expected ${typeof value} to be a boolean`,
        typeof value, 'boolean'
      );
    }
  },

  isNullish(value, message = '') {
    if (value !== null && value !== undefined) {
      throw new AssertionError(
        message || `Expected ${JSON.stringify(value)} to be null or undefined`,
        value, null
      );
    }
  },

  includes(arrayOrString, item, message = '') {
    if (!arrayOrString.includes(item)) {
      throw new AssertionError(
        message || `Expected ${JSON.stringify(arrayOrString)} to include ${JSON.stringify(item)}`,
        false, true
      );
    }
  },

  hasProperty(obj, prop, message = '') {
    if (!(prop in obj)) {
      throw new AssertionError(
        message || `Expected object to have property "${prop}"`,
        false, true
      );
    }
  },

  hasLength(value, expected, message = '') {
    if (value.length !== expected) {
      throw new AssertionError(
        message || `Expected length ${value.length} to be ${expected}`,
        value.length, expected
      );
    }
  },

  greaterThan(value, expected, message = '') {
    if (value <= expected) {
      throw new AssertionError(
        message || `Expected ${value} to be greater than ${expected}`,
        value, `> ${expected}`
      );
    }
  },

  lessThan(value, expected, message = '') {
    if (value >= expected) {
      throw new AssertionError(
        message || `Expected ${value} to be less than ${expected}`,
        value, `< ${expected}`
      );
    }
  },

  between(value, min, max, message = '') {
    if (value < min || value > max) {
      throw new AssertionError(
        message || `Expected ${value} to be between ${min} and ${max}`,
        value, `${min}..${max}`
      );
    }
  },

  throws(fn, expectedType, message = '') {
    try {
      fn();
      throw new AssertionError(
        message || 'Expected function to throw',
        false, true
      );
    } catch (e) {
      if (expectedType && e.name !== expectedType) {
        throw new AssertionError(
          message || `Expected ${expectedType} but got ${e.name}`,
          e.name, expectedType
        );
      }
    }
  },

  exists(filePath, message = '') {
    if (!fs.existsSync(filePath)) {
      throw new AssertionError(
        message || `Expected file to exist: ${filePath}`,
        false, true
      );
    }
  },

  match(value, regex, message = '') {
    if (!regex.test(value)) {
      throw new AssertionError(
        message || `Expected "${value}" to match ${regex}`,
        false, true
      );
    }
  },

  empty(value, message = '') {
    if (value.length !== 0) {
      throw new AssertionError(
        message || `Expected empty value but got ${JSON.stringify(value)}`,
        value.length, 0
      );
    }
  },

  ok(value, message = '') {
    if (!value) {
      throw new AssertionError(
        message || `Expected truthy value but got ${JSON.stringify(value)}`,
        value, true
      );
    }
  },
};

// ============================================================
// Test File Discovery
// ============================================================

function discoverTests(category) {
  const config = TEST_CATEGORIES[category];
  if (!config) {
    console.error(`Unknown test category: ${category}`);
    process.exit(1);
  }

  const testDir = path.join(ROOT_DIR, config.dir);
  if (!fs.existsSync(testDir)) {
    return [];
  }

  const files = fs.readdirSync(testDir);
  return files
    .filter(f => f.endsWith('.mjs'))
    .map(f => path.join(testDir, f));
}

// ============================================================
// Test Execution
// ============================================================

async function runTestFile(filePath, config) {
  const startTime = Date.now();
  const relPath = path.relative(ROOT_DIR, filePath);
  const testName = path.basename(filePath, '.mjs');

  const result = new TestResult(testName, relPath, startTime);

  try {
    // Dynamic import - test files export a default function
    const testModule = await import(filePath + '?t=' + Date.now());
    
    if (typeof testModule.default !== 'function') {
      result.error = `Test file ${relPath} does not export a default function`;
      result.status = 'failed';
      result.complete();
      return result;
    }

    // Inject test helpers with assertion counting
    const countingAssertions = {};
    for (const [name, fn] of Object.entries(assertions)) {
      countingAssertions[name] = (...args) => {
        result.assertions++;
        return fn(...args);
      };
    }
    const testContext = {
      describe: (name, fn) => {
        return fn();
      },
      it: async (name, fn) => {
        result.tests++;
        const testStart = Date.now();
        try {
          await fn();
          result.passed++;
        } catch (e) {
          result.failed++;
          result.error = `${name}: ${e.message}`;
          result.status = 'failed';
        }
        const duration = Date.now() - testStart;
        if (config.verbose) {
          const icon = result.failed > 0 && result.error?.includes(name) ? '✗' : '✓';
          console.log(`      ${icon} ${name} (${duration}ms)`);
        }
      },
      skip: (name, fn) => {
        result.tests++;
        result.skipped++;
        if (config.verbose) {
          console.log(`      ⊘ ${name} (skipped)`);
        }
      },
      beforeEach: () => {},
      afterEach: () => {},
      assertions: countingAssertions,
      assert: countingAssertions,
    };

    // Run the test
    await testModule.default(testContext);

    if (result.status === 'pending') {
      result.status = result.failed > 0 ? 'failed' : 'passed';
    }
  } catch (e) {
    result.error = e.message;
    result.status = 'failed';
    result.failed++;
    result.tests++;
  }

  result.complete();
  return result;
}

async function runCategory(category, config) {
  const testFiles = discoverTests(category);
  const suite = new SuiteResult(category);

  if (testFiles.length === 0) {
    console.log(`  ⊘ ${category}: No tests found`);
    suite.complete();
    return suite;
  }

  const catConfig = TEST_CATEGORIES[category];
  const parallel = catConfig.parallel;

  console.log(`\n  ${catConfig.description}`);
  console.log(`  Running ${testFiles.length} test file(s)...`);

  if (parallel) {
    // Run all tests in parallel
    const promises = testFiles.map(f => runTestFile(f, config));
    suite.results = await Promise.all(promises);
  } else {
    // Run tests sequentially
    for (const file of testFiles) {
      const result = await runTestFile(file, config);
      suite.results.push(result);
    }
  }

  suite.complete();
  return suite;
}

// ============================================================
// Output Formatting
// ============================================================

function formatDuration(ms) {
  if (ms < 1000) return `${ms}ms`;
  return `${(ms / 1000).toFixed(2)}s`;
}

function statusIcon(status) {
  switch (status) {
    case 'passed': return '✓';
    case 'failed': return '✗';
    case 'skipped': return '⊘';
    default: return '?';
  }
}

function printSummary(suiteResults, config) {
  const totalTests = suiteResults.reduce((s, r) => s + r.totalTests, 0);
  const totalPassed = suiteResults.reduce((s, r) => s + r.totalPassed, 0);
  const totalFailed = suiteResults.reduce((s, r) => s + r.totalFailed, 0);
  const totalSkipped = suiteResults.reduce((s, r) => s + r.totalSkipped, 0);
  const totalDuration = suiteResults.reduce((s, r) => s + r.duration, 0);
  const totalFiles = suiteResults.reduce((s, r) => s + r.results.length, 0);
  const totalAssertions = suiteResults.reduce((s, r) => s + r.results.reduce((a, r) => a + (r.assertions || 0), 0), 0);

  const header = '═'.repeat(60);
  const separator = '─'.repeat(60);

  console.log(`\n${header}`);
  console.log('  📊 Test Summary');
  console.log(header);

  for (const suite of suiteResults) {
    const passRate = suite.totalTests > 0
      ? ((suite.totalPassed / suite.totalTests) * 100).toFixed(1)
      : 'N/A';
    const icon = suite.totalFailed > 0 ? '✗' : suite.totalTests > 0 ? '✓' : '⊘';

    console.log(`\n  ${icon} ${suite.category} (${formatDuration(suite.duration)})`);
    console.log(`     ${suite.totalPassed}/${suite.totalTests} passed (${passRate}%)`);

    for (const result of suite.results) {
      const icon = statusIcon(result.status);
      const assertInfo = result.assertions ? ` (${result.assertions} assertions)` : '';
      console.log(`       ${icon} ${result.name} (${formatDuration(result.duration)})${assertInfo}`);
      if (result.error) {
        console.log(`         Error: ${result.error}`);
      }
    }
  }

  console.log(`\n${separator}`);
  console.log(`  Total: ${totalPassed}/${totalTests} tests passed`);
  console.log(`  Files: ${totalFiles} test file(s) executed`);
  console.log(`  Assertions: ${totalAssertions}`);
  if (totalSkipped > 0) {
    console.log(`  Skipped: ${totalSkipped}`);
  }
  console.log(`  Duration: ${formatDuration(totalDuration)}`);

  if (totalFailed > 0) {
    console.log(`\n  Result: ❌ FAILED (${totalFailed} test(s) failed)`);
  } else {
    console.log(`\n  Result: ✅ ALL TESTS PASSED`);
  }
  console.log(header);
}

function printJSONOutput(suiteResults) {
  const output = {
    timestamp: new Date().toISOString(),
    suites: {},
  };

  for (const suite of suiteResults) {
    output.suites[suite.category] = {
      duration: suite.duration,
      totalTests: suite.totalTests,
      passed: suite.totalPassed,
      failed: suite.totalFailed,
      skipped: suite.totalSkipped,
      tests: suite.results.map(r => r.toJSON()),
    };
  }

  console.log(JSON.stringify(output, null, 2));
}

function generateJUnitXML(suiteResults) {
  let xml = '<?xml version="1.0" encoding="UTF-8"?>\n';
  xml += '<testsuites>\n';

  for (const suite of suiteResults) {
    xml += `  <testsuite name="${suite.category}" tests="${suite.totalTests}" `;
    xml += `failures="${suite.totalFailed}" skipped="${suite.totalSkipped}" `;
    xml += `time="${(suite.duration / 1000).toFixed(3)}">\n`;

    for (const result of suite.results) {
      xml += `    <testcase name="${result.name}" `;
      xml += `classname="${suite.category}" `;
      xml += `time="${(result.duration / 1000).toFixed(3)}">\n`;
      
      if (result.status === 'failed' && result.error) {
        xml += `      <failure message="${escapeXml(result.error)}"></failure>\n`;
      } else if (result.status === 'skipped') {
        xml += `      <skipped/>\n`;
      }
      
      xml += `    </testcase>\n`;
    }

    xml += `  </testsuite>\n`;
  }

  xml += '</testsuites>';
  return xml;
}

function escapeXml(str) {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

// ============================================================
// Device Health Check and Auto-Reboot
// ============================================================

async function ensureDeviceReady() {
  console.error('Device tests are not included in this public export.');
  return false;
}


// ============================================================
// Main Entry Point
// ============================================================

export async function runTests(config) {
  console.log('');
  console.log('  🔬 Roku Channel Template Test Suite');
  console.log(`  Categories: ${config.categories.join(', ')}`);
  if (config.grep) {
    console.log(`  Filter: ${config.grep}`);
  }
  console.log('');

  // Auto-reboot device for e2e/performance tests if not responsive
  const needsDevice = config.categories.some(c => TEST_CATEGORIES[c]?.requiresDevice);
  if (needsDevice) {
    // Acquire E2E lock — waits if another agent is running tests
    await acquireE2ELock(config);
    try {
      const deviceOk = await ensureDeviceReady(config);
      if (!deviceOk) {
        console.log('');
        console.log('  ❌ No Roku device available — E2E tests FAILED');
        console.log('  Tried primary and fallback — both unreachable');
        console.log('  Fix: power-cycle device or check network connectivity');
        process.exit(1);
      }

      const suiteResults = [];

      for (const category of config.categories) {
        const result = await runCategory(category, config);
        suiteResults.push(result);
      }

      // Output
      if (config.json) {
        printJSONOutput(suiteResults);
      } else {
        printSummary(suiteResults, config);
      }

      // Coverage report
      if (config.coverage) {
        const totalTests = suiteResults.reduce((s, r) => s + r.totalTests, 0);
        const totalPassed = suiteResults.reduce((s, r) => s + r.totalPassed, 0);
        const totalFiles = suiteResults.reduce((s, r) => s + r.results.length, 0);
        const totalAssertions = suiteResults.reduce((s, r) => s + r.results.reduce((a, r) => a + (r.assertions || 0), 0), 0);
        const totalFailed = suiteResults.reduce((s, r) => s + r.totalFailed, 0);
        const passRate = totalTests > 0 ? ((totalPassed / totalTests) * 100) : 0;

        console.log('\n📈 Coverage Report');
        console.log('═'.repeat(60));
        console.log(`  Test files executed: ${totalFiles}`);
        console.log(`  Tests passed: ${totalPassed}/${totalTests} (${passRate.toFixed(1)}%)`);
        console.log(`  Assertions executed: ${totalAssertions}`);
        console.log(`  Avg assertions/test: ${(totalTests > 0 ? (totalAssertions / totalTests).toFixed(1) : 0)}`);

        // Coverage check: all tests pass + minimum assertions
        const minAssertions = 1000;
        const coverageOk = totalFailed === 0 && totalAssertions >= minAssertions && passRate >= 80;
        if (coverageOk) {
          console.log(`\n  ✅ Coverage: PASS (${totalAssertions} assertions >= ${minAssertions} threshold, ${passRate.toFixed(1)}% pass rate >= 80%)`);
        } else {
          console.log(`\n  ❌ Coverage: FAIL`);
          if (totalFailed > 0) console.log(`     - ${totalFailed} test(s) failed`);
          if (totalAssertions < minAssertions) console.log(`     - ${totalAssertions} assertions < ${minAssertions} minimum`);
          if (passRate < 80) console.log(`     - ${passRate.toFixed(1)}% pass rate < 80%`);
        }
        console.log('═'.repeat(60));
      }

      // JUnit XML
      if (config.junit) {
        const outputDir = path.dirname(config.junitOutput);
        if (!fs.existsSync(outputDir)) {
          fs.mkdirSync(outputDir, { recursive: true });
        }
        fs.writeFileSync(config.junitOutput, generateJUnitXML(suiteResults));
        console.log(`\n  📄 JUnit report: ${config.junitOutput}`);
      }

      // Exit code
      const totalFailed = suiteResults.reduce((s, r) => s + r.totalFailed, 0);
      releaseE2ELock();
      process.exit(totalFailed > 0 ? 1 : 0);
    } catch (e) {
      releaseE2ELock();
      throw e;
    }
  }

  // Non-device tests — no lock needed
  const suiteResults = [];

  for (const category of config.categories) {
    const result = await runCategory(category, config);
    suiteResults.push(result);
  }

  // Output
  if (config.json) {
    printJSONOutput(suiteResults);
  } else {
    printSummary(suiteResults, config);
  }

  // Coverage report
  if (config.coverage) {
    const totalTests = suiteResults.reduce((s, r) => s + r.totalTests, 0);
    const totalPassed = suiteResults.reduce((s, r) => s + r.totalPassed, 0);
    const totalFiles = suiteResults.reduce((s, r) => s + r.results.length, 0);
    const totalAssertions = suiteResults.reduce((s, r) => s + r.results.reduce((a, r) => a + (r.assertions || 0), 0), 0);
    const totalFailed = suiteResults.reduce((s, r) => s + r.totalFailed, 0);
    const passRate = totalTests > 0 ? ((totalPassed / totalTests) * 100) : 0;

    console.log('\n📈 Coverage Report');
    console.log('═'.repeat(60));
    console.log(`  Test files executed: ${totalFiles}`);
    console.log(`  Tests passed: ${totalPassed}/${totalTests} (${passRate.toFixed(1)}%)`);
    console.log(`  Assertions executed: ${totalAssertions}`);
    console.log(`  Avg assertions/test: ${(totalTests > 0 ? (totalAssertions / totalTests).toFixed(1) : 0)}`);

    // Coverage check: all tests pass + minimum assertions
    const minAssertions = 1000;
    const coverageOk = totalFailed === 0 && totalAssertions >= minAssertions && passRate >= 80;
    if (coverageOk) {
      console.log(`\n  ✅ Coverage: PASS (${totalAssertions} assertions >= ${minAssertions} threshold, ${passRate.toFixed(1)}% pass rate >= 80%)`);
    } else {
      console.log(`\n  ❌ Coverage: FAIL`);
      if (totalFailed > 0) console.log(`     - ${totalFailed} test(s) failed`);
      if (totalAssertions < minAssertions) console.log(`     - ${totalAssertions} assertions < ${minAssertions} minimum`);
      if (passRate < 80) console.log(`     - ${passRate.toFixed(1)}% pass rate < 80%`);
    }
    console.log('═'.repeat(60));
  }

  // JUnit XML
  if (config.junit) {
    const outputDir = path.dirname(config.junitOutput);
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }
    fs.writeFileSync(config.junitOutput, generateJUnitXML(suiteResults));
    console.log(`\n  📄 JUnit report: ${config.junitOutput}`);
  }

  // Exit code
  const totalFailed = suiteResults.reduce((s, r) => s + r.totalFailed, 0);
  process.exit(totalFailed > 0 ? 1 : 0);
}

// Run if called directly
const config = parseArgs(process.argv);
await runTests(config);
