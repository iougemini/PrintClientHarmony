import { webview } from '@kit.ArkWeb';
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { buffer } from '@kit.ArkTS';
import { picker } from '@kit.CoreFileKit';
import { Prefs } from '../common/Prefs';
import { PrintBridge } from '../common/Bridge';
import { PrintManager } from '../common/PrintManager';
import { FileSaver } from '../common/FileSaver';

/**
 * 外壳主界面：一个 Web 组件加载内网地址，外加 4 件原生能力
 *   1. 打印（网页里的 window.print 由注入脚本转到系统打印）
 *   2. 导出下载（网页用 Blob 生成 .xls/.json，转 base64 交给原生写入用户文件）
 *   3. 选文件（稿件选择框 input[type=file]）
 *   4. 断线兜底页 + 返回键逻辑
 *
 * 业务逻辑、权限、数据全在服务端，这里不做任何缓存或本地库。
 */
@Entry
@Component
struct Index {
  private controller: webview.WebviewController = new webview.WebviewController();
  private bridge: PrintBridge = new PrintBridge();

  @State serverUrl: string = '';
  @State progressVisible: boolean = false;
  @State errorVisible: boolean = false;
  @State errMsg: string = '';

  private printing: boolean = false;
  private lastBackAt: number = 0;

  aboutToAppear(): void {
    this.bridge.setHandlers(
      () => { this.startPrint(); },
      (name: string, mime: string, base64: string) => { this.saveFile(name, mime, base64); },
      (msg: string) => { this.toast(msg); },
      () => { this.openSettings(); },
      () => { return this.serverUrl; }
    );
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Web({ src: 'about:blank', controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .databaseAccess(true)
        .mixedMode(MixedMode.All)
        .zoomAccess(false)
        .cacheMode(CacheMode.Default)
        .onPageBegin(() => {
          this.progressVisible = true;
        })
        .onPageEnd(() => {
          this.progressVisible = false;
          this.errorVisible = false;
          this.injectShim();
        })
        .onErrorReceive((event) => {
          if (event.request.isMainFrame()) {
            this.progressVisible = false;
            this.errMsg = this.serverUrl + '\n' + (event.error.getErrorInfo() || '网络错误');
            this.errorVisible = true;
          }
        })
        .onShowFileSelector((event) => {
          this.handleFileSelector(event);
          return true;
        })
        .onControllerAttached(() => {
          this.initAndLoad();
        })
        .javaScriptProxy({
          object: this.bridge,
          name: 'PrintBridge',
          methodList: ['printPage', 'saveFile', 'toast', 'openSettings', 'serverUrl'],
          controller: this.controller
        })
        .width('100%')
        .height('100%')

      if (this.progressVisible) {
        Row()
          .width('100%')
          .height(3)
          .backgroundColor($r('app.color.brand'))
      }

      if (this.errorVisible) {
        this.ErrorPanel()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.paper'))
  }

  @Builder
  ErrorPanel() {
    Column() {
      Image($r('app.media.app_icon'))
        .width(72)
        .height(72)
        .margin({ bottom: 16 })
      Text($r('app.string.err_title'))
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      Text(this.errMsg)
        .fontSize(13)
        .fontColor($r('app.color.text_2'))
        .margin({ top: 10 })
        .textAlign(TextAlign.Center)
        .width('100%')
      Text($r('app.string.err_hint'))
        .fontSize(13)
        .fontColor($r('app.color.text_2'))
        .margin({ top: 14 })
        .width('100%')
        .lineHeight(22)
      Row() {
        Button($r('app.string.err_retry'))
          .layoutWeight(1)
          .onClick(() => {
            this.errorVisible = false;
            this.loadServer();
          })
        Button($r('app.string.err_change'))
          .layoutWeight(1)
          .margin({ left: 12 })
          .onClick(() => {
            this.openSettings();
          })
      }
      .width('100%')
      .margin({ top: 22 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 28, right: 28 })
    .justifyContent(FlexAlign.Center)
  }

  /* ------------------------------------------------------------------ 加载 */

  private async initAndLoad(): Promise<void> {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const saved = await Prefs.server(ctx);
    if (saved === null) {
      router.replaceUrl({ url: 'pages/SetupPage' });
      return;
    }
    this.serverUrl = saved;
    this.controller.loadUrl(saved);
  }

  private loadServer(): void {
    if (this.serverUrl.length === 0) return;
    this.errorVisible = false;
    this.controller.loadUrl(this.serverUrl);
  }

  /** 注入打印/下载桥接与少量移动端样式；失败不影响主流程。 */
  private async injectShim(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const data = await ctx.resourceManager.getRawFileContent('shim.js');
      const js = buffer.from(data).toString('utf8');
      await this.controller.runJavaScript(js);
    } catch (e) {
      console.error('PrintClient inject shim failed: ' + JSON.stringify(e));
    }
  }

  /* ------------------------------------------------------------------ 返回键 */

  onBackPress(): boolean {
    if (this.controller.accessBackward()) {
      this.controller.backward();
      return true;
    }
    const now = Date.now();
    if (now - this.lastBackAt < 2000) {
      return false;
    }
    this.lastBackAt = now;
    this.toast(this.getString($r('app.string.exit_hint')));
    return true;
  }

  /* ------------------------------------------------------------------ 打印 */

  private startPrint(): void {
    if (this.printing) {
      this.toast(this.getString($r('app.string.print_busy')));
      return;
    }
    this.printing = true;
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    PrintManager.printPage(this.controller, ctx, () => {
      this.printing = false;
      this.toast(this.getString($r('app.string.print_unsupported')));
    }, () => {
      this.printing = false;
    });
  }

  /* ------------------------------------------------------------------ 导出保存 */

  private saveFile(name: string, mime: string, base64: string): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    FileSaver.saveFile(name, mime, base64, ctx, (msg: string) => { this.toast(msg); });
  }

  /* ------------------------------------------------------------------ 选文件 */

  private handleFileSelector(event: OnShowFileSelectorEvent): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const documentSelectOptions = new picker.DocumentSelectOptions();
    const documentViewPicker = new picker.DocumentViewPicker(ctx);
    documentViewPicker.select(documentSelectOptions).then((uris: string[]) => {
      if (uris.length > 0) {
        event.result.handleFileList(uris);
      }
    }).catch((err: BusinessError) => {
      console.error('PrintClient select file failed: ' + err.code + ' ' + err.message);
    });
  }

  /* ------------------------------------------------------------------ 权限与工具 */

  private openSettings(): void {
    router.pushUrl({ url: 'pages/SetupPage' });
  }

  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
  }

  private getString(res: Resource): string {
    const ctx = this.getUIContext().getHostContext();
    if (ctx === undefined || ctx === null) return '';
    return ctx.resourceManager.getStringSync(res.id);
  }
}
