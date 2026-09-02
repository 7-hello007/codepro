// entry/src/main/ets/services/StatusBarManager.ets
import wifiManager from '@ohos.wifiManager';
import { BusinessError } from '@kit.BasicServicesKit';

export interface StatusBarInfo {
  line: number;
  column: number;
  fileType: string;
  encoding: string;
  filePath: string;
  lineEnding: string;
  currentTime: string;
  lastModified: string;
  wifiName: string;
  wifiStatus: number; // 0=强,1=中,2=弱/无
}

export class StatusBarManager {
  private info: StatusBarInfo = {
    line: 1,
    column: 1,
    fileType: '',
    encoding: 'UTF-8',
    filePath: '',
    lineEnding: 'LF',
    currentTime: '',
    lastModified: '',
    wifiName: 'WiFi',
    wifiStatus: 2
  };

  private timerId: number = -1;          // 时间定时器（1秒）
  private wifiTimerId: number = -1;      // WiFi定时器（30秒）

  onStatusChanged?: (info: StatusBarInfo) => void;

  startTimer(): void {
    this.updateTime();
    this.updateWifi();

    // 时间每秒更新一次（显示秒）
    this.timerId = setInterval(() => {
      this.updateTime();
    }, 1000);

    // WiFi 每30秒更新一次
    this.wifiTimerId = setInterval(() => {
      this.updateWifi();
    }, 30000);

    console.info('[StatusBar] 定时器已启动');
  }

  stopTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    if (this.wifiTimerId !== -1) {
      clearInterval(this.wifiTimerId);
      this.wifiTimerId = -1;
    }
    console.info('[StatusBar] 定时器已停止');
  }

  updateCursor(line: number, col: number): void {
    this.info.line = line;
    this.info.column = col;
    this.notify();
  }

  setFileInfo(fileType: string, filePath: string, lastModified: string): void {
    this.info.fileType = fileType;
    this.info.filePath = filePath;
    this.info.lastModified = lastModified;
    this.notify();
  }

  setLastModified(time: string): void {
    this.info.lastModified = time;
    this.notify();
  }

  private updateTime(): void {
    const now = new Date();
    const hh = String(now.getHours()).padStart(2, '0');
    const mm = String(now.getMinutes()).padStart(2, '0');
    const ss = String(now.getSeconds()).padStart(2, '0');
    this.info.currentTime = `${hh}:${mm}:${ss}`;
    this.notify();
  }

  private updateWifi(): void {
    try {
      wifiManager.getLinkedInfo().then((info: wifiManager.WifiLinkedInfo) => {
        if (!info) {
          this.info.wifiName = '无WiFi';
          this.info.wifiStatus = 2;
          this.notify();
          console.info('[StatusBar] WiFi: 无连接');
          return;
        }
        this.info.wifiName = info.ssid || 'WiFi';
        const rssi = info.rssi ?? -100;
        if (rssi > -50) this.info.wifiStatus = 0;
        else if (rssi > -70) this.info.wifiStatus = 1;
        else this.info.wifiStatus = 2;
        this.notify();
        console.info(`[StatusBar] WiFi: ${this.info.wifiName}, RSSI=${rssi}`);
      }).catch((err: BusinessError) => {
        console.error('[StatusBar] WiFi 获取失败:', err.message);
        this.info.wifiName = '无WiFi';
        this.info.wifiStatus = 2;
        this.notify();
      });
    } catch (e) {
      console.error('[StatusBar] WiFi 异常:', e);
      this.info.wifiName = '无WiFi';
      this.info.wifiStatus = 2;
      this.notify();
    }
  }

  getInfo(): StatusBarInfo {
    return {
      line: this.info.line,
      column: this.info.column,
      fileType: this.info.fileType,
      encoding: this.info.encoding,
      filePath: this.info.filePath,
      lineEnding: this.info.lineEnding,
      currentTime: this.info.currentTime,
      lastModified: this.info.lastModified,
      wifiName: this.info.wifiName,
      wifiStatus: this.info.wifiStatus
    };
  }

  private notify(): void {
    if (this.onStatusChanged) {
      this.onStatusChanged(this.getInfo());
    }
  }
}