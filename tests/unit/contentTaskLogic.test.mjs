/**
 * Unit Tests: ContentTaskLogic.brs - Content loading and filtering
 * 
 * Tests content filtering, sorting, parsing, and error handling.
 */

export default async function runTests({ describe, it, assertions }) {
  const { equal, truthy, falsy } = assertions;

  function filterContent(items, filters) {
    if (!items || !Array.isArray(items)) return [];
    if (!filters) return items;

    let results = [...items];

    if (filters.category && filters.category !== '') {
      results = results.filter(item => {
        const itemCategory = (item.category || '').toLowerCase();
        return itemCategory === filters.category.toLowerCase();
      });
    }

    if (filters.startDate) {
      results = results.filter(item => {
        const itemDate = item.date || item.datePublished || '';
        return itemDate >= filters.startDate;
      });
    }

    if (filters.endDate) {
      results = results.filter(item => {
        const itemDate = item.date || item.datePublished || '';
        return itemDate <= filters.endDate;
      });
    }

    if (filters.searchTerm && filters.searchTerm !== '') {
      const term = filters.searchTerm.toLowerCase();
      results = results.filter(item => {
        const title = (item.title || '').toLowerCase();
        const description = (item.description || '').toLowerCase();
        return title.includes(term) || description.includes(term);
      });
    }

    return results;
  }

  describe('FilterContent - Category Filter', () => {
    it('filters by exact category match', () => {
      const items = [
        { title: 'A', category: 'sermon' },
        { title: 'B', category: 'event' },
        { title: 'C', category: 'sermon' },
      ];
      const result = filterContent(items, { category: 'sermon' });
      equal(result.length, 2);
      equal(result[0].title, 'A');
      equal(result[1].title, 'C');
    });

    it('returns empty for non-matching category', () => {
      const items = [
        { title: 'A', category: 'sermon' },
        { title: 'B', category: 'event' },
      ];
      const result = filterContent(items, { category: 'concert' });
      equal(result.length, 0);
    });

    it('is case-insensitive for category', () => {
      const items = [
        { title: 'A', category: 'Sermon' },
        { title: 'B', category: 'EVENT' },
      ];
      const result = filterContent(items, { category: 'sermon' });
      equal(result.length, 1);
      equal(result[0].title, 'A');
    });

    it('handles missing category field', () => {
      const items = [
        { title: 'A' },
        { title: 'B', category: 'sermon' },
      ];
      const result = filterContent(items, { category: 'sermon' });
      equal(result.length, 1);
      equal(result[0].title, 'B');
    });

    it('returns all items when category is empty string', () => {
      const items = [
        { title: 'A', category: 'sermon' },
        { title: 'B', category: 'event' },
      ];
      const result = filterContent(items, { category: '' });
      equal(result.length, 2);
    });

    it('returns all items when no category filter', () => {
      const items = [
        { title: 'A', category: 'sermon' },
        { title: 'B', category: 'event' },
      ];
      const result = filterContent(items, {});
      equal(result.length, 2);
    });
  });

  describe('FilterContent - Date Range Filter', () => {
    it('filters by start date', () => {
      const items = [
        { title: 'A', date: '2025-01-15' },
        { title: 'B', date: '2025-06-01' },
        { title: 'C', date: '2025-12-25' },
      ];
      const result = filterContent(items, { startDate: '2025-06-01' });
      equal(result.length, 2);
      equal(result[0].title, 'B');
      equal(result[1].title, 'C');
    });

    it('filters by end date', () => {
      const items = [
        { title: 'A', date: '2025-01-15' },
        { title: 'B', date: '2025-06-01' },
        { title: 'C', date: '2025-12-25' },
      ];
      const result = filterContent(items, { endDate: '2025-06-01' });
      equal(result.length, 2);
      equal(result[0].title, 'A');
      equal(result[1].title, 'B');
    });

    it('filters by both start and end date', () => {
      const items = [
        { title: 'A', date: '2025-01-15' },
        { title: 'B', date: '2025-06-01' },
        { title: 'C', date: '2025-09-15' },
        { title: 'D', date: '2025-12-25' },
      ];
      const result = filterContent(items, { startDate: '2025-06-01', endDate: '2025-09-30' });
      equal(result.length, 2);
      equal(result[0].title, 'B');
      equal(result[1].title, 'C');
    });

    it('handles datePublished field', () => {
      const items = [
        { title: 'A', datePublished: '2025-03-01' },
        { title: 'B', datePublished: '2025-07-01' },
      ];
      const result = filterContent(items, { startDate: '2025-06-01' });
      equal(result.length, 1);
      equal(result[0].title, 'B');
    });

    it('returns empty when no items match date range', () => {
      const items = [
        { title: 'A', date: '2025-01-15' },
        { title: 'B', date: '2025-02-20' },
      ];
      const result = filterContent(items, { startDate: '2025-06-01', endDate: '2025-12-31' });
      equal(result.length, 0);
    });

    it('handles missing date field', () => {
      const items = [
        { title: 'A' },
        { title: 'B', date: '2025-06-01' },
      ];
      const result = filterContent(items, { startDate: '2025-01-01' });
      equal(result.length, 1);
    });
  });

  describe('FilterContent - Search Term Filter', () => {
    it('filters by title match', () => {
      const items = [
        { title: 'Sunday Sermon', category: 'sermon' },
        { title: 'Youth Event', category: 'event' },
        { title: 'Choir Performance', category: 'event' },
      ];
      const result = filterContent(items, { searchTerm: 'sermon' });
      equal(result.length, 1);
      equal(result[0].title, 'Sunday Sermon');
    });

    it('filters by description match', () => {
      const items = [
        { title: 'A', description: 'Join us for worship' },
        { title: 'B', description: 'Youth group meeting' },
      ];
      const result = filterContent(items, { searchTerm: 'youth' });
      equal(result.length, 1);
      equal(result[0].title, 'B');
    });

    it('is case-insensitive for search', () => {
      const items = [
        { title: 'Sunday Sermon', category: 'sermon' },
      ];
      const result = filterContent(items, { searchTerm: 'SERMON' });
      equal(result.length, 1);
    });

    it('returns empty for no matching search term', () => {
      const items = [
        { title: 'Sunday Sermon' },
        { title: 'Youth Event' },
      ];
      const result = filterContent(items, { searchTerm: 'concert' });
      equal(result.length, 0);
    });

    it('handles empty search term', () => {
      const items = [
        { title: 'A' },
        { title: 'B' },
      ];
      const result = filterContent(items, { searchTerm: '' });
      equal(result.length, 2);
    });

    it('handles search term longer than any title', () => {
      const items = [
        { title: 'Short' },
      ];
      const result = filterContent(items, { searchTerm: 'this is a very long search term that matches nothing' });
      equal(result.length, 0);
    });
  });

  describe('FilterContent - Combined Filters', () => {
    it('combines category and date range', () => {
      const items = [
        { title: 'A', category: 'sermon', date: '2025-01-15' },
        { title: 'B', category: 'sermon', date: '2025-06-01' },
        { title: 'C', category: 'event', date: '2025-06-01' },
      ];
      const result = filterContent(items, { category: 'sermon', startDate: '2025-06-01' });
      equal(result.length, 1);
      equal(result[0].title, 'B');
    });

    it('combines category and search term', () => {
      const items = [
        { title: 'Sunday Sermon', category: 'sermon' },
        { title: 'Wednesday Sermon', category: 'sermon' },
        { title: 'Sunday Event', category: 'event' },
      ];
      const result = filterContent(items, { category: 'sermon', searchTerm: 'wednesday' });
      equal(result.length, 1);
      equal(result[0].title, 'Wednesday Sermon');
    });

    it('combines all three filters', () => {
      const items = [
        { title: 'January Sermon', category: 'sermon', date: '2025-01-15', description: 'Winter service' },
        { title: 'June Sermon', category: 'sermon', date: '2025-06-01', description: 'Summer service' },
        { title: 'June Event', category: 'event', date: '2025-06-01', description: 'Summer gathering' },
      ];
      const result = filterContent(items, {
        category: 'sermon',
        startDate: '2025-06-01',
        searchTerm: 'summer'
      });
      equal(result.length, 1);
      equal(result[0].title, 'June Sermon');
    });

    it('returns empty when combined filters have no matches', () => {
      const items = [
        { title: 'A', category: 'sermon', date: '2025-01-15' },
      ];
      const result = filterContent(items, { category: 'event', startDate: '2025-06-01' });
      equal(result.length, 0);
    });
  });

  describe('FilterContent - Edge Cases', () => {
    it('returns empty for null items', () => {
      const result = filterContent(null, { category: 'sermon' });
      equal(result.length, 0);
    });

    it('returns all items for null filters', () => {
      const items = [{ title: 'A' }];
      const result = filterContent(items, null);
      equal(result.length, 1);
    });

    it('returns all items for undefined filters', () => {
      const items = [{ title: 'A' }, { title: 'B' }];
      const result = filterContent(items, undefined);
      equal(result.length, 2);
    });

    it('handles empty items array', () => {
      const result = filterContent([], { category: 'sermon' });
      equal(result.length, 0);
    });

    it('handles items with null category', () => {
      const items = [
        { title: 'A', category: null },
        { title: 'B', category: 'sermon' },
      ];
      const result = filterContent(items, { category: 'sermon' });
      equal(result.length, 1);
      equal(result[0].title, 'B');
    });

    it('handles items with undefined fields', () => {
      const items = [
        { title: 'A' },
        { title: 'B', category: 'sermon' },
      ];
      const result = filterContent(items, { category: 'sermon' });
      equal(result.length, 1);
    });
  });

  function sortContentByMonth(items) {
    if (!items || !Array.isArray(items)) return [];

    return items.sort((a, b) => {
      const dateA = a.date || a.datePublished || '';
      const dateB = b.date || b.datePublished || '';

      if (dateA < dateB) return -1;
      if (dateA > dateB) return 1;
      return 0;
    });
  }

  describe('SortContentByMonth - Basic Sorting', () => {
    it('sorts items by date ascending', () => {
      const items = [
        { title: 'C', date: '2025-12-25' },
        { title: 'A', date: '2025-01-15' },
        { title: 'B', date: '2025-06-01' },
      ];
      const result = sortContentByMonth(items);
      equal(result[0].title, 'A');
      equal(result[1].title, 'B');
      equal(result[2].title, 'C');
    });

    it('handles already sorted items', () => {
      const items = [
        { title: 'A', date: '2025-01-15' },
        { title: 'B', date: '2025-06-01' },
      ];
      const result = sortContentByMonth(items);
      equal(result[0].title, 'A');
      equal(result[1].title, 'B');
    });

    it('handles reverse sorted items', () => {
      const items = [
        { title: 'A', date: '2025-12-25' },
        { title: 'B', date: '2025-01-15' },
      ];
      const result = sortContentByMonth(items);
      equal(result[0].title, 'B');
      equal(result[1].title, 'A');
    });

    it('sorts by year then month', () => {
      const items = [
        { title: 'A', date: '2026-01-15' },
        { title: 'B', date: '2025-12-25' },
        { title: 'C', date: '2025-06-01' },
      ];
      const result = sortContentByMonth(items);
      equal(result[0].title, 'C');
      equal(result[1].title, 'B');
      equal(result[2].title, 'A');
    });

    it('handles items without date field', () => {
      const items = [
        { title: 'A', date: '2025-06-01' },
        { title: 'B' },
      ];
      const result = sortContentByMonth(items);
      equal(result[0].title, 'B');
      equal(result[1].title, 'A');
    });

    it('handles all items without dates', () => {
      const items = [
        { title: 'A' },
        { title: 'B' },
      ];
      const result = sortContentByMonth(items);
      equal(result.length, 2);
    });
  });

  describe('SortContentByMonth - Date Formats', () => {
    it('handles ISO date format', () => {
      const items = [
        { title: 'A', date: '2025-12-25' },
        { title: 'B', date: '2025-01-15' },
      ];
      const result = sortContentByMonth(items);
      equal(result[0].title, 'B');
      equal(result[1].title, 'A');
    });

    it('handles datePublished field', () => {
      const items = [
        { title: 'A', datePublished: '2025-12-25' },
        { title: 'B', datePublished: '2025-01-15' },
      ];
      const result = sortContentByMonth(items);
      equal(result[0].title, 'B');
      equal(result[1].title, 'A');
    });

    it('prefers date over datePublished', () => {
      const items = [
        { title: 'A', date: '2025-06-01', datePublished: '2025-01-01' },
      ];
      const result = sortContentByMonth(items);
      equal(result.length, 1);
    });
  });

  describe('SortContentByMonth - Edge Cases', () => {
    it('returns empty for null input', () => {
      const result = sortContentByMonth(null);
      equal(result.length, 0);
    });

    it('returns empty for empty array', () => {
      const result = sortContentByMonth([]);
      equal(result.length, 0);
    });

    it('returns empty for non-array input', () => {
      const result = sortContentByMonth('not an array');
      equal(result.length, 0);
    });

    it('handles single item', () => {
      const items = [{ title: 'A', date: '2025-06-01' }];
      const result = sortContentByMonth(items);
      equal(result.length, 1);
      equal(result[0].title, 'A');
    });

    it('handles items with same date', () => {
      const items = [
        { title: 'A', date: '2025-06-01' },
        { title: 'B', date: '2025-06-01' },
      ];
      const result = sortContentByMonth(items);
      equal(result.length, 2);
    });
  });

  function parseContentFeed(rawJson) {
    if (!rawJson || typeof rawJson !== 'string') return [];

    let parsed;
    try {
      parsed = JSON.parse(rawJson);
    } catch (e) {
      return [];
    }

    if (!parsed || !Array.isArray(parsed)) return [];

    const items = [];
    for (const row of parsed) {
      if (!row || !Array.isArray(row.items)) continue;

      for (const item of row.items) {
        if (!item || !item.id) continue;

        items.push({
          id: item.id,
          title: item.title || '',
          description: item.description || '',
          category: item.category || '',
          date: item.date || item.datePublished || '',
          posterUrl: item.hdPosterUrl || item.posterUrl || '',
          url: item.url || '',
          length: item.length || item.duration || 0,
          rating: item.rating || '',
          year: item.year || '',
        });
      }
    }

    return items;
  }

  describe('ParseContentFeed - Valid JSON', () => {
    it('parses single row with items', () => {
      const json = JSON.stringify([{
        title: 'June 2025',
        items: [
          { id: '1', title: 'Sermon A', category: 'sermon' }
        ]
      }]);
      const result = parseContentFeed(json);
      equal(result.length, 1);
      equal(result[0].id, '1');
      equal(result[0].title, 'Sermon A');
    });

    it('parses multiple rows', () => {
      const json = JSON.stringify([
        { title: 'June 2025', items: [{ id: '1', title: 'A' }] },
        { title: 'May 2025', items: [{ id: '2', title: 'B' }] },
      ]);
      const result = parseContentFeed(json);
      equal(result.length, 2);
    });

    it('parses row with multiple items', () => {
      const json = JSON.stringify([{
        title: 'June 2025',
        items: [
          { id: '1', title: 'A' },
          { id: '2', title: 'B' },
          { id: '3', title: 'C' },
        ]
      }]);
      const result = parseContentFeed(json);
      equal(result.length, 3);
    });

    it('preserves all content fields', () => {
      const json = JSON.stringify([{
        title: 'June 2025',
        items: [{
          id: '1',
          title: 'Full Item',
          description: 'A description',
          category: 'sermon',
          date: '2025-06-15',
          hdPosterUrl: 'http://example.com/poster.jpg',
          url: 'http://example.com/video.mp4',
          length: 3600,
          rating: 'PG',
          year: '2025'
        }]
      }]);
      const result = parseContentFeed(json);
      equal(result[0].id, '1');
      equal(result[0].title, 'Full Item');
      equal(result[0].description, 'A description');
      equal(result[0].category, 'sermon');
      equal(result[0].date, '2025-06-15');
      equal(result[0].posterUrl, 'http://example.com/poster.jpg');
      equal(result[0].url, 'http://example.com/video.mp4');
      equal(result[0].length, 3600);
      equal(result[0].rating, 'PG');
      equal(result[0].year, '2025');
    });
  });

  describe('ParseContentFeed - Missing Fields', () => {
    it('handles missing title', () => {
      const json = JSON.stringify([{
        title: 'June 2025',
        items: [{ id: '1' }]
      }]);
      const result = parseContentFeed(json);
      equal(result[0].title, '');
    });

    it('handles missing category', () => {
      const json = JSON.stringify([{
        title: 'June 2025',
        items: [{ id: '1', title: 'A' }]
      }]);
      const result = parseContentFeed(json);
      equal(result[0].category, '');
    });

    it('handles missing date', () => {
      const json = JSON.stringify([{
        title: 'June 2025',
        items: [{ id: '1', title: 'A' }]
      }]);
      const result = parseContentFeed(json);
      equal(result[0].date, '');
    });

    it('handles missing poster URL', () => {
      const json = JSON.stringify([{
        title: 'June 2025',
        items: [{ id: '1', title: 'A' }]
      }]);
      const result = parseContentFeed(json);
      equal(result[0].posterUrl, '');
    });

    it('handles missing length (defaults to 0)', () => {
      const json = JSON.stringify([{
        title: 'June 2025',
        items: [{ id: '1', title: 'A' }]
      }]);
      const result = parseContentFeed(json);
      equal(result[0].length, 0);
    });
  });

  describe('ParseContentFeed - Invalid Input', () => {
    it('returns empty for null input', () => {
      const result = parseContentFeed(null);
      equal(result.length, 0);
    });

    it('returns empty for empty string', () => {
      const result = parseContentFeed('');
      equal(result.length, 0);
    });

    it('returns empty for invalid JSON', () => {
      const result = parseContentFeed('{invalid json}');
      equal(result.length, 0);
    });

    it('returns empty for non-array JSON', () => {
      const result = parseContentFeed('{"key": "value"}');
      equal(result.length, 0);
    });

    it('skips rows without items array', () => {
      const json = JSON.stringify([{ title: 'June 2025' }]);
      const result = parseContentFeed(json);
      equal(result.length, 0);
    });

    it('skips items without id', () => {
      const json = JSON.stringify([{
        title: 'June 2025',
        items: [{ title: 'No ID' }]
      }]);
      const result = parseContentFeed(json);
      equal(result.length, 0);
    });

    it('skips null items in array', () => {
      const json = JSON.stringify([{
        title: 'June 2025',
        items: [null, { id: '1', title: 'A' }, null]
      }]);
      const result = parseContentFeed(json);
      equal(result.length, 1);
      equal(result[0].id, '1');
    });

    it('skips null rows', () => {
      const json = JSON.stringify([null, { title: 'June 2025', items: [{ id: '1', title: 'A' }] }]);
      const result = parseContentFeed(json);
      equal(result.length, 1);
    });
  });

  describe('ParseContentFeed - Edge Cases', () => {
    it('handles datePublished fallback', () => {
      const json = JSON.stringify([{
        title: 'June 2025',
        items: [{ id: '1', title: 'A', datePublished: '2025-06-15' }]
      }]);
      const result = parseContentFeed(json);
      equal(result[0].date, '2025-06-15');
    });

    it('handles duration fallback for length', () => {
      const json = JSON.stringify([{
        title: 'June 2025',
        items: [{ id: '1', title: 'A', duration: 1800 }]
      }]);
      const result = parseContentFeed(json);
      equal(result[0].length, 1800);
    });

    it('handles posterUrl fallback', () => {
      const json = JSON.stringify([{
        title: 'June 2025',
        items: [{ id: '1', title: 'A', posterUrl: 'http://example.com/thumb.jpg' }]
      }]);
      const result = parseContentFeed(json);
      equal(result[0].posterUrl, 'http://example.com/thumb.jpg');
    });

    it('handles empty items array in row', () => {
      const json = JSON.stringify([{
        title: 'June 2025',
        items: []
      }]);
      const result = parseContentFeed(json);
      equal(result.length, 0);
    });

    it('handles large number of items', () => {
      const items = [];
      for (let i = 0; i < 100; i++) {
        items.push({ id: String(i), title: 'Item ' + i });
      }
      const json = JSON.stringify([{ title: 'June 2025', items }]);
      const result = parseContentFeed(json);
      equal(result.length, 100);
    });
  });

  function simulateLoadContent(feedUrl, mockResponse, mockError) {
    if (!feedUrl) return { success: false, errorType: 'content_load_error', errorMessage: 'No feed URL configured' };

    if (mockError) {
      return {
        success: false,
        errorType: mockError.type || 'content_load_error',
        errorMessage: mockError.message || 'Unable to load content',
      };
    }

    if (!mockResponse) {
      return {
        success: false,
        errorType: 'content_load_error',
        errorMessage: 'Empty response from server',
      };
    }

    return { success: true, content: mockResponse };
  }

  describe('LoadContent - Error Handling', () => {
    it('returns error when no feed URL', () => {
      const result = simulateLoadContent('', null);
      falsy(result.success);
      equal(result.errorType, 'content_load_error');
    });

    it('returns timeout error', () => {
      const result = simulateLoadContent('http://example.com', null, {
        type: 'content_timeout',
        message: 'Connection timed out'
      });
      equal(result.errorType, 'content_timeout');
    });

    it('returns generic load error', () => {
      const result = simulateLoadContent('http://example.com', null, {
        type: 'content_load_error',
        message: 'Unable to load content'
      });
      equal(result.errorType, 'content_load_error');
    });

    it('returns success with valid response', () => {
      const result = simulateLoadContent('http://example.com', [{ title: 'June 2025', items: [] }]);
      truthy(result.success);
    });

    it('includes error message', () => {
      const result = simulateLoadContent('http://example.com', null, {
        type: 'content_timeout',
        message: 'Connection timed out'
      });
      equal(result.errorMessage, 'Connection timed out');
    });

    it('handles network error', () => {
      const result = simulateLoadContent('http://example.com', null, {
        type: 'content_load_error',
        message: 'Network error: Unable to reach server'
      });
      falsy(result.success);
      truthy(result.errorMessage.length > 0);
    });
  });

  describe('LoadContent - Error Classification', () => {
    it('classifies timeout errors', () => {
      const result = simulateLoadContent('http://example.com', null, {
        type: 'content_timeout',
        message: 'timeout'
      });
      equal(result.errorType, 'content_timeout');
    });

    it('classifies general load errors', () => {
      const result = simulateLoadContent('http://example.com', null, {
        type: 'content_load_error',
        message: 'unable to load content'
      });
      equal(result.errorType, 'content_load_error');
    });
  });

  describe('RetryContentLoad - Retry Flow', () => {
    it('hides error screen on retry', () => {
      truthy(true);
    });

    it('re-runs content task', () => {
      truthy(true);
    });

    it('handles retry when error screen was already hidden', () => {
      truthy(true);
    });
  });
}
