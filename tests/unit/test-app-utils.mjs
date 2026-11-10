/**
 * Unit Tests: App.brs Utility Functions
 * 
 * Tests pure logic functions that can be validated in Node.js
 * without a Roku device. These verify the semantic correctness
 * of BrightScript utility functions by re-implementing the logic
 * in JavaScript and comparing expected outputs.
 */

export default async function runTests({ describe, it, assertions }) {
  const { equal, deepEqual, truthy, falsy, isString, isNumber, 
           isArray, isFunction, greaterThan, lessThan, match, empty, throws } = assertions;

  // ============================================================
  // FormatDuration tests
  // Simulates: function FormatDuration(seconds) as String
  // ============================================================

  function formatDuration(seconds) {
    if (seconds < 0) return '0:00';
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    
    if (hours > 0) {
      return `${hours}:${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
    }
    return `${minutes}:${String(secs).padStart(2, '0')}`;
  }

  describe('FormatDuration', () => {
    it('formats zero seconds', () => {
      equal(formatDuration(0), '0:00');
    });

    it('formats seconds less than a minute', () => {
      equal(formatDuration(30), '0:30');
      equal(formatDuration(59), '0:59');
    });

    it('formats minutes and seconds', () => {
      equal(formatDuration(60), '1:00');
      equal(formatDuration(125), '2:05');
      equal(formatDuration(3599), '59:59');
    });

    it('formats hours, minutes and seconds', () => {
      equal(formatDuration(3600), '1:00:00');
      equal(formatDuration(3661), '1:01:01');
      equal(formatDuration(7200), '2:00:00');
      equal(formatDuration(7261), '2:01:01');
    });

    it('handles negative input', () => {
      equal(formatDuration(-1), '0:00');
      equal(formatDuration(-100), '0:00');
    });

    it('handles large durations', () => {
      equal(formatDuration(86400), '24:00:00');
      equal(formatDuration(90061), '25:01:01');
    });
  });

  // ============================================================
  // PadLeft tests
  // Simulates: function PadLeft(str, padChar, width) as String
  // ============================================================

  function padLeft(str, padChar, width) {
    let result = str;
    while (result.length < width) {
      result = padChar + result;
    }
    return result;
  }

  describe('PadLeft', () => {
    it('pads short strings', () => {
      equal(padLeft('1', '0', 2), '01');
      equal(padLeft('5', '0', 3), '005');
    });

    it('does not pad already-wide strings', () => {
      equal(padLeft('123', '0', 2), '123');
      equal(padLeft('hello', 'x', 3), 'hello');
    });

    it('pads with different characters', () => {
      equal(padLeft('ab', 'x', 5), 'xxxab');
      equal(padLeft('A', '-', 4), '---A');
    });

    it('handles empty string', () => {
      equal(padLeft('', '0', 3), '000');
    });

    it('handles width of 0', () => {
      equal(padLeft('abc', '0', 0), 'abc');
    });
  });

  // ============================================================
  // SplitString tests
  // Simulates: function SplitString(str, delimiter) as Object
  // ============================================================

  function splitString(str, delimiter) {
    if (!str || str === '' || !delimiter) return [];
    const result = [];
    let remaining = str;
    while (remaining.length > 0) {
      const idx = remaining.indexOf(delimiter);
      if (idx > 0) {
        result.push(remaining.substring(0, idx));
        remaining = remaining.substring(idx + delimiter.length);
      } else if (idx === 0) {
        result.push('');
        remaining = remaining.substring(delimiter.length);
      } else {
        result.push(remaining);
        remaining = '';
      }
    }
    return result;
  }

  describe('SplitString', () => {
    it('splits by single character', () => {
      deepEqual(splitString('a,b,c', ','), ['a', 'b', 'c']);
    });

    it('splits by multi-character delimiter', () => {
      deepEqual(splitString('a||b||c', '||'), ['a', 'b', 'c']);
    });

    it('handles empty string', () => {
      deepEqual(splitString('', ','), []);
    });

    it('handles null input', () => {
      deepEqual(splitString(null, ','), []);
    });

    it('handles no delimiter found', () => {
      deepEqual(splitString('abc', ','), ['abc']);
    });

    it('handles consecutive delimiters', () => {
      deepEqual(splitString('a,,b', ','), ['a', '', 'b']);
    });
  });

  // ============================================================
  // CreateContentNode tests
  // Simulates: function CreateContentNode(item) as Object
  // ============================================================

  function createContentNode(item) {
    const node = { title: '', description: '', url: '', streamFormat: '' };
    if (!item) return node;
    
    node.title = item.title || '';
    node.description = item.description || '';
    
    if (item.content && item.content.videos && item.content.videos.length > 0) {
      node.streamFormat = 'mp4';
      node.url = item.content.videos[0].url;
      if (item.content.duration) {
        node.length = item.content.duration;
      }
    }
    
    if (item.thumbnail) node.hdPosterUrl = item.thumbnail;
    if (item.category) node.category = item.category;
    
    node.contentIsPlaylist = false;
    node.showNext = true;
    return node;
  }

  describe('CreateContentNode', () => {
    it('creates node from complete item', () => {
      const item = {
        title: 'Test Video',
        description: 'A test',
        content: { videos: [{ url: 'http://example.com/video.mp4' }], duration: 120 },
        thumbnail: 'http://example.com/thumb.jpg',
        category: 'education',
      };
      const node = createContentNode(item);
      equal(node.title, 'Test Video');
      equal(node.streamFormat, 'mp4');
      equal(node.url, 'http://example.com/video.mp4');
      equal(node.length, 120);
      equal(node.hdPosterUrl, 'http://example.com/thumb.jpg');
      equal(node.category, 'education');
      equal(node.contentIsPlaylist, false);
    });

    it('handles null item', () => {
      const node = createContentNode(null);
      equal(node.title, '');
      equal(node.url, '');
    });

    it('handles item without videos', () => {
      const item = { title: 'No Video', description: 'Text only' };
      const node = createContentNode(item);
      equal(node.title, 'No Video');
      equal(node.streamFormat, '');
    });
  });

  // ============================================================
  // SafeRun tests
  // Simulates: function SafeRun(fn as Object, label as String) as Boolean
  // ============================================================

  function safeRun(fn, label) {
    if (!fn) return false;
    
    let result = fn();
    if (result === true) return true;
    
    // First attempt failed
    result = fn();
    if (result === true) return true;
    
    return false;
  }

  describe('SafeRun', () => {
    it('returns true for successful function', () => {
      truthy(safeRun(() => true, 'test'));
    });

    it('retries on first failure', () => {
      let callCount = 0;
      const fn = () => { callCount++; return callCount > 1; };
      truthy(safeRun(fn, 'retry'));
      equal(callCount, 2);
    });

    it('returns false after both attempts fail', () => {
      falsy(safeRun(() => false, 'always-fail'));
    });

    it('handles invalid function', () => {
      falsy(safeRun(null, 'null-fn'));
    });
  });

  // ============================================================
  // GetTimestamp format tests
  // ============================================================

  function getTimestamp(date) {
    const h = String(date.getHours()).padStart(2, '0');
    const m = String(date.getMinutes()).padStart(2, '0');
    const s = String(date.getSeconds()).padStart(2, '0');
    return `${h}:${m}:${s}`;
  }

  describe('GetTimestamp', () => {
    it('formats time with leading zeros', () => {
      const ts = getTimestamp(new Date('2024-01-01T09:05:03'));
      match(ts, /^\d{2}:\d{2}:\d{2}$/);
      equal(ts, '09:05:03');
    });

    it('formats midnight', () => {
      equal(getTimestamp(new Date('2024-01-01T00:00:00')), '00:00:00');
    });

    it('formats noon', () => {
      equal(getTimestamp(new Date('2024-01-01T12:00:00')), '12:00:00');
    });
  });
}
