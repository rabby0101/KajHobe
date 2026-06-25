import { describe, it, expect } from 'vitest';
import { parseMediaItems } from './media';

describe('parseMediaItems', () => {
  it('returns [] for non-arrays', () => {
    expect(parseMediaItems(null)).toEqual([]);
    expect(parseMediaItems('nope')).toEqual([]);
    expect(parseMediaItems({})).toEqual([]);
  });

  it('parses the current object shape', () => {
    const items = parseMediaItems([
      { id: 'a', url: 'http://x/1.jpg', type: 'image', thumbnail_url: 'http://x/t1.jpg' },
      { id: 'b', url: 'http://x/2.mp4', type: 'video', thumbnail_url: 'http://x/t2.jpg' },
    ]);
    expect(items).toHaveLength(2);
    expect(items[0]).toEqual({ id: 'a', url: 'http://x/1.jpg', type: 'image', thumbnail_url: 'http://x/t1.jpg' });
    expect(items[1].type).toBe('video');
  });

  it('defaults missing type to image and missing thumbnail to null', () => {
    const items = parseMediaItems([{ url: 'http://x/1.jpg' }]);
    expect(items[0].type).toBe('image');
    expect(items[0].thumbnail_url).toBeNull();
    expect(items[0].id).toBe('0');
  });

  it('supports legacy bare URL strings and guesses video by extension', () => {
    const items = parseMediaItems(['http://x/clip.mov', 'http://x/pic.png']);
    expect(items[0].type).toBe('video');
    expect(items[1].type).toBe('image');
  });

  it('skips entries without a url', () => {
    expect(parseMediaItems([{ type: 'image' }, ''])).toEqual([]);
  });
});
