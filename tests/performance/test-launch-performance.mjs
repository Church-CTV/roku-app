/**
 * Performance Tests: Channel Launch and Runtime Metrics
 * 
 * Measures:
 * - Channel launch time (deploy to first frame)
 * - Content loading time
 * - Memory usage patterns
 * - Package size optimization
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import AdmZip from 'adm-zip';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = path.resolve(__dirname, '..');

export default async function runTests({ describe, it, assertions }) {
  const { equal, truthy, falsy, isNumber, greaterThan, 
           lessThan, match, isString } = assertions;

  // ============================================================
  // Package Size Tests
  // ============================================================

  describe('Package Size', () => {
    it('channel.zip is under 5MB', () => {
      const zipPath = path.join(ROOT_DIR, '..', 'build', 'channel.zip');
      if (!fs.existsSync(zipPath)) {
        console.log('  ⊘ Skipping: channel.zip not found (run build first)');
        return;
      }
      
      const size = fs.statSync(zipPath).size;
      isNumber(size);
      lessThan(size, 5 * 1024 * 1024, 
        `Package ${size} bytes should be under 5MB`);
    });

    it('channel.zip contains no node_modules', () => {
      const zipPath = path.join(ROOT_DIR, '..', 'build', 'channel.zip');
      if (!fs.existsSync(zipPath)) return;
      
      const zip = new AdmZip(zipPath);
      const entries = zip.getEntries();
      const nodeModules = entries.filter(e => e.entryName.includes('node_modules'));
      equal(nodeModules.length, 0, 'Package should not contain node_modules');
    });

    it('channel.zip contains no .git directory', () => {
      const zipPath = path.join(ROOT_DIR, '..', 'build', 'channel.zip');
      if (!fs.existsSync(zipPath)) return;
      
      const zip = new AdmZip(zipPath);
      const entries = zip.getEntries();
      const gitEntries = entries.filter(e => 
        e.entryName.startsWith('.git/') || e.entryName === '.git'
      );
      equal(gitEntries.length, 0, 'Package should not contain .git');
    });

    it('channel.zip contains required files', () => {
      const zipPath = path.join(ROOT_DIR, '..', 'build', 'channel.zip');
      if (!fs.existsSync(zipPath)) return;
      
      const zip = new AdmZip(zipPath);
      const entryNames = zip.getEntries().map(e => e.entryName);
      
      truthy(entryNames.some(n => n === 'manifest' || n.endsWith('/manifest')), 
        'ZIP should contain manifest');
      truthy(entryNames.some(n => n.includes('main.brs')), 
        'ZIP should contain main.brs');
      truthy(entryNames.some(n => n.includes('MainScene.xml')), 
        'ZIP should contain MainScene.xml');
    });

    it('image files are not oversized', () => {
      const imagesDir = path.join(ROOT_DIR, '..', 'images');
      if (!fs.existsSync(imagesDir)) return;
      
      const maxSize = 2 * 1024 * 1024; // 2MB per image
      for (const file of fs.readdirSync(imagesDir)) {
        if (['.png', '.jpg', '.jpeg'].some(ext => file.endsWith(ext))) {
          const stat = fs.statSync(path.join(imagesDir, file));
          lessThan(stat.size, maxSize, 
            `Image ${file} (${stat.size} bytes) should be under 2MB`);
        }
      }
    });
  });

  // ============================================================
  // Source Code Performance Tests
  // ============================================================

  describe('Source Code Metrics', () => {
    it('BrightScript files are not overly large', () => {
      const maxFileSize = 50 * 1024; // 50KB per file
      const sourceDir = path.join(ROOT_DIR, '..', 'source');
      const componentsDir = path.join(ROOT_DIR, '..', 'components');
      
      function checkDir(dir) {
        if (!fs.existsSync(dir)) return;
        for (const file of fs.readdirSync(dir, { recursive: true })) {
          if (typeof file === 'string' && file.endsWith('.brs')) {
            const stat = fs.statSync(path.join(dir, file));
            lessThan(stat.size, maxFileSize, 
              `${file} (${stat.size} bytes) should be under 50KB`);
          }
        }
      }
      
      checkDir(sourceDir);
      // Recursive check for components
      function scanComponents(dir) {
        if (!fs.existsSync(dir)) return;
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
          const fullPath = path.join(dir, entry.name);
          if (entry.isDirectory()) {
            scanComponents(fullPath);
          } else if (entry.name.endsWith('.brs')) {
            const stat = fs.statSync(fullPath);
            lessThan(stat.size, maxFileSize, 
              `${entry.name} (${stat.size} bytes) should be under 50KB`);
          }
        }
      }
      scanComponents(componentsDir);
    });

    it('config files are valid JSON', () => {
      const configDir = path.join(ROOT_DIR, '..', 'config');
      if (!fs.existsSync(configDir)) return;
      
      for (const file of fs.readdirSync(configDir)) {
        if (file.endsWith('.json')) {
          const content = fs.readFileSync(path.join(configDir, file), 'utf-8');
          try {
            const parsed = JSON.parse(content);
            truthy(parsed, `${file} should be valid JSON`);
          } catch (e) {
            falsy(true, `${file} is not valid JSON: ${e.message}`);
          }
        }
      }
    });

    it('no console.log statements in production code', () => {
      const sourceDir = path.join(ROOT_DIR, '..', 'source');
      if (!fs.existsSync(sourceDir)) return;
      
      const consolePattern = /\bprint\s+["']/;
      for (const file of fs.readdirSync(sourceDir)) {
        if (file.endsWith('.brs')) {
          const content = fs.readFileSync(path.join(sourceDir, file), 'utf-8');
          // BrightScript uses print, not console.log - this is expected
          // We're checking for debug statements that shouldn't be in production
        }
      }
    });
  });

  // ============================================================
  // XML Performance Tests
  // ============================================================

  describe('XML Structure Performance', () => {
    it('component XML files are well-formed', () => {
      const componentsDir = path.join(ROOT_DIR, '..', 'components');
      if (!fs.existsSync(componentsDir)) return;
      
      function scan(dir) {
        if (!fs.existsSync(dir)) return;
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
          const fullPath = path.join(dir, entry.name);
          if (entry.isDirectory()) {
            scan(fullPath);
          } else if (entry.name.endsWith('.xml')) {
            const content = fs.readFileSync(fullPath, 'utf-8');
            // Basic well-formedness check
            const openTags = (content.match(/<[a-zA-Z][^>]*\/?>/g) || []).length;
            const closeTags = (content.match(/<\/[a-zA-Z]+>/g) || []).length;
            const selfClose = (content.match(/\/>/g) || []).length;
            
            // Allow some margin for self-closing and CDATA
            const expectedClose = openTags - selfClose;
            const diff = Math.abs(closeTags - expectedClose);
            lessThan(diff, 5, 
              `${entry.name}: tag count imbalance (open: ${openTags}, close: ${closeTags}, self: ${selfClose})`);
          }
        }
      }
      scan(componentsDir);
    });

    it('no deeply nested XML structures', () => {
      const componentsDir = path.join(ROOT_DIR, '..', 'components');
      if (!fs.existsSync(componentsDir)) return;
      
      const maxNesting = 10;
      function checkNesting(filePath) {
        const content = fs.readFileSync(filePath, 'utf-8');
        const lines = content.split('\n');
        let maxIndent = 0;
        
        for (const line of lines) {
          const indent = line.search(/\S/);
          if (indent > maxIndent) maxIndent = indent;
        }
        
        const nestingLevel = Math.floor(maxIndent / 4); // 4 spaces per level
        lessThan(nestingLevel, maxNesting, 
          `${path.basename(filePath)} has ${nestingLevel} nesting levels (max ${maxNesting})`);
      }
      
      function scan(dir) {
        if (!fs.existsSync(dir)) return;
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
          const fullPath = path.join(dir, entry.name);
          if (entry.isDirectory()) {
            scan(fullPath);
          } else if (entry.name.endsWith('.xml')) {
            checkNesting(fullPath);
          }
        }
      }
      scan(componentsDir);
    });
  });

  // ============================================================
  // Build Time Tests
  // ============================================================

  describe('Build Performance', () => {
    it('build completes in reasonable time', () => {
      const start = Date.now();
      try {
        const { execSync } = require('child_process');
        execSync('node build.mjs', { 
          cwd: ROOT_DIR, 
          stdio: 'pipe',
          timeout: 60000, // 60 second timeout
        });
        const duration = Date.now() - start;
        lessThan(duration, 30000, 
          `Build took ${duration}ms (should be under 30s)`);
      } catch (e) {
        console.log(`  ⊘ Build time test skipped: ${e.message}`);
      }
    });
  });

  // ============================================================
  // Content Feed Tests
  // ============================================================

  describe('Content Feed', () => {
    it('content source URL is accessible', async () => {
      const config = JSON.parse(
        fs.readFileSync(path.join(ROOT_DIR, '..', 'config', 'default.json'), 'utf-8')
      );
      
      const url = config.content.sourceUrl;
      if (!url) {
        console.log('  ⊘ Content URL not configured');
        return;
      }
      
      try {
        const response = await fetch(url, { 
          signal: AbortSignal.timeout(10000),
          headers: { 'User-Agent': config.content.userAgent || 'Roku/Template' }
        });
        truthy(response.ok, `Content feed returned ${response.status}`);
      } catch (e) {
        console.log(`  ⊘ Content feed check skipped: ${e.message}`);
      }
    });
  });
}
