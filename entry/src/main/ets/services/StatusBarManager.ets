// entry/src/main/ets/services/StatusBarManager.ets
import wifiManager from '@ohos.wifiManager';

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

/**
 * 状态栏管理器（负责时间和WiFi更新）
 */
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

  private timerId: number = -1;

  onStatusChanged?: (info: StatusBarInfo) => void;

  startTimer(): void {
    this.updateTime();
    this.updateWifi();
    this.timerId = setInterval(() => {
      this.updateTime();
    }, 60000);
  }

  stopTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
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
    this.info.currentTime =
      String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
    this.notify();
  }

  private updateWifi(): void {
    try {
      wifiManager.getLinkedInfo().then((info: wifiManager.WifiLinkedInfo) => {
        if (!info) {
          this.info.wifiName = '无WiFi';
          this.info.wifiStatus = 2;
          this.notify();
          return;
        }
        this.info.wifiName = info.ssid || 'WiFi';
        const rssi = info.rssi ?? -100;
        if (rssi > -50) this.info.wifiStatus = 0;
        else if (rssi > -70) this.info.wifiStatus = 1;
        else this.info.wifiStatus = 2;
        this.notify();
      }).catch(() => {
        this.info.wifiName = '无WiFi';
        this.info.wifiStatus = 2;
        this.notify();
      });
    } catch (e) {
      this.info.wifiName = '无WiFi';
      this.info.wifiStatus = 2;
      this.notify();
    }
  }

  getInfo(): StatusBarInfo {
    // 显式构造新对象，避免对象展开
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