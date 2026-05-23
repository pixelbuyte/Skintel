import { useState } from 'react';
import { Plus } from 'lucide-react';
import { AddProductSheet } from './AddProductSheet';
import { haptic } from '@/lib/haptics';

export function AddProductFab() {
  const [open, setOpen] = useState(false);

  return (
    <>
      <button
        type="button"
        onClick={() => {
          haptic.tap();
          setOpen(true);
        }}
        aria-label="Add product"
        className="md:hidden fixed right-4 z-40 w-14 h-14 rounded-full bg-primary text-white shadow-sheet flex items-center justify-center active:scale-90 transition-transform duration-200 ease-ios"
        style={{ bottom: 'calc(env(safe-area-inset-bottom) + 5rem)' }}
      >
        <Plus size={26} strokeWidth={2.4} />
      </button>
      <AddProductSheet open={open} onOpenChange={setOpen} />
    </>
  );
}
