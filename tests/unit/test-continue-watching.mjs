/**
 * Unit Tests: Continue Watching
 * 
 * Tests continue watching functionality
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

  describe('Continue Watching', () => {
    it('ContinueWatching.brs file exists', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'ContinueWatching.brs');
      truthy(fileExists(testPath), 'ContinueWatching.brs should exist');
    });

    it('ContinueWatching has required functions', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'ContinueWatching.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('SavePlaybackPosition'), 'Should have SavePlaybackPosition function');
      truthy(content.includes('GetPlaybackPosition'), 'Should have GetPlaybackPosition function');
      truthy(content.includes('GetContinueWatchingItems'), 'Should have GetContinueWatchingItems function');
      truthy(content.includes('HasPartiallyWatched'), 'Should have HasPartiallyWatched function');
    });

    it('SavePlaybackPosition stores contentId, position, duration, progress, and timestamp', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'ContinueWatching.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('positionData.contentId'), 'Should store contentId in position data');
      truthy(content.includes('positionData.position'), 'Should store position in position data');
      truthy(content.includes('positionData.duration'), 'Should store duration in position data');
      truthy(content.includes('positionData.progress'), 'Should calculate and store progress percentage');
      truthy(content.includes('positionData.timestamp'), 'Should store timestamp for ordering');
    });

    it('SavePlaybackPosition limits to max 20 items and removes oldest', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'ContinueWatching.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('> 20'), 'Should check if count exceeds 20-item limit');
      truthy(content.includes('SortKeysByTimestamp'), 'Should sort keys by timestamp when exceeding limit');
      truthy(content.includes('Delete'), 'Should delete oldest entries when over limit');
    });

    it('SavePlaybackPosition saves to roPreferences with key "continue_watching"', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'ContinueWatching.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('SavePreference("continue_watching"'), 'Should persist data using SavePreference');
      truthy(content.includes('FormatJson(data)'), 'Should serialize data as JSON before saving');
    });

    it('GetPlaybackPosition returns position data for a given contentId', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'ContinueWatching.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('DoesExist(contentId)'), 'Should check if contentId exists in stored data');
      truthy(content.includes('return data[contentId]'), 'Should return position data for matching contentId');
    });

    it('GetPlaybackPosition returns invalid when contentId not found', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'ContinueWatching.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('return invalid'), 'Should return invalid when no data exists');
    });

    it('HasPartiallyWatched returns true only for 5%-95% progress range', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'ContinueWatching.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('progress > 5'), 'Should require more than 5% progress to count as partially watched');
      truthy(content.includes('progress < 95'), 'Should require less than 95% progress (not fully watched)');
    });

    it('RemoveContinueWatchingItem deletes entry and persists', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'ContinueWatching.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('data.Delete(contentId)'), 'Should delete the specific contentId from stored data');
      truthy(content.includes('SavePreference("continue_watching"'), 'Should persist after deletion');
    });

    it('ClearContinueWatchingData empties all data', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'ContinueWatching.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('SavePreference("continue_watching", "")'), 'Should clear by saving empty string');
    });

    it('GetContinueWatchingData deserializes JSON from preferences', () => {
      const testPath = path.join(ROOT_DIR, '..', 'source', 'ContinueWatching.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('LoadPreference("continue_watching"'), 'Should load from preference key "continue_watching"');
      truthy(content.includes('ParseJson(json)'), 'Should parse JSON string into associative array');
    });
  });

  describe('Continue Watching Screen', () => {
    it('ContinueWatchingScreen files exist', () => {
      const xmlPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.xml');
      const brsPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.brs');
      
      truthy(fileExists(xmlPath), 'ContinueWatchingScreen.xml should exist');
      truthy(fileExists(brsPath), 'ContinueWatchingScreen.brs should exist');
    });

    it('ContinueWatchingScreen.brs has required subs', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('Init'), 'Should have Init sub');
      truthy(content.includes('LoadContinueWatching'), 'Should have LoadContinueWatching sub');
      truthy(content.includes('OnRowListSelect'), 'Should have OnRowListSelect sub');
    });

    it('LoadContinueWatching creates ContentNodes with playback position fields', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('playbackPosition'), 'Should set playbackPosition on continue watching nodes');
      truthy(content.includes('playbackDuration'), 'Should set playbackDuration on continue watching nodes');
      truthy(content.includes('playbackProgress'), 'Should set playbackProgress on continue watching nodes');
    });

    it('LoadContinueWatching joins continue watching data with feed content', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('FindContentById'), 'Should search for matching content in the feed');
      truthy(content.includes('for each contentId in positions'), 'Should iterate over saved continue watching entries');
    });

    it('LoadContinueWatching shows empty state when no data', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('m.emptyState.visible = true'), 'Should show empty state when no continue watching data');
      truthy(content.includes('m.continueRowList.visible = false'), 'Should hide row list when no continue watching data');
    });

    it('LoadContinueWatching shows row list when data exists', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('m.emptyState.visible = false'), 'Should hide empty state when data exists');
      truthy(content.includes('m.continueRowList.visible = true'), 'Should show row list when data exists');
    });

    it('FindContentById searches feed rows for matching contentId', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('GetChildCount()'), 'Should iterate over child nodes of feed');
      truthy(content.includes('item.id = contentId'), 'Should compare each item id against target contentId');
      truthy(content.includes('return invalid'), 'Should return invalid when no match found');
    });

    it('OnRowListSelect fires play event with selected item info', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('m.top.play = true'), 'Should fire play event on m.top when user selects an item');
      truthy(content.includes('TrackInteraction("continue_watching"'), 'Should track the interaction with analytics');
    });

    it('OnRowListSelect sets ClipStart for resume position', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('ClipStart'), 'Should set ClipStart field on content node for seek position');
    });

    it('OnRowListSelect sets selectedContent with the continue watching item', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('selectedContent'), 'Should set selectedContent for navigation context');
    });

    it('OnRowListSelect extracts position from the continue watching node', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('playbackPosition'), 'Should read playbackPosition from selected item');
    });

    it('ContinueWatchingScreen.xml declares required interface fields', () => {
      const xmlPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.xml');
      const content = readFile(xmlPath);
      
      truthy(content.includes('id="content"'), 'Should accept content feed via interface');
      truthy(content.includes('id="play"'), 'Should expose play event via interface');
      truthy(content.includes('LoadContinueWatching'), 'Should declare LoadContinueWatching function');
    });

    it('ContinueWatchingScreen.xml has RowList and empty state children', () => {
      const xmlPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.xml');
      const content = readFile(xmlPath);
      
      truthy(content.includes('id="continueRowList"'), 'Should have continueRowList node');
      truthy(content.includes('id="emptyState"'), 'Should have empty state group');
      truthy(content.includes('visible="false"'), 'Empty state should be hidden by default');
    });

    it('ContinueWatchingScreen.brs has OnExit cleanup', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('OnExit'), 'Should have OnExit handler for cleanup');
      truthy(content.includes('SafeUnobserveField'), 'Should clean up field observers on exit');
    });

    it('LoadContinueWatching sets standard ContentNode fields', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('continueNode.title'), 'Should copy title from feed content');
      truthy(content.includes('continueNode.hdPosterUrl'), 'Should copy poster URL from feed content');
      truthy(content.includes('continueNode.url'), 'Should copy stream URL from feed content');
      truthy(content.includes('continueNode.streamFormat'), 'Should copy stream format from feed content');
    });

    it('LoadContinueWatching sets playlist fields on continue watching nodes', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('contentIsPlaylist'), 'Should set contentIsPlaylist field');
      truthy(content.includes('showNext'), 'Should set showNext field for playback behavior');
    });

    it('OnRowListSelect sets ClipStart for resume position', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('ClipStart'), 'Should set ClipStart field on content node for seek position');
    });

    it('OnRowListSelect sets selectedContent with the continue watching item', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('selectedContent'), 'Should set selectedContent for navigation context');
    });

    it('OnRowListSelect extracts position from the continue watching node', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('playbackPosition'), 'Should read playbackPosition from selected item');
    });

    it('VideoPlayerLogic uses Clone for content to preserve ClipStart', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'UILogic', 'VideoPlayerLogic.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('.Clone('), 'Should clone content node (preserves ClipStart and other fields)');
    });

    it('VideoPlayerLogic sets control to play after assigning content', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'UILogic', 'VideoPlayerLogic.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('m.videoPlayer.control = "play"'), 'Should start playback by setting control to play');
    });

     it('ContinueWatchingScreen.xml exposes selectedContent in interface', () => {
      const xmlPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.xml');
      const content = readFile(xmlPath);
      
      truthy(content.includes('id="selectedContent"'), 'Should expose selectedContent field for navigation context');
    });

    it('VideoScreen saves playback position when video finishes', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'VideoScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('SavePlaybackPosition'), 'Should save playback position on video completion');
    });

    it('VideoScreen removes from continue watching when fully watched (>= 95%)', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'VideoScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('HasPartiallyWatched'), 'Should check if video was only partially watched');
    });

    it('VideoScreen onContentChange preserves ClipStart from source content', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'VideoScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('ClipStart'), 'Should copy ClipStart to new ContentNode for Video player');
    });

    it('ContinueWatchingScreen tracks continue watching interaction', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('TrackInteraction("continue_watching"'), 'Should track continue watching interactions');
    });

    it('OnRowListSelect sets ClipStart only when position > 0', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('playbackPosition > 0'), 'Should only set ClipStart when there is a saved position');
    });

    it('LoadContinueWatching iterates positions and skips missing feed items', () => {
      const testPath = path.join(ROOT_DIR, '..', 'components', 'ContinueWatchingScreen.brs');
      const content = readFile(testPath);
      
      truthy(content.includes('if contentItem <> invalid'), 'Should skip continue watching entries whose feed item was deleted');
    });
  });
}
