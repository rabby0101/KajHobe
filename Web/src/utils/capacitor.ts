
import { Capacitor } from '@capacitor/core';

export const initializeCapacitor = async () => {
  if (Capacitor.isNativePlatform()) {
    try {
      // Dynamically import status bar only on native platforms
      const { StatusBar, Style } = await import('@capacitor/status-bar');
      await StatusBar.setStyle({ style: Style.Default });
    } catch (error) {
      console.log('StatusBar plugin not available:', error);
    }

    try {
      // Dynamically import splash screen only on native platforms
      const { SplashScreen } = await import('@capacitor/splash-screen');
      await SplashScreen.hide();
    } catch (error) {
      console.log('SplashScreen plugin not available:', error);
    }
  }
};

export const isNative = () => Capacitor.isNativePlatform();
export const getPlatform = () => Capacitor.getPlatform();
