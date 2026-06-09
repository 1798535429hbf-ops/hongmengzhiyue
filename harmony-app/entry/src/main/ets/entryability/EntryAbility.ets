import { UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { applyWindowSplashMode } from '../common/WindowMode';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want): void {
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    const mainWindow: window.Window = windowStage.getMainWindowSync();
    await applyWindowSplashMode(mainWindow, true);
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        console.error(`Load content failed: ${JSON.stringify(err)}`);
      }
    });
  }
}
