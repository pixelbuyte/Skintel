import { Capacitor } from '@capacitor/core';

export function isNative(): boolean {
  return Capacitor.isNativePlatform();
}

export function platform(): 'ios' | 'android' | 'web' {
  return Capacitor.getPlatform() as 'ios' | 'android' | 'web';
}

export async function setupNativeShell(): Promise<void> {
  if (!isNative()) return;
  try {
    const { StatusBar, Style } = await import('@capacitor/status-bar');
    await StatusBar.setStyle({ style: Style.Light });
    if (platform() === 'android') {
      await StatusBar.setBackgroundColor({ color: '#FFFEFA' });
    }
  } catch {}
  try {
    const { SplashScreen } = await import('@capacitor/splash-screen');
    await SplashScreen.hide({ fadeOutDuration: 300 });
  } catch {}
  try {
    const { App } = await import('@capacitor/app');
    App.addListener('backButton', ({ canGoBack }) => {
      if (canGoBack) window.history.back();
      else App.exitApp();
    });
  } catch {}
}

export async function haptic(style: 'light' | 'medium' | 'heavy' = 'light'): Promise<void> {
  if (!isNative()) return;
  try {
    const { Haptics, ImpactStyle } = await import('@capacitor/haptics');
    const map = {
      light: ImpactStyle.Light,
      medium: ImpactStyle.Medium,
      heavy: ImpactStyle.Heavy,
    } as const;
    await Haptics.impact({ style: map[style] });
  } catch {}
}

export async function takePhoto(): Promise<string | null> {
  if (!isNative()) return null;
  try {
    const { Camera, CameraResultType, CameraSource } = await import('@capacitor/camera');
    const photo = await Camera.getPhoto({
      quality: 80,
      allowEditing: false,
      resultType: CameraResultType.DataUrl,
      source: CameraSource.Camera,
    });
    return photo.dataUrl ?? null;
  } catch {
    return null;
  }
}

export async function pickPhoto(): Promise<string | null> {
  if (!isNative()) return null;
  try {
    const { Camera, CameraResultType, CameraSource } = await import('@capacitor/camera');
    const photo = await Camera.getPhoto({
      quality: 80,
      allowEditing: false,
      resultType: CameraResultType.DataUrl,
      source: CameraSource.Photos,
    });
    return photo.dataUrl ?? null;
  } catch {
    return null;
  }
}

export const nativeStorage = {
  async get(key: string): Promise<string | null> {
    if (!isNative()) {
      try {
        return window.localStorage.getItem(key);
      } catch {
        return null;
      }
    }
    try {
      const { Preferences } = await import('@capacitor/preferences');
      const { value } = await Preferences.get({ key });
      return value;
    } catch {
      return null;
    }
  },
  async set(key: string, value: string): Promise<void> {
    if (!isNative()) {
      try {
        window.localStorage.setItem(key, value);
      } catch {}
      return;
    }
    try {
      const { Preferences } = await import('@capacitor/preferences');
      await Preferences.set({ key, value });
    } catch {}
  },
  async remove(key: string): Promise<void> {
    if (!isNative()) {
      try {
        window.localStorage.removeItem(key);
      } catch {}
      return;
    }
    try {
      const { Preferences } = await import('@capacitor/preferences');
      await Preferences.remove({ key });
    } catch {}
  },
};
