import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { Prefs } from '../common/Prefs';

/**
 * 内网地址设置页。首次启动、连接失败、桌面图标长按快捷方式都会进入这里。
 * 点「测试并进入」会真的去 ping 一下 /api/session：能通（哪怕返回 401）就说明服务器活着。
 */
@Entry
@Component
struct SetupPage {
  @State serverInput: string = '';
  @State statusText: string = '';
  @State statusVisible: boolean = false;
  @State testing: boolean = false;
  @State inputError: string = '';

  aboutToAppear(): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    Prefs.server(ctx).then((saved) => {
      this.serverInput = saved ?? 'http://192.168.1.50:8090';
    });
  }

  build() {
    Scroll() {
      Column() {
        Image($r('app.media.app_icon'))
          .width(76)
          .height(76)
          .margin({ top: 48 })
        Text($r('app.string.setup_head'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .margin({ top: 18 })
        Text($r('app.string.setup_desc'))
          .fontSize(13)
          .fontColor($r('app.color.text_2'))
          .margin({ top: 8 })
          .lineHeight(20)
        TextInput({ text: this.serverInput, placeholder: $r('app.string.setup_label') })
          .type(InputType.Normal)
          .fontSize(16)
          .margin({ top: 26 })
          .onChange((v: string) => {
            this.serverInput = v;
          })
        if (this.inputError.length > 0) {
          Text(this.inputError)
            .fontSize(12)
            .fontColor($r('app.color.brand'))
            .margin({ top: 6 })
        }
        if (this.statusVisible) {
          Text(this.statusText)
            .fontSize(13)
            .fontColor($r('app.color.text_2'))
            .margin({ top: 10 })
        }
        Button($r('app.string.setup_test'))
          .width('100%')
          .height(52)
          .margin({ top: 18 })
          .enabled(!this.testing)
          .onClick(() => {
            this.testAndEnter();
          })
        Text($r('app.string.setup_tip'))
          .fontSize(12.5)
          .fontColor($r('app.color.ink'))
          .margin({ top: 26 })
          .padding(14)
          .backgroundColor($r('app.color.brand_light'))
          .width('100%')
          .lineHeight(20)
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.paper'))
  }

  private testAndEnter(): void {
    this.inputError = '';
    const normalized = Prefs.normalize(this.serverInput);
    if (normalized === null) {
      this.inputError = this.getString($r('app.string.err_bad_url'));
      return;
    }
    this.serverInput = normalized;
    this.testing = true;
    this.statusVisible = true;
    this.statusText = this.getString($r('app.string.setup_testing'));
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.probe(normalized).then((fail) => {
      this.testing = false;
      if (fail === null) {
        Prefs.saveServer(ctx, normalized);
        this.statusText = this.getString($r('app.string.setup_ok'));
        router.replaceUrl({ url: 'pages/Index' });
      } else {
        this.statusText = '连不上：' + fail;
        this.confirmEnterAnyway(normalized, fail);
      }
    });
  }

  /** 返回 null 表示可达；否则返回失败原因。 */
  private probe(base: string): Promise<string | null> {
    return new Promise<string | null>((resolve: (value: string | null) => void) => {
      const httpReq = http.createHttp();
      httpReq.request(base + '/api/session', {
        method: http.RequestMethod.GET,
        connectTimeout: 4000,
        readTimeout: 4000
      }).then((resp: http.HttpResponse) => {
        const code = resp.responseCode;
        // 401 说明服务器在跑、只是没登录，同样算「通」
        if (code >= 100 && code <= 599) {
          resolve(null);
        } else {
          resolve('HTTP ' + code);
        }
        httpReq.destroy();
      }).catch((e: BusinessError) => {
        const code = e.code;
        let reason: string;
        if (code === 2300006) {
          reason = this.getString($r('app.string.probe_timeout'));
        } else if (code === 2300007 || code === 2300027) {
          reason = this.getString($r('app.string.probe_refused'));
        } else {
          reason = this.getString($r('app.string.probe_unknown'));
        }
        resolve(reason);
        httpReq.destroy();
      });
    });
  }

  /** 探测失败时也允许进：万一是服务端临时忙，进去后错误页还能重试。 */
  private confirmEnterAnyway(url: string, reason: string): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.getUIContext().showAlertDialog({
      title: this.getString($r('app.string.err_title')),
      message: reason + '\n\n要让 App 直接打开这个地址吗？进去后仍可重试或改地址。',
      primaryButton: {
        value: '留在此页',
        action: () => { }
      },
      secondaryButton: {
        value: '仍然进入',
        action: () => {
          Prefs.saveServer(ctx, url);
          router.replaceUrl({ url: 'pages/Index' });
        }
      }
    });
  }

  private getString(res: Resource): string {
    const ctx = this.getUIContext().getHostContext();
    if (ctx === undefined || ctx === null) return '';
    return ctx.resourceManager.getStringSync(res.id);
  }
}
