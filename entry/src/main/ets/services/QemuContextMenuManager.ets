// entry/src/main/ets/services/QemuContextMenuManager.ets
import promptAction from '@ohos.promptAction';
import { QemuFileSystem } from '../lib/QemuFileSystem';
import { StatusBarManager } from './StatusBarManager'; // 新增导入

/**
 * Qemu 右键菜单管理器
 * 负责显示右键菜单、创建/删除操作执行
 */
export class QemuContextMenuManager {
  private qemuFs: QemuFileSystem | null = null;
  private onRefreshNeeded?: () => void;
  private statusBarManager: StatusBarManager | null = null; // 新增

  // 回调：通知外部显示创建对话框
  onShowCreateDialog?: (parentPath: string, type: 'file' | 'folder') => void;
  // 回调：通知外部显示删除确认对话框
  onShowDeleteDialog?: (path: string, isDir: boolean) => void;

  bindFileSystem(qemuFs: QemuFileSystem): void {
    this.qemuFs = qemuFs;
  }

  // ====== 新增：绑定状态栏管理器 ======
  bindStatusBarManager(statusBarManager: StatusBarManager): void {
    this.statusBarManager = statusBarManager;
  }

  setRefreshCallback(callback: () => void): void {
    this.onRefreshNeeded = callback;
  }

  isReady(): boolean {
    return this.qemuFs !== null && this.qemuFs.isReady();
  }

  /**
   * 显示右键菜单
   */
  showContextMenu(path: string, isDir: boolean): void {
    if (!this.qemuFs || !this.qemuFs.isReady()) {
      promptAction.showToast({ message: 'Qemu 未就绪', duration: 1000 });
      return;
    }

    promptAction.showActionMenu({
      title: `文件操作 - ${path}`,
      buttons: [
        { text: '新建文件', color: '#007dff' },
        { text: '新建文件夹', color: '#007dff' },
        { text: '删除', color: '#ff3b30' }
      ]
    })
      .then((data: promptAction.ActionMenuSuccessResponse) => {
        const index = data.index;
        if (index === 0) {
          const parentPath = isDir ? path : path.substring(0, path.lastIndexOf('/'));
          if (this.onShowCreateDialog) {
            this.onShowCreateDialog(parentPath, 'file');
          }
        } else if (index === 1) {
          const parentPath = isDir ? path : path.substring(0, path.lastIndexOf('/'));
          if (this.onShowCreateDialog) {
            this.onShowCreateDialog(parentPath, 'folder');
          }
        } else if (index === 2) {
          if (this.onShowDeleteDialog) {
            this.onShowDeleteDialog(path, isDir);
          }
        }
      })
      .catch((err: Error) => {
        console.warn('[QemuContextMenuManager] 显示菜单失败:', err);
      });
  }

  /**
   * 执行创建（带进度反馈）
   */
  async executeCreate(parentPath: string, name: string, type: 'file' | 'folder'): Promise<boolean> {
    if (!this.qemuFs) return false;
    const fullPath = parentPath + '/' + name;
    const actionName = type === 'file' ? '文件' : '文件夹';
    // ====== 开始进度 ======
    this.statusBarManager?.startOperation(`正在创建${actionName}: ${name}`);
    try {
      let success: boolean;
      if (type === 'file') {
        success = await this.qemuFs.touch(fullPath);
      } else {
        success = await this.qemuFs.mkdir(fullPath);
      }
      // ====== 结束进度（无论成功失败） ======
      this.statusBarManager?.finishOperation();
      if (success && this.onRefreshNeeded) {
        this.onRefreshNeeded();
      }
      return success;
    } catch (e) {
      console.error('[QemuContextMenuManager] 创建失败:', e);
      this.statusBarManager?.finishOperation();
      return false;
    }
  }

  /**
   * 执行删除（带进度反馈）
   */
  async executeDelete(path: string): Promise<boolean> {
    if (!this.qemuFs) return false;
    const name = path.split('/').pop() || path;
    // ====== 开始进度 ======
    this.statusBarManager?.startOperation(`正在删除: ${name}`);
    try {
      const success = await this.qemuFs.rm(path);
      this.statusBarManager?.finishOperation();
      if (success && this.onRefreshNeeded) {
        this.onRefreshNeeded();
      }
      return success;
    } catch (e) {
      console.error('[QemuContextMenuManager] 删除失败:', e);
      this.statusBarManager?.finishOperation();
      return false;
    }
  }
}