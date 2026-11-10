#!/usr/bin/env node
/**
 * build.mjs - Roku channel packaging script
 * Compiles BrighterScript (.bs) to BrightScript (.brs), then packages into a .zip
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execSync, spawnSync } from 'child_process';
import AdmZip from 'adm-zip';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BUILD_DIR = 'build';
const STAGING_DIR = '.roku-staging';
const CHANNEL_ZIP = path.join(__dirname, BUILD_DIR, 'channel.zip');

function colorizeNavBg() {
  const configPath = path.join(__dirname, 'config', 'default.json');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

  // Get color: navFocusBg → fallback to focus → fallback to accent
  let colorHex = config.branding?.colors?.navFocusBg
    || config.branding?.colors?.focus
    || config.branding?.colors?.accent
    || '#E8B931';

  // Strip leading 0x if present
  colorHex = colorHex.replace(/^0x/, '#');
  // Handle 0xRRGGBB → #RRGGBB
  if (colorHex.length === 7 && colorHex[0] === '#') {
    // already good
  } else if (colorHex.length === 9) {
    // RGBA, strip alpha
    colorHex = colorHex.substring(0, 7);
  }

  const srcMask = path.join(__dirname, 'images', 'nav_bg.png');
  const dstColored = path.join(STAGING_DIR, 'images', 'nav_bg.png');
  fs.mkdirSync(path.dirname(dstColored), { recursive: true });

  // Use ImageMagick to colorize: replace white pixels with target color
  const result = spawnSync('magick', [
    srcMask,
    '-fuzz', '1%',
    '-fill', colorHex,
    '-colorize', '100',
    dstColored
  ], { encoding: 'utf8' });

  if (result.status !== 0) {
    console.error(`Colorize nav_bg failed: ${result.stderr}`);
    // Fallback: just copy the mask as-is so build doesn't break
    fs.copyFileSync(srcMask, dstColored);
    console.warn('Using uncolorized nav_bg mask as fallback.');
  } else {
    const stats = fs.statSync(dstColored);
    console.log(`Colorized nav_bg to ${colorHex} (${stats.size} bytes)`);
  }
}

function collectFiles(dir, baseDir = '') {
  const files = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    const relativePath = path.join(baseDir, entry.name);

    // Skip node_modules and build directories
    if (entry.name === 'node_modules' || entry.name === BUILD_DIR) {
      continue;
    }

    // Skip .git directory
    if (entry.name === '.git') {
      continue;
    }

    // Skip DOX files — these are development docs, not channel content
    const rel = relativePath.replace(/\\/g, '/');
    if (rel.includes('/AGENTS.md') || rel.includes('/README.md') || rel.includes('/improvements.md')) {
      continue;
    }

    // Skip .husky, tools, docs, plan, report directories — dev-only content
    if (entry.name === '.husky' || entry.name === 'tools' || entry.name === 'docs' || 
        entry.name === 'plan' || entry.name === 'report') {
      continue;
    }

    if (entry.isDirectory()) {
      files.push(...collectFiles(fullPath, relativePath));
    } else {
      files.push({ from: fullPath, to: relativePath });
    }
  }
  return files;
}

function main() {
  // Clean build and staging directories
  if (fs.existsSync(BUILD_DIR)) {
    fs.rmSync(BUILD_DIR, { recursive: true });
  }
  if (fs.existsSync(STAGING_DIR)) {
    fs.rmSync(STAGING_DIR, { recursive: true });
  }
  fs.mkdirSync(BUILD_DIR, { recursive: true });

  // Compile BrighterScript to BrightScript
  console.log('Compiling BrighterScript...');
  try {
    execSync('node_modules/.bin/bsc', { stdio: 'inherit', cwd: __dirname });
  } catch (e) {
    console.error('BrighterScript compilation failed:');
    process.exit(1);
  }

  // Copy manifest to staging (bsc doesn't handle non-source files)
  const manifestSrc = path.join(__dirname, 'manifest');
  if (fs.existsSync(manifestSrc)) {
    fs.copyFileSync(manifestSrc, path.join(STAGING_DIR, 'manifest'));
  }

  // Collect files from staging directory (transpiled output)
  if (!fs.existsSync(STAGING_DIR)) {
    console.error('Staging directory not found after compilation.');
    process.exit(1);
  }

  // Colorize nav_bg mask from config before packaging
  colorizeNavBg();

  const filesToCopy = collectFiles(STAGING_DIR);
  console.log(`Packaging ${filesToCopy.length} files...`);

  // Create zip using adm-zip
  const zip = new AdmZip();
  for (const { from, to } of filesToCopy) {
    zip.addLocalFile(from, '', to);
  }

  // Write the zip file
  zip.writeZip(CHANNEL_ZIP);

  const stats = fs.statSync(CHANNEL_ZIP);
  console.log(`Built: ${CHANNEL_ZIP}`);
  console.log(`Size: ${(stats.size / 1024).toFixed(1)} KB`);
}

main();
