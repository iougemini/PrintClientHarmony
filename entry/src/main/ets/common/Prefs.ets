import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const SP_NAME: string = 'settings';
const KEY_SERVER: string = 'server_url';
export const DEFAULT_PORT: number = 8090;

/**
 * 只存一个东西：服务端地址。
 * 其它业务数据全在服务端 SQLite 里，客户端不做任何本地存储。
 */
export class Prefs {
  static async server(ctx: common.Context): Promise<string | null> {
    try {
      const sp = await preferences.getPreferences(ctx, SP_NAME);
      const v = await sp.get(KEY_SERVER, '');
      const s = (v as string).trim();
      return s.length > 0 ? s : null;
    } catch (e) {
      return null;
    }
  }

  static async hasServer(ctx: common.Context): Promise<boolean> {
    return (await Prefs.server(ctx)) !== null;
  }

  static async saveServer(ctx: common.Context, raw: string): Promise<void> {
    const url = Prefs.normalize(raw);
    if (url === null) return;
    const sp = await preferences.getPreferences(ctx, SP_NAME);
    await sp.put(KEY_SERVER, url);
    await sp.flush();
  }

  /**
   * 把用户随手输的内容规整成可用地址：
   *  192.168.1.50            -> http://192.168.1.50:8090
   *  192.168.1.50:8090       -> http://192.168.1.50:8090
   *  http://192.168.1.50/    -> http://192.168.1.50:8090
   *  http://192.168.1.50:8090/#orders -> http://192.168.1.50:8090
   */
  static normalize(raw: string): string | null {
    let s = raw.trim();
    if (s.length === 0) return null;
    s = s.replace(/：/g, ':').replace(/／/g, '/');
    const hashIdx = s.indexOf('#');
    if (hashIdx >= 0) s = s.substring(0, hashIdx);
    const qIdx = s.indexOf('?');
    if (qIdx >= 0) s = s.substring(0, qIdx);
    if (!/^https?:\/\//i.test(s)) s = 'http://' + s;
    const m = /^([a-zA-Z]+):\/\/([^\/:?#]+)(?::(\d+))?(\/[^?#]*)?$/.exec(s);
    if (m === null) return null;
    const scheme = m[1].toLowerCase();
    const host = m[2];
    if (host.length === 0) return null;
    const portStr = m.length > 3 ? m[3] : '';
    const port = portStr.length > 0 ? parseInt(portStr, 10) : DEFAULT_PORT;
    if (!Number.isFinite(port) || port <= 0 || port > 65535) return null;
    const path = (m.length > 4 ? m[4] : '').replace(/\/+$/, '');
    return scheme + '://' + host + ':' + String(port) + path;
  }
}
