import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { spawnSync } from 'node:child_process';

test('public Roku package excludes unrelated server and deployment dependencies', () => {
  const manifest = JSON.parse(readFileSync('package.json', 'utf8'));
  assert.deepEqual(Object.keys(manifest.dependencies).sort(), ['adm-zip']);
  assert.deepEqual(Object.keys(manifest.devDependencies).sort(), ['brighterscript', 'brslint']);
});

test('XML tooling does not resolve the known vulnerable legacy parser', () => {
  const lockfile = JSON.parse(readFileSync('package-lock.json', 'utf8'));
  const parsers = Object.entries(lockfile.packages).filter(([name]) => name.endsWith('node_modules/xml2js'));
  assert.ok(parsers.length > 0);
  for (const [, parser] of parsers) {
    const [major, minor] = parser.version.split('.').map(Number);
    assert.ok(major > 0 || minor >= 5, `Unsupported XML parser version: ${parser.version}`);
  }
});

test('public defaults do not contact a real service', () => {
  const config = JSON.parse(readFileSync('config/default.json', 'utf8'));
  assert.equal(config.analytics.enabled, false);
  for (const value of [config.content.sourceUrl, config.analytics.exportUrl, config.server.baseUrl, config.giving.donationUrl, config.heartbeat.exportUrl]) {
    assert.match(value, /^https:\/\/example\.invalid(?:\/|$)/);
  }
  assert.match(readFileSync('manifest', 'utf8'), /content_feed_url=https:\/\/example\.invalid\//);
  assert.equal(existsSync('config/devices.json'), false);
});

test('test runner cannot reboot a device', () => {
  const runner = readFileSync('tests/runner.mjs', 'utf8');
  assert.doesNotMatch(runner, /function rebootDevice|\/reboot\?sid=/);
});

test('package validator rejects a missing archive', () => {
  const result = spawnSync(process.execPath, ['scripts/validate-package.mjs', '--zip=missing-export-test.zip'], { encoding: 'utf8' });
  assert.equal(result.status, 1);
  assert.match(result.stdout, /Package not found/);
});
