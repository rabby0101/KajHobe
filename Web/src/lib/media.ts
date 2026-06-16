// Job media parsing — mirrors the iOS Job.MediaItem model (id/url/type/thumbnail).

export type MediaType = 'image' | 'video';

export interface MediaItem {
  id: string;
  url: string;
  type: MediaType;
  thumbnail_url: string | null;
}

/**
 * Parse a job's `media_urls` JSON into MediaItem[]. Tolerant of legacy shapes:
 * an array of `{url,type,...}` objects (current) or a bare array of URL strings.
 */
export function parseMediaItems(value: unknown): MediaItem[] {
  if (!Array.isArray(value)) return [];
  const items: MediaItem[] = [];
  value.forEach((raw, i) => {
    if (typeof raw === 'string') {
      if (raw) items.push({ id: String(i), url: raw, type: guessType(raw), thumbnail_url: null });
      return;
    }
    if (raw && typeof raw === 'object') {
      const obj = raw as Record<string, unknown>;
      const url = typeof obj.url === 'string' ? obj.url : '';
      if (!url) return;
      const type: MediaType = obj.type === 'video' ? 'video' : 'image';
      items.push({
        id: typeof obj.id === 'string' ? obj.id : String(i),
        url,
        type,
        thumbnail_url: typeof obj.thumbnail_url === 'string' ? obj.thumbnail_url : null,
      });
    }
  });
  return items;
}

/** Best-effort media type from a file extension (used for legacy string urls). */
function guessType(url: string): MediaType {
  return /\.(mp4|mov|webm|m4v)(\?|$)/i.test(url) ? 'video' : 'image';
}
