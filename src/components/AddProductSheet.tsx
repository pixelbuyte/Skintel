import { useEffect, useState } from 'react';
import { Drawer } from 'vaul';
import { useNavigate } from 'react-router-dom';
import { ScanLine, ImageIcon, Link2, ChevronLeft } from 'lucide-react';
import BarcodeScanner, { type BarcodeResult } from './BarcodeScanner';
import PhotoUpload from './PhotoUpload';
import ImportFromUrl from './ImportFromUrl';

type Mode = 'picker' | 'barcode' | 'photo' | 'url';

export type PrefillData = {
  brand: string | null;
  productName: string | null;
  ingredients: string;
  upc?: string | null;
};

type Tile = {
  id: Exclude<Mode, 'picker'>;
  icon: typeof ScanLine;
  title: string;
  hint: string;
};

const TILES: Tile[] = [
  { id: 'barcode', icon: ScanLine, title: 'Scan barcode', hint: 'Fastest. Camera reads EAN/UPC.' },
  { id: 'photo', icon: ImageIcon, title: 'Snap ingredient label', hint: 'AI OCR reads the back of the bottle' },
  { id: 'url', icon: Link2, title: 'Paste product URL', hint: 'Sephora, Ulta, brand sites' },
];

export function AddProductSheet({
  open,
  onOpenChange,
  initialMode = 'picker',
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  initialMode?: Mode;
}) {
  const nav = useNavigate();
  const [mode, setMode] = useState<Mode>(initialMode);

  useEffect(() => {
    if (open) setMode(initialMode);
  }, [open, initialMode]);

  function complete(data: PrefillData) {
    onOpenChange(false);
    nav('/app/products/new', { state: { prefill: data } });
  }

  function onBarcode(d: BarcodeResult) {
    complete({
      brand: d.brand ?? null,
      productName: d.productName ?? null,
      ingredients: d.ingredients,
      upc: d.upc,
    });
  }

  return (
    <Drawer.Root open={open} onOpenChange={onOpenChange}>
      <Drawer.Portal>
        <Drawer.Overlay className="fixed inset-0 z-50 bg-black/40 backdrop-blur-sm" />
        <Drawer.Content className="fixed bottom-0 left-0 right-0 z-50 mt-24 flex flex-col rounded-t-3xl bg-card outline-none">
          <Drawer.Title className="sr-only">Add product</Drawer.Title>
          <Drawer.Description className="sr-only">Choose how to add your product</Drawer.Description>
          <div className="mx-auto mt-2 mb-2 h-1.5 w-12 rounded-full bg-border" />
          <div
            className="px-5 pt-2 pb-6 max-h-[85vh] overflow-y-auto"
            style={{ paddingBottom: 'max(env(safe-area-inset-bottom), 1.5rem)' }}
          >
            {mode === 'picker' && (
              <div className="space-y-4">
                <div>
                  <h2 className="font-display text-3xl">Add a product</h2>
                  <p className="text-sm text-muted mt-1">Pick how you want to capture it.</p>
                </div>
                <div className="space-y-3 pt-1">
                  {TILES.map(({ id, icon: Icon, title, hint }) => (
                    <button
                      key={id}
                      type="button"
                      onClick={() => setMode(id)}
                      className="w-full card p-4 text-left flex items-center gap-4 active:scale-[0.98] transition-transform duration-200 ease-ios hover:shadow-soft min-h-16"
                    >
                      <div className="w-12 h-12 rounded-2xl bg-primary/10 flex items-center justify-center text-primary shrink-0">
                        <Icon size={22} />
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="font-medium">{title}</div>
                        <div className="text-xs text-muted mt-0.5">{hint}</div>
                      </div>
                    </button>
                  ))}
                </div>
              </div>
            )}

            {mode !== 'picker' && (
              <div className="space-y-4">
                <button
                  type="button"
                  onClick={() => setMode('picker')}
                  className="inline-flex items-center gap-1 text-sm text-muted min-h-11"
                >
                  <ChevronLeft size={16} /> Back
                </button>

                {mode === 'barcode' && <BarcodeScanner onScanned={onBarcode} onSwitchToPhoto={() => setMode('photo')} />}
                {mode === 'photo' && (
                  <PhotoUpload
                    onExtracted={(d) =>
                      complete({
                        brand: d.brand ?? null,
                        productName: d.productName ?? null,
                        ingredients: d.ingredients,
                      })
                    }
                  />
                )}
                {mode === 'url' && (
                  <ImportFromUrl
                    onImported={(d) =>
                      complete({
                        brand: d.brand ?? null,
                        productName: d.productName ?? null,
                        ingredients: d.ingredients,
                      })
                    }
                  />
                )}
              </div>
            )}
          </div>
        </Drawer.Content>
      </Drawer.Portal>
    </Drawer.Root>
  );
}
