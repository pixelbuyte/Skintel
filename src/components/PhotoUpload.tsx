import { useCallback, useRef, useState } from 'react';
import { Camera, Upload, Loader2 } from 'lucide-react';
import { supabase } from '@/lib/supabase';

type ExtractedData = {
  brand?: string | null;
  productName?: string | null;
  ingredients: string;
};

type Props = {
  onExtracted: (data: ExtractedData) => void;
};

type ApiResponse = {
  result?: {
    brand?: string | null;
    productName?: string | null;
    ingredients?: string;
  };
  error?: string;
};

const ALLOWED_MIME = ['image/jpeg', 'image/png', 'image/webp'] as const;
type AllowedMime = (typeof ALLOWED_MIME)[number];

function isAllowedMime(value: string): value is AllowedMime {
  return (ALLOWED_MIME as readonly string[]).includes(value);
}

async function fileToBase64(file: File): Promise<{ base64: string; mimeType: AllowedMime }> {
  if (!isAllowedMime(file.type)) {
    throw new Error('Only JPEG, PNG, or WEBP images are supported.');
  }
  const bitmap = await createImageBitmap(file);
  const MAX = 1600;
  const scale = Math.min(1, MAX / Math.max(bitmap.width, bitmap.height));
  const w = Math.round(bitmap.width * scale);
  const h = Math.round(bitmap.height * scale);
  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('Canvas unsupported');
  ctx.drawImage(bitmap, 0, 0, w, h);
  const blob: Blob = await new Promise((resolve, reject) =>
    canvas.toBlob((b) => (b ? resolve(b) : reject(new Error('Encode failed'))), 'image/jpeg', 0.85)
  );
  const buf = await blob.arrayBuffer();
  const bytes = new Uint8Array(buf);
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return { base64: btoa(bin), mimeType: 'image/jpeg' };
}

export default function PhotoUpload({ onExtracted }: Props) {
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  const handleFile = useCallback((next: File | null) => {
    setError(null);
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    if (!next) {
      setFile(null);
      setPreviewUrl(null);
      return;
    }
    if (!isAllowedMime(next.type)) {
      setError('Only JPEG, PNG, or WEBP images are supported.');
      setFile(null);
      setPreviewUrl(null);
      return;
    }
    setFile(next);
    setPreviewUrl(URL.createObjectURL(next));
  }, [previewUrl]);

  const onInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    handleFile(e.target.files?.[0] ?? null);
  };

  const onDrop = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setIsDragging(false);
    const dropped = e.dataTransfer.files?.[0] ?? null;
    handleFile(dropped);
  };

  const onDragOver = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const onDragLeave = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setIsDragging(false);
  };

  const extract = async () => {
    if (!file) return;
    setLoading(true);
    setError(null);
    try {
      const { base64, mimeType } = await fileToBase64(file);

      const { data: sessionData } = await supabase.auth.getSession();
      const token = sessionData.session?.access_token;
      if (!token) throw new Error('You must be signed in.');

      const resp = await fetch('/api/scan-photo', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ imageBase64: base64, mimeType }),
      });

      const payload: ApiResponse = await resp.json().catch(() => ({}));
      if (!resp.ok) {
        throw new Error(payload?.error ?? `Request failed (${resp.status})`);
      }
      const result = payload.result;
      if (!result) throw new Error('No result returned.');

      onExtracted({
        brand: result.brand ?? null,
        productName: result.productName ?? null,
        ingredients: result.ingredients ?? '',
      });
    } catch (e: any) {
      setError(String(e?.message ?? e));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="card p-5 space-y-4">
      <div>
        <label className="label">Scan back of bottle</label>
        <p className="text-sm text-muted mt-1">
          Snap or upload a photo of the ingredient list. Claude will OCR the brand, product name, and INCI.
        </p>
      </div>

      <div
        onDrop={onDrop}
        onDragOver={onDragOver}
        onDragLeave={onDragLeave}
        className={`relative rounded-xl border-2 border-dashed transition-colors p-6 text-center cursor-pointer ${
          isDragging ? 'border-primary bg-primary/5' : 'border-gray-300 hover:border-primary/60'
        }`}
        onClick={() => inputRef.current?.click()}
      >
        <input
          ref={inputRef}
          type="file"
          accept="image/*"
          capture="environment"
          onChange={onInputChange}
          className="hidden"
        />

        {previewUrl ? (
          <div className="flex flex-col items-center gap-3">
            <img
              src={previewUrl}
              alt="Selected ingredient label"
              className="max-h-56 rounded-lg object-contain"
            />
            <p className="text-xs text-muted truncate max-w-full">{file?.name}</p>
          </div>
        ) : (
          <div className="flex flex-col items-center gap-2 text-muted">
            <div className="flex gap-3">
              <Camera size={28} />
              <Upload size={28} />
            </div>
            <p className="text-sm">Tap to take a photo or drop an image here</p>
            <p className="text-xs">JPEG, PNG, or WEBP up to ~6MB</p>
          </div>
        )}
      </div>

      {error && (
        <div className="text-sm bad-text bg-bad-bg rounded-lg px-3 py-2">{error}</div>
      )}

      <div className="flex gap-2 justify-end">
        {file && (
          <button
            type="button"
            className="btn-ghost"
            onClick={() => handleFile(null)}
            disabled={loading}
          >
            Clear
          </button>
        )}
        <button
          type="button"
          className="btn-primary inline-flex items-center gap-2"
          onClick={extract}
          disabled={!file || loading}
        >
          {loading ? <Loader2 size={16} className="animate-spin" /> : <Upload size={16} />}
          {loading ? 'Extracting...' : 'Extract ingredients'}
        </button>
      </div>
    </div>
  );
}
