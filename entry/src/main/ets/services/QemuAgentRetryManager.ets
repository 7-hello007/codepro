// entry/src/main/ets/services/QemuAgentRetryManager.ets
import { QemuAgentManager } from '../lib/QemuAgentManager';
import { QemuAgent } from '../lib/QemuAgent';
import { QemuFileSystem } from '../lib/QemuFileSystem';
import promptAction from '@ohos.promptAction';

/**
 * QemuAgent 重试管理器
 * 负责带重试的 Agent 获取，独立管理连接状态
 */
export class QemuAgentRetryManager {
  private maxRetries: number = 30;
  private delayMs: number = 2000;
  private qemuFs: QemuFileSystem | null = null;
  private onSuccess?: () => void;
  private onFailure?: () => void;
  private isRunning: boolean = false;
  private timerId: number = -1;

  bindFileSystem(qemuFs: QemuFileSystem): void {
    this.qemuFs = qemuFs;
  }

  setSuccessCallback(callback: () => void): void {
    this.onSuccess = callback;
  }

  setFailureCallback(callback: () => void): void {
    this.onFailure = callback;
  }

  /**
   * 启动重试获取
   */
  start(): void {
    if (this.isRunning) {
      console.warn('[QemuAgentRetryManager] 已在运行中');
      return;
    }
    this.isRunning = true;
    let attempt = 0;

    const tryAcquire = (): void => {
      if (!this.isRunning) {
        console.warn('[QemuAgentRetryManager] 已停止，不再重试');
        return;
      }

      attempt++;
      console.info(`[QemuAgentRetryManager] 尝试获取 QemuAgent (${attempt}/${this.maxRetries})...`);

      QemuAgentManager.release('IDELayout')
        .catch(() => {})
        .finally(() => {
          QemuAgentManager.acquire('IDELayout')
            .then((agent: QemuAgent | null) => {
              if (!this.isRunning) return;

              if (agent) {
                this.qemuFs?.bindAgent(agent);
                console.info(`[QemuAgentRetryManager] ✅ QemuAgent 获取成功 (尝试 ${attempt} 次)`);
                this.isRunning = false;
                if (this.onSuccess) {
                  this.onSuccess();
                }
              } else {
                console.warn(`[QemuAgentRetryManager] agent 为 null (尝试 ${attempt}/${this.maxRetries})，${this.delayMs}ms 后重试...`);
                if (attempt < this.maxRetries) {
                  this.timerId = setTimeout(tryAcquire, this.delayMs);
                } else {
                  console.error(`[QemuAgentRetryManager] ❌ 经过 ${this.maxRetries} 次尝试，仍无法获取 QemuAgent`);
                  this.isRunning = false;
                  promptAction.showToast({
                    message: '无法连接到虚拟机 QGA，请检查虚拟机状态',
                    duration: 3000
                  });
                  if (this.onFailure) {
                    this.onFailure();
                  }
                }
              }
            })
            .catch((err: Error) => {
              if (!this.isRunning) return;
              console.error(`[QemuAgentRetryManager] acquire 异常 (尝试 ${attempt}/${this.maxRetries}):`, err);
              if (attempt < this.maxRetries) {
                this.timerId = setTimeout(tryAcquire, this.delayMs);
              } else {
                this.isRunning = false;
                if (this.onFailure) {
                  this.onFailure();
                }
              }
            });
        });
    };

    tryAcquire();
  }

  /**
   * 停止重试
   */
  stop(): void {
    this.isRunning = false;
    if (this.timerId !== -1) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
    QemuAgentManager.release('IDELayout').catch(() => {});
    console.info('[QemuAgentRetryManager] 已停止');
  }

  isActive(): boolean {
    return this.isRunning;
  }
}