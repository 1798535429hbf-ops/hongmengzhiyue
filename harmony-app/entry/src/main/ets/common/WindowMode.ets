import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

const SPLASH_BAR_COLOR: string = '#00000000';
const APP_STATUS_BAR_COLOR: string = '#FBFBFD';
const APP_NAVIGATION_BAR_COLOR: string = '#FFFFFF';
const LIGHT_BAR_CONTENT: string = '#FFFFFF';
const DARK_BAR_CONTENT: string = '#20233A';

export async function applyWindowSplashMode(appWindow: window.Window, enabled: boolean): Promise<void> {
  try {
    await appWindow.setWindowLayoutFullScreen(enabled);
    await appWindow.setWindowSystemBarProperties({
      statusBarColor: enabled ? SPLASH_BAR_COLOR : APP_STATUS_BAR_COLOR,
      navigationBarColor: enabled ? SPLASH_BAR_COLOR : APP_NAVIGATION_BAR_COLOR,
      statusBarContentColor: enabled ? LIGHT_BAR_CONTENT : DARK_BAR_CONTENT,
      navigationBarContentColor: enabled ? LIGHT_BAR_CONTENT : DARK_BAR_CONTENT,
      isStatusBarLightIcon: enabled,
      isNavigationBarLightIcon: enabled,
    });
  } catch (err) {
    console.error(`Update window splash mode failed: ${JSON.stringify(err)}`);
  }
}

export async function setCurrentWindowSplashMode(context: common.UIAbilityContext, enabled: boolean): Promise<void> {
  try {
    const appWindow: window.Window = await window.getLastWindow(context);
    await applyWindowSplashMode(appWindow, enabled);
  } catch (err) {
    console.error(`Get current window failed: ${JSON.stringify(err)}`);
  }
}
