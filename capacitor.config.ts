import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.skintel.app',
  appName: 'Skintel',
  webDir: 'dist',
  bundledWebRuntime: false,
  ios: {
    contentInset: 'always',
    backgroundColor: '#FFFEFA',
    limitsNavigationsToAppBoundDomains: false,
    preferredContentMode: 'mobile',
  },
  server: {
    androidScheme: 'https',
    iosScheme: 'https',
    cleartext: false,
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 1500,
      launchAutoHide: true,
      backgroundColor: '#FFFEFA',
      androidSplashResourceName: 'splash',
      androidScaleType: 'CENTER_CROP',
      showSpinner: false,
      splashFullScreen: true,
      splashImmersive: true,
      iosSpinnerStyle: 'small',
      spinnerColor: '#A35848',
    },
    StatusBar: {
      style: 'LIGHT',
      backgroundColor: '#FFFEFA',
      overlaysWebView: false,
    },
    Camera: {
      ios: {
        usageDescription: 'Skintel uses the camera to scan product barcodes and capture ingredient labels.',
      },
    },
    Preferences: {
      group: 'SkintelPrefs',
    },
  },
};

export default config;
