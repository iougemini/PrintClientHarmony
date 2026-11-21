import { webview } from '@kit.ArkWeb';
import { print } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

function delay(ms: number): Promise<void> {
  return new Promise<void>((resolve: (value: void) => void) => {
    setTimeout(() => { resolve(); }, ms);
  });
}

/**
 * 打印：把网页切到「只显示单据」的白底版式，再交给系统打印。
 * createWebPrintDocumentAdapter / print.print 为 API 11+ 能力；
 * 低版本系统（鸿蒙 4）调用会抛异常，由调用方降级提示。
 */
export class PrintManager {
  static async printPage(
    controller: webview.WebviewController,
    context: common.Context,
    onUnsupported: () => void,
    onDone: () => void
  ): Promise<void> {
    try {
      // 先切到打印版式（复刻安卓的 .printing 类逻辑）
      await controller.runJavaScript("document.documentElement.classList.add('printing')");
      await delay(400);
      const adapter = controller.createWebPrintDocumentAdapter('瑜华印务管理系统');
      print.print('瑜华印务管理系统-单据', adapter, null, context);
      // 打印对话框已拉起，等页面恢复后再移除版式
      await delay(2000);
      await controller.runJavaScript("document.documentElement.classList.remove('printing')");
      onDone();
    } catch (e) {
      const err = e as BusinessError;
      console.error('PrintClient print failed: ' + err.code + ' ' + err.message);
      try {
        await controller.runJavaScript("document.documentElement.classList.remove('printing')");
      } catch (e2) {
        // 忽略
      }
      onUnsupported();
      onDone();
    }
  }
}
