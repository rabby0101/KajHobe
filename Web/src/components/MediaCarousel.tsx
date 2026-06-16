import { useEffect, useState } from 'react';
import {
  Carousel,
  CarouselContent,
  CarouselItem,
  CarouselNext,
  CarouselPrevious,
  type CarouselApi,
} from '@/components/ui/carousel';
import { Dialog, DialogContent } from '@/components/ui/dialog';
import { cn } from '@/lib/utils';
import type { MediaItem } from '@/lib/media';

interface MediaCarouselProps {
  items: MediaItem[];
  className?: string;
  /** Height of the inline carousel. */
  height?: number;
}

function MediaSlide({ item, onOpen }: { item: MediaItem; onOpen?: () => void }) {
  if (item.type === 'video') {
    return (
      <video
        src={item.url}
        poster={item.thumbnail_url ?? undefined}
        controls
        className="h-full w-full bg-black object-contain"
      />
    );
  }
  return (
    <img
      src={item.url}
      alt=""
      loading="lazy"
      onClick={onOpen}
      className="h-full w-full cursor-zoom-in bg-muted object-cover"
    />
  );
}

/** Swipeable job media gallery with page dots + fullscreen (parity with iOS MediaCarouselView). */
export default function MediaCarousel({ items, className, height = 220 }: MediaCarouselProps) {
  const [api, setApi] = useState<CarouselApi>();
  const [current, setCurrent] = useState(0);
  const [fullscreen, setFullscreen] = useState(false);

  useEffect(() => {
    if (!api) return;
    const onSelect = () => setCurrent(api.selectedScrollSnap());
    onSelect();
    api.on('select', onSelect);
    return () => {
      api.off('select', onSelect);
    };
  }, [api]);

  if (items.length === 0) return null;

  return (
    <>
      <div className={cn('relative overflow-hidden rounded-lg', className)}>
        <Carousel setApi={setApi} className="w-full">
          <CarouselContent>
            {items.map((item) => (
              <CarouselItem key={item.id}>
                <div style={{ height }} className="overflow-hidden rounded-lg">
                  <MediaSlide item={item} onOpen={() => setFullscreen(true)} />
                </div>
              </CarouselItem>
            ))}
          </CarouselContent>
          {items.length > 1 && (
            <>
              <CarouselPrevious className="left-2" />
              <CarouselNext className="right-2" />
            </>
          )}
        </Carousel>

        {items.length > 1 && (
          <div className="absolute bottom-2 left-1/2 flex -translate-x-1/2 items-center gap-1.5 rounded-full bg-black/40 px-2 py-1">
            {items.map((item, i) => (
              <span
                key={item.id}
                className={cn('h-1.5 w-1.5 rounded-full', i === current ? 'bg-white' : 'bg-white/50')}
              />
            ))}
          </div>
        )}
      </div>

      <Dialog open={fullscreen} onOpenChange={setFullscreen}>
        <DialogContent className="max-w-3xl p-0">
          <MediaSlide item={items[current]} />
        </DialogContent>
      </Dialog>
    </>
  );
}
