// entry/src/main/ets/services/QemuContextMenuManager.ets
import promptAction from '@ohos.promptAction';
import { QemuFileSystem } from '../lib/QemuFileSystem';

/**
 * Qemu 右键菜单管理器
 * 负责显示右键菜单、创建/删除操作执行
 */
export class QemuContextMenuManager {
  private qemuFs: QemuFileSystem | null = null;
  private onRefreshNeeded?: () => void;

  // 回调：通知外部显示创建对话框
  onShowCreateDialog?: (parentPath: string, type: 'file' | 'folder') => void;
  // 回调：通知外部显示删除确认对话框
  onShowDeleteDialog?: (path: string, isDir: boolean) => void;

  bindFileSystem(qemuFs: QemuFileSystem): void {
    this.qemuFs = qemuFs;
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
          // 新建文件
          const parentPath = isDir ? path : path.substring(0, path.lastIndexOf('/'));
          if (this.onShowCreateDialog) {
            this.onShowCreateDialog(parentPath, 'file');
          }
        } else if (index === 1) {
          // 新建文件夹
          const parentPath = isDir ? path : path.substring(0, path.lastIndexOf('/'));
          if (this.onShowCreateDialog) {
            this.onShowCreateDialog(parentPath, 'folder');
          }
        } else if (index === 2) {
          // 删除
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
   * 执行创建
   */
  async executeCreate(parentPath: string, name: string, type: 'file' | 'folder'): Promise<boolean> {
    if (!this.qemuFs) return false;
    const fullPath = parentPath + '/' + name;
    try {
      let success: boolean;
      if (type === 'file') {
        success = await this.qemuFs.touch(fullPath);
      } else {
        success = await this.qemuFs.mkdir(fullPath);
      }
      if (success && this.onRefreshNeeded) {
        this.onRefreshNeeded();
      }
      return success;
    } catch (e) {
      console.error('[QemuContextMenuManager] 创建失败:', e);
      return false;
    }
  }

  /**
   * 执行删除
   */
  async executeDelete(path: string): Promise<boolean> {
    if (!this.qemuFs) return false;
    try {
      const success = await this.qemuFs.rm(path);
      if (success && this.onRefreshNeeded) {
        this.onRefreshNeeded();
      }
      return success;
    } catch (e) {
      console.error('[QemuContextMenuManager] 删除失败:', e);
      return false;
    }
  }
}