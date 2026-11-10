/**
 * Unit Tests: Watch Later (REMOVED)
 * 
 * Tests that Watch Later has been properly removed from the channel.
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = path.resolve(__dirname, '..');

export default async function runTests({ describe, it, assertions }) {
  const { falsy, truthy } = assertions;

  function fileExists(testPath) {
    try {
      return fs.existsSync(testPath);
    } catch (e) {
      return false;
    }
  }

  describe('Watch Later — Removed', () => {
    it('WatchLater.brs has been removed from source/', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'WatchLater.brs');
      falsy(fileExists(testPath), 'WatchLater.brs should NOT exist (removed)');
    });

    it('WatchLaterScreen files have been removed from components/', () => {
      const xmlPath = path.join(ROOT_DIR, '..', 'components', 'WatchLaterScreen.xml');
      const brsPath = path.join(ROOT_DIR, '..', 'components', 'WatchLaterScreen.brs');
      
      falsy(fileExists(xmlPath), 'WatchLaterScreen.xml should NOT exist (removed)');
      falsy(fileExists(brsPath), 'WatchLaterScreen.brs should NOT exist (removed)');
    });

    it('Watch Later nav item is hidden in config', () => {
      const configPath = path.join(ROOT_DIR, '..', 'config', 'default.json');
      const content = fs.readFileSync(configPath, 'utf-8');
      const config = JSON.parse(content);
      
      // Watch later nav item has been removed from config (not just hidden)
      const watchLaterNav = config.navItems?.find(item => item.id === 'watchlater');
      falsy(watchLaterNav !== undefined, 'watchlater nav item should NOT exist in config (removed)');
    });

    it('Watch Later is not referenced in ContentCard.xml scripts', () => {
      const ccPath = path.join(ROOT_DIR, '..', 'components', 'ContentCard.xml');
      const content = fs.readFileSync(ccPath, 'utf-8');
      
      falsy(content.includes('WatchLater.brs'), 'ContentCard.xml should NOT reference WatchLater.brs');
    });
  });
}
