/**
 * 网页侧通过 window.PrintBridge 调用，方法签名不可随意改（见 rawfile/shim.js）。
 * 由 Index 页面注入真实实现；这里只做桥接与转发。
 */
export class PrintBridge {
  private printHandler: () => void = () => {};
  private saveHandler: (name: string, mime: string, base64: string) => void = () => {};
  private toastHandler: (msg: string) => void = () => {};
  private settingsHandler: () => void = () => {};
  private serverUrlHandler: () => string = () => '';

  setHandlers(
    p: () => void,
    s: (name: string, mime: string, base64: string) => void,
    t: (msg: string) => void,
    se: () => void,
    su: () => string
  ): void {
    this.printHandler = p;
    this.saveHandler = s;
    this.toastHandler = t;
    this.settingsHandler = se;
    this.serverUrlHandler = su;
  }

  printPage(): void {
    this.printHandler();
  }

  saveFile(name: string, mime: string, base64: string): void {
    this.saveHandler(name, mime, base64);
  }

  toast(msg: string): void {
    this.toastHandler(msg);
  }

  openSettings(): void {
    this.settingsHandler();
  }

  serverUrl(): string {
    return this.serverUrlHandler();
  }
}
