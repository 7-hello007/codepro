// entry/src/main/ets/services/FileTreePollingService.ets
import { FileNode } from '../components/FileTree';
import { QemuFileSystem } from '../lib/QemuFileSystem';

/**
 * 文件树轮询服务
 * 职责：定期轮询当前目录，检测变化后通过回调通知 UI
 */
export class FileTreePollingService {
  private timerId: number = -1;
  private intervalMs: number = 3000;
  private qemuFs: QemuFileSystem | null = null;
  private currentPath: string = '/';
  private lastHash: string = '';
  private isRunning: boolean = false;

  // 回调：目录发生变化时触发
  onDirectoryChanged?: (nodes: FileNode[]) => void;
  // 回调：轮询出错时触发
  onError?: (err: Error) => void;

  /**
   * 绑定 QemuFileSystem 实例
   */
  bindFileSystem(qemuFs: QemuFileSystem): void {
    this.qemuFs = qemuFs;
  }

  /**
   * 设置轮询间隔（毫秒）
   */
  setInterval(ms: number): void {
    this.intervalMs = ms;
  }

  /**
   * 更新当前监听的路径
   */
  setCurrentPath(path: string): void {
    this.currentPath = path;
    // 路径变化时重新计算哈希，避免误触发
    if (this.qemuFs?.isReady()) {
      this.updateHash();
    }
  }

  /**
   * 启动轮询
   */
  start(): void {
    if (this.isRunning) {
      console.warn('[FileTreePollingService] 轮询已在运行中');
      return;
    }
    if (!this.qemuFs || !this.qemuFs.isReady()) {
      console.warn('[FileTreePollingService] QemuFileSystem 未就绪，无法启动轮询');
      return;
    }

    this.isRunning = true;
    // 首次启动时先更新哈希基准
    this.updateHash();

    console.info(`[FileTreePollingService] 启动轮询，间隔 ${this.intervalMs}ms，路径: ${this.currentPath}`);

    this.timerId = setInterval(() => {
      this.checkAndNotify();
    }, this.intervalMs);
  }

  /**
   * 停止轮询
   */
  stop(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.isRunning = false;
    console.info('[FileTreePollingService] 轮询已停止');
  }

  /**
   * 手动刷新（立即检查并通知）
   */
  refresh(): void {
    this.checkAndNotify();
  }

  /**
   * 检查目录变化并通知
   */
  private checkAndNotify(): void {
    if (!this.qemuFs || !this.qemuFs.isReady()) {
      console.warn('[FileTreePollingService] QemuFileSystem 不可用，跳过检查');
      return;
    }

    this.qemuFs.listDirectory(this.currentPath)
      .then((nodes: FileNode[]) => {
        if (!nodes) {
          console.warn('[FileTreePollingService] listDirectory 返回空');
          return;
        }
        const newHash = this.computeHash(nodes);
        if (newHash !== this.lastHash) {
          console.info(`[FileTreePollingService] 目录发生变化，刷新文件树 (${this.currentPath})`);
          this.lastHash = newHash;
          if (this.onDirectoryChanged) {
            this.onDirectoryChanged(nodes);
          }
        }
      })
      .catch((err: Error) => {
        console.warn('[FileTreePollingService] 轮询检查目录失败:', err);
        if (this.onError) {
          this.onError(err);
        }
      });
  }

  /**
   * 更新哈希基准（不触发通知）
   */
  private updateHash(): void {
    if (!this.qemuFs || !this.qemuFs.isReady()) {
      return;
    }
    this.qemuFs.listDirectory(this.currentPath)
      .then((nodes: FileNode[]) => {
        if (nodes) {
          this.lastHash = this.computeHash(nodes);
          console.info(`[FileTreePollingService] 哈希基准已更新: ${this.currentPath}`);
        }
      })
      .catch(() => {});
  }

  /**
   * 计算文件列表的哈希值（用于比对变化）
   */
  private computeHash(nodes: FileNode[]): string {
    return nodes.map(n => n.name + (n.isDir ? '/d' : '/f')).sort().join(',');
  }

  /**
   * 是否正在运行
   */
  isActive(): boolean {
    return this.isRunning;
  }

  /**
   * 获取当前监听路径
   */
  getCurrentPath(): string {
    return this.currentPath;
  }
}