import { useRef, useState } from 'react';
import { Images, Upload, X, Loader2 } from 'lucide-react';
import { supabase } from '@/lib/supabase';

type ExtractedProduct = {
  brand?: string | null;
  productName?: string | null;
  ingredients: string;
};

type Props = {
  onBatchExtracted: (products: ExtractedProduct[]) => void;
};

type Selected = {
  file: File;
  previewUrl: string;
};

const MAX_FILES = 5;

function fileToBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result as string;
      const comma = result.indexOf(',');
      resolve(comma >= 0 ? result.slice(comma + 1) : result);
    };
    reader.onerror = () => reject(reader.error ?? new Error('Failed to read file'));
    reader.readAsDataURL(file);
  });
}

export default function BulkPhotoUpload({ onBatchExtracted }: Props) {
  const [files, setFiles] = useState<Selected[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement | null>(null);

  function handleFiles(list: FileList | null) {
    if (!list || list.length === 0) return;
    setError(null);
    const incoming = Array.from(list).filter((f) => f.type.startsWith('image/'));
    const room = Math.max(0, MAX_FILES - files.length);
    const accepted = incoming.slice(0, room);
    if (incoming.length > accepted.length) {
      setError(`Max ${MAX_FILES} images per batch`);
    }
    const mapped: Selected[] = accepted.map((file) => ({
      file,
      previewUrl: URL.createObjectURL(file),
    }));
    setFiles((prev) => [...prev, ...mapped]);
  }

  function removeFile(index: number) {
    setFiles((prev) => {
      const next = [...prev];
      const [removed] = next.splice(index, 1);
      if (removed) URL.revokeObjectURL(removed.previewUrl);
      return next;
    });
  }

  async function handleExtract() {
    if (files.length === 0) return;
    setLoading(true);
    setError(null);
    try {
      const images = await Promise.all(
        files.map(async (f) => ({
          imageBase64: await fileToBase64(f.file),
          mimeType: f.file.type,
        })),
      );

      const { data: sessionData } = await supabase.auth.getSession();
      const token = sessionData.session?.access_token;
      if (!token) throw new Error('You must be signed in');

      const resp = await fetch('/api/scan-photo-bulk', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ images }),
      });

      const data = (await resp.json()) as {
        products?: ExtractedProduct[];
        error?: string;
      };

      if (!resp.ok) {
        throw new Error(data?.error ?? `Request failed (${resp.status})`);
      }

      const products = Array.isArray(data.products) ? data.products : [];
      if (products.length === 0) {
        setError('No ingredient lists detected. Try clearer photos of the back labels.');
        return;
      }

      onBatchExtracted(products);
      // Clear selection after success
      files.forEach((f) => URL.revokeObjectURL(f.previewUrl));
      setFiles([]);
      if (inputRef.current) inputRef.current.value = '';
    } catch (e: any) {
      setError(String(e?.message ?? e));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="card space-y-4">
      <div className="flex items-center gap-2">
        <Images className="h-5 w-5 text-muted-foreground" />
        <div>
          <div className="font-medium">Bulk photo scan</div>
          <div className="text-sm text-muted-foreground">
            Upload up to {MAX_FILES} photos (or one routine layout) to extract every product at once.
          </div>
        </div>
      </div>

      <div>
        <label className="label" htmlFor="bulk-photo-input">
          Photos
        </label>
        <input
          id="bulk-photo-input"
          ref={inputRef}
          className="input"
          type="file"
          accept="image/*"
          multiple
          disabled={loading || files.length >= MAX_FILES}
          onChange={(e) => handleFiles(e.target.files)}
        />
      </div>

      {files.length > 0 && (
        <div className="grid grid-cols-3 gap-3 sm:grid-cols-4 md:grid-cols-5">
          {files.map((f, i) => (
            <div
              key={`${f.file.name}-${i}`}
              className="group relative overflow-hidden rounded-lg border border-border bg-muted"
            >
              <img
                src={f.previewUrl}
                alt={f.file.name}
                className="aspect-square w-full object-cover"
              />
              <button
                type="button"
                onClick={() => removeFile(i)}
                disabled={loading}
                className="absolute right-1 top-1 rounded-full bg-background/90 p-1 text-foreground shadow hover:bg-background disabled:opacity-50"
                aria-label={`Remove ${f.file.name}`}
              >
                <X className="h-3.5 w-3.5" />
              </button>
            </div>
          ))}
        </div>
      )}

      {error && (
        <div className="rounded-md border border-destructive/40 bg-destructive/10 px-3 py-2 text-sm text-destructive">
          {error}
        </div>
      )}

      <div className="flex flex-wrap gap-2">
        <button
          type="button"
          className="btn-primary"
          onClick={handleExtract}
          disabled={loading || files.length === 0}
        >
          {loading ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Extracting...
            </>
          ) : (
            <>
              <Upload className="mr-2 h-4 w-4" />
              Extract all
            </>
          )}
        </button>
        {files.length > 0 && (
          <button
            type="button"
            className="btn-ghost"
            onClick={() => {
              files.forEach((f) => URL.revokeObjectURL(f.previewUrl));
              setFiles([]);
              if (inputRef.current) inputRef.current.value = '';
            }}
            disabled={loading}
          >
            Clear
          </button>
        )}
      </div>
    </div>
  );
}
