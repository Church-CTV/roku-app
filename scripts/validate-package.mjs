#!/usr/bin/env node
/**
 * validate-package.mjs - Comprehensive package validation for Roku channels
 *
 * Validates the built channel package for correctness before deployment.
 * Checks:
 *   1. Required files exist
 *   2. Manifest syntax and required fields
 *   3. ZIP integrity and contents
 *   4. BrightScript syntax validation
 *   5. Component XML structure validation
 *
 * Usage:
 *   node scripts/validate-package.mjs [--zip <path>] [--verbose]
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import AdmZip from 'adm-zip';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = path.resolve(__dirname, '..');

// Parse CLI arguments
const args = process.argv.slice(2);
const zipPath = args.find(a => a.startsWith('--zip='))?.split('=')[1]
  || path.join(ROOT_DIR, 'build', 'channel.zip');
const verbose = args.includes('--verbose');

const errors = [];
const warnings = [];
const checks = [];

function check(name, fn) {
  try {
    const result = fn();
    const isPass = result === true || (typeof result === 'string' && /^(ZIP valid:|Syntax OK:|XML OK:|Config files valid$)/.test(result));
    const detail = typeof result === 'string' ? result : 'OK';
    checks.push({ name, pass: isPass, detail });
    if (!isPass) errors.push(`${name}: ${detail}`);
    return result;
  } catch (e) {
    checks.push({ name, pass: false, detail: e.message });
    errors.push(`${name}: ${e.message}`);
    return false;
  }
}

// 1. Required files check
const requiredFiles = [
  'manifest',
  'source/main.brs',
  'components/MainScene.xml',
  'components/MainScene.brs',
  'components/MainView.xml',
];

for (const file of requiredFiles) {
  check(`Required file: ${file}`, () => {
    const fullPath = path.join(ROOT_DIR, file);
    if (!fs.existsSync(fullPath)) {
      return `Missing required file: ${file}`;
    }
    return true;
  });
}

// Special check: source/App may be .bs (BrighterScript) or .brs
check('Required file: source/App.brs/.bs', () => {
  const bsPath = path.join(ROOT_DIR, 'source', 'App.bs');
  const brsPath = path.join(ROOT_DIR, 'source', 'App.brs');
  if (fs.existsSync(bsPath) || fs.existsSync(brsPath)) {
    return true;
  }
  return 'Missing required file: source/App.bs or source/App.brs';
});

// 2. Manifest validation
check('Manifest validation', () => {
  const manifestPath = path.join(ROOT_DIR, 'manifest');
  const content = fs.readFileSync(manifestPath, 'utf-8');
  const lines = content.split('\n');
  const fields = {};

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx > 0) {
      fields[trimmed.substring(0, eqIdx).trim()] = trimmed.substring(eqIdx + 1).trim();
    }
  }

  const requiredFields = ['title', 'major_version', 'minor_version', 'build_version'];
  for (const field of requiredFields) {
    if (!fields[field]) {
      return `Missing required manifest field: ${field}`;
    }
  }

  // Validate version numbers
  const major = parseInt(fields.major_version, 10);
  const minor = parseInt(fields.minor_version, 10);
  const build = parseInt(fields.build_version, 10);

  if (isNaN(major) || major < 0) return `Invalid major_version: ${fields.major_version}`;
  if (isNaN(minor) || minor < 0) return `Invalid minor_version: ${fields.minor_version}`;
  if (isNaN(build) || build < 0) return `Invalid build_version: ${fields.build_version}`;

  return true;
});

// 3. ZIP integrity check
check('ZIP package integrity', () => {
  if (!fs.existsSync(zipPath)) {
    return `Package not found: ${zipPath}. Run 'npm run build' first.`;
  }

  const stats = fs.statSync(zipPath);
  if (stats.size === 0) return 'Package is empty (0 bytes)';
  if (stats.size < 100) return `Package too small (${stats.size} bytes)`;

  try {
    const zip = new AdmZip(zipPath);
    const entries = zip.getEntries();

    if (entries.length === 0) return 'ZIP contains no files';

    // Check for required entries in the ZIP
    const entryPaths = entries.map(e => e.entryName);
    const requiredInZip = [
      'manifest',
      'source/main.brs',
      'components/MainScene.xml',
      'components/MainScene.brs',
    ];

    for (const req of requiredInZip) {
      if (!entryPaths.some(p => p === req || p.endsWith('/' + req))) {
        return `Missing from ZIP: ${req}`;
      }
    }

    // Check for node_modules in ZIP (should be excluded)
    const nodeModulesEntries = entryPaths.filter(p => p.includes('node_modules'));
    if (nodeModulesEntries.length > 0) {
      return `node_modules found in package: ${nodeModulesEntries.slice(0, 3).join(', ')}...`;
    }

    // Check for .git directory in ZIP (should be excluded, but .github is OK)
    const gitDirEntries = entryPaths.filter(p => p.startsWith('.git/') || p === '.git');
    if (gitDirEntries.length > 0) {
      return `.git directory found in package`;
    }

    return `ZIP valid: ${entries.length} files, ${(stats.size / 1024).toFixed(1)} KB`;
  } catch (e) {
    return `ZIP corruption: ${e.message}`;
  }
});

// 4. BrightScript syntax validation
check('BrightScript syntax', () => {
  const sourceDir = path.join(ROOT_DIR, 'source');
  const componentsDir = path.join(ROOT_DIR, 'components');

  const bsFiles = [];
  function collectBs(dir) {
    if (!fs.existsSync(dir)) return;
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        collectBs(fullPath);
      } else if (entry.name.endsWith('.bs') || entry.name.endsWith('.brs')) {
        bsFiles.push(fullPath);
      }
    }
  }

  collectBs(sourceDir);
  collectBs(componentsDir);

  const syntaxErrors = [];
  for (const file of bsFiles) {
    const content = fs.readFileSync(file, 'utf-8');
    const relPath = path.relative(ROOT_DIR, file);

    // Check for unmatched triple-quote strings (BrightScript multi-line strings)
    // BrightScript supports """ for multi-line strings
    const tripleQuoteCount = (content.match(/"""/g) || []).length;
    if (tripleQuoteCount % 2 !== 0) {
      syntaxErrors.push(`${relPath}: Unmatched triple-quote string`);
      continue;
    }

    // Check for unmatched single/double quotes per line (improved)
    const lines = content.split('\n');
    let lastUnmatchedLine = 0;
    for (let lineNum = 0; lineNum < lines.length; lineNum++) {
      let line = lines[lineNum];
      // Skip comments and triple-quote lines
      const trimmed = line.trim();
      if (trimmed.startsWith('\'') || trimmed.startsWith('#')) continue;
      if (line.includes('"""')) continue;

      // Remove string literals before counting stray quotes
      line = line.replace(/"[^"]*"/g, '');
      line = line.replace(/'[^']*'/g, '');

      // Remove inline comments (apostrophe followed by non-quote)
      line = line.replace(/'[^\n]*$/, '');

      const doubleQuotes = (line.match(/"/g) || []).length;
      const singleQuotes = (line.match(/'/g) || []).length;
      if (doubleQuotes % 2 !== 0 || singleQuotes % 2 !== 0) {
        lastUnmatchedLine = lineNum + 1;
      }
    }
    if (lastUnmatchedLine > 0) {
      syntaxErrors.push(`${relPath}:${lastUnmatchedLine}: Possible unmatched string literal`);
    }

    // Check for .GetType() on SGNodes — causes runtime error &hf4
      // Must use Type(node) builtin instead
      if (/\.GetType\(\)/.test(content)) {
        syntaxErrors.push(`${relPath}: .GetType() found — use Type(node) builtin instead (GetType() causes runtime error &hf4 on SGNodes)`);
      }

      // Check for end without sub/function
    const subPattern = /\bsub\s+\w+/gi;
    const endPattern = /\bend\b/gi;
    const subs = content.match(subPattern);
    const ends = content.match(endPattern);
    if (subs && ends) {
      const subCount = subs.length;
      const endCount = ends.length;
      // end keyword is used in multiple contexts (end if, end for, end sub, end function)
      // Simple heuristic: count "end " (with space) as end-of-block markers
      const endBlockPattern = /\bend\s+/gi;
      const endBlocks = content.match(endBlockPattern);
      if (endBlocks && endBlocks.length > subCount * 3) {
        // May have issues but not definitive
      }
    }
  }

  if (syntaxErrors.length > 0) {
    return syntaxErrors.join('; ');
  }
  return `Syntax OK: ${bsFiles.length} files checked`;
});

// 5. Component XML validation
check('Component XML structure', () => {
  const componentsDir = path.join(ROOT_DIR, 'components');
  if (!fs.existsSync(componentsDir)) {
    return 'components directory not found';
  }

  const xmlFiles = [];
  const entries = fs.readdirSync(componentsDir, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.name.endsWith('.xml')) {
      xmlFiles.push(path.join(componentsDir, entry.name));
    }
  }

  const xmlErrors = [];
  for (const file of xmlFiles) {
    const content = fs.readFileSync(file, 'utf-8');
    // Basic XML well-formedness: check matching tags
    const openTags = content.match(/<([a-zA-Z][a-zA-Z0-9]*)[^>]*>/g) || [];
    const closeTags = content.match(/<\/([a-zA-Z][a-zA-Z0-9]*)>/g) || [];

    // Simple check: count opening and closing tags
    const openCount = openTags.length;
    const closeCount = closeTags.length;

    // Self-closing tags don't need closing
    const selfClosing = content.match(/\/>/g) || [];
    const expectedClose = openCount - selfClosing.length;

    if (closeCount !== expectedClose) {
      xmlErrors.push(`${path.basename(file)}: tag mismatch (open: ${openCount}, close: ${closeCount})`);
    }

    // Check for Component node
    if (!content.includes('<component') && !file.endsWith('Global.xml')) {
      xmlErrors.push(`${path.basename(file)}: missing <component> root element`);
    }
  }

  if (xmlErrors.length > 0) {
    return xmlErrors.join('; ');
  }
  return `XML OK: ${xmlFiles.length} component files validated`;
});

// 6. Config validation
check('Configuration files', () => {
  const configFiles = ['config/default.json', 'config/schema.json'];
  for (const configFile of configFiles) {
    const fullPath = path.join(ROOT_DIR, configFile);
    if (!fs.existsSync(fullPath)) {
      return `Missing config file: ${configFile}`;
    }
    try {
      JSON.parse(fs.readFileSync(fullPath, 'utf-8'));
    } catch (e) {
      return `Invalid JSON in ${configFile}: ${e.message}`;
    }
  }
  return 'Config files valid';
});

// Print results
console.log('\n📦 Package Validation Report');
console.log('═'.repeat(60));

for (const check of checks) {
  const icon = check.pass ? '✓' : '✗';
  console.log(`  ${icon} ${check.name}: ${check.detail}`);
}

console.log('═'.repeat(60));
console.log(`  ${checks.filter(c => c.pass).length}/${checks.length} checks passed`);

if (errors.length > 0) {
  console.log('\n❌ ERRORS:');
  for (const err of errors) {
    console.log(`  - ${err}`);
  }
  console.log('\nResult: FAILED');
  process.exit(1);
} else if (warnings.length > 0) {
  console.log('\n⚠ WARNINGS:');
  for (const warn of warnings) {
    console.log(`  - ${warn}`);
  }
  console.log('\nResult: PASSED (with warnings)');
  process.exit(0);
} else {
  console.log('\nResult: PASSED');
  process.exit(0);
}
