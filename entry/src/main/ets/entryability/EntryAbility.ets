import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Prefs } from '../common/Prefs';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'PrintClient', 'EntryAbility onCreate');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.loadPage(windowStage);
  }

  /**
   * 按是否已配置内网地址决定首屏：
   * 有地址 → 直接进主界面；无地址 → 先进服务器设置页。
   */
  private async loadPage(windowStage: window.WindowStage): Promise<void> {
    let page = 'pages/SetupPage';
    try {
      const has = await Prefs.hasServer(this.context);
      if (has) page = 'pages/Index';
    } catch (e) {
      hilog.error(0x0000, 'PrintClient', 'read prefs failed: %{public}s', JSON.stringify(e));
    }
    windowStage.loadContent(page, (err) => {
      if (err.code) {
        hilog.error(0x0000, 'PrintClient', 'loadContent failed: %{public}s', JSON.stringify(err));
        return;
      }
    });
  }

  onWindowStageDestroy(): void {
  }

  onForeground(): void {
  }

  onBackground(): void {
  }
}
