// entry/src/main/ets/services/QemuCoordinator.ets
import { QemuAgentManager } from '../lib/QemuAgentManager';
import { QemuAgent } from '../lib/QemuAgent';
import { QemuFileSystem } from '../lib/QemuFileSystem';
import { QemuFileTreeService } from './QemuFileTreeService';
import { FileTreePollingService } from './FileTreePollingService';
import promptAction from '@ohos.promptAction';

/**
 * Qemu 协调器
 * 负责 Agent 重试获取，成功后初始化文件树和轮询服务
 */
export class QemuCoordinator {
  private maxRetries: number = 30;
  private delayMs: number = 2000;
  private qemuFs: QemuFileSystem | null = null;
  private qemuFileTreeService: QemuFileTreeService | null = null;
  private pollingService: FileTreePollingService | null = null;
  private isRunning: boolean = false;
  private timerId: number = -1;
  private onReady?: () => void;

  bindServices(
    qemuFs: QemuFileSystem,
    qemuFileTreeService: QemuFileTreeService,
    pollingService: FileTreePollingService
  ): void {
    this.qemuFs = qemuFs;
    this.qemuFileTreeService = qemuFileTreeService;
    this.pollingService = pollingService;
  }

  setOnReady(callback: () => void): void {
    this.onReady = callback;
  }

  start(): void {
    if (this.isRunning) {
      console.warn('[QemuCoordinator] 已在运行中');
      return;
    }
    this.isRunning = true;
    let attempt = 0;

    const tryAcquire = (): void => {
      if (!this.isRunning) {
        console.warn('[QemuCoordinator] 已停止，不再重试');
        return;
      }

      attempt++;
      console.info(`[QemuCoordinator] 尝试获取 QemuAgent (${attempt}/${this.maxRetries})...`);

      QemuAgentManager.release('IDELayout')
        .catch(() => {})
        .finally(() => {
          QemuAgentManager.acquire('IDELayout')
            .then((agent: QemuAgent | null) => {
              if (!this.isRunning) return;

              if (agent) {
                this.qemuFs?.bindAgent(agent);
                console.info(`[QemuCoordinator] ✅ QemuAgent 获取成功 (尝试 ${attempt} 次)`);
                this.isRunning = false;
                this.initQemuServices();
                if (this.onReady) this.onReady();
              } else {
                console.warn(`[QemuCoordinator] agent 为 null (尝试 ${attempt}/${this.maxRetries})，${this.delayMs}ms 后重试...`);
                if (attempt < this.maxRetries) {
                  this.timerId = setTimeout(tryAcquire, this.delayMs);
                } else {
                  console.error(`[QemuCoordinator] ❌ 经过 ${this.maxRetries} 次尝试，仍无法获取 QemuAgent`);
                  this.isRunning = false;
                  promptAction.showToast({
                    message: '无法连接到虚拟机 QGA，请检查虚拟机状态',
                    duration: 3000
                  });
                }
              }
            })
            .catch((err: Error) => {
              if (!this.isRunning) return;
              console.error(`[QemuCoordinator] acquire 异常 (尝试 ${attempt}/${this.maxRetries}):`, err);
              if (attempt < this.maxRetries) {
                this.timerId = setTimeout(tryAcquire, this.delayMs);
              } else {
                this.isRunning = false;
              }
            });
        });
    };

    tryAcquire();
  }

  private initQemuServices(): void {
    if (!this.qemuFs || !this.qemuFileTreeService || !this.pollingService) {
      console.warn('[QemuCoordinator] 服务未绑定，无法初始化');
      return;
    }
    console.info('[QemuCoordinator] 初始化 Qemu 文件系统...');
    this.pollingService.bindFileSystem(this.qemuFs);
    this.pollingService.setCurrentPath('/');
    this.qemuFileTreeService.loadRootDirectory();
    this.pollingService.start();
  }

  stop(): void {
    this.isRunning = false;
    if (this.timerId !== -1) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
    QemuAgentManager.release('IDELayout').catch(() => {});
    console.info('[QemuCoordinator] 已停止');
  }
}