import { picker, fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';

const base64Helper: util.Base64Helper = new util.Base64Helper();

/**
 * 导出保存：网页用 Blob 生成 .xls/.json，转 base64 交给原生写入用户文件。
 * 使用 DocumentViewPicker.save() 拉起系统保存界面，无需申请存储权限。
 */
export class FileSaver {
  static async saveFile(
    name: string,
    mime: string,
    base64: string,
    context: common.UIAbilityContext,
    onToast: (msg: string) => void
  ): Promise<void> {
    const safeName = FileSaver.sanitizeName(name);
    try {
      const bytes = base64Helper.decodeSync(base64);
      const documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.newFileNames = [safeName];
      const documentViewPicker = new picker.DocumentViewPicker(context);
      const uris: string[] = await documentViewPicker.save(documentSaveOptions);
      if (uris.length === 0) {
        onToast('已取消保存');
        return;
      }
      const uri = uris[0];
      const file = fileIo.openSync(uri, fileIo.OpenMode.READ_WRITE);
      fileIo.writeSync(file.fd, bytes);
      fileIo.closeSync(file);
      onToast('已保存到「下载/印刷系统导出/' + safeName + '」');
    } catch (e) {
      const err = e as BusinessError;
      console.error('PrintClient saveFile failed: ' + err.code + ' ' + err.message);
      onToast('保存失败：' + (err.message || '未知错误'));
    }
  }

  static sanitizeName(name: string): string {
    const n = name.trim();
    if (n.length === 0) return '导出文件';
    return n.replace(/[\\/:*?"<>|]/g, '_');
  }
}
