// entry/src/main/ets/services/QemuFileTreeService.ets
import { FileNode } from '../components/FileTree';
import { QemuFileSystem } from '../lib/QemuFileSystem';

/**
 * Qemu 文件树服务
 * 负责加载根目录、展开/收起子节点，始终保持在根目录 /，不切换整体视图
 */
export class QemuFileTreeService {
  private qemuFs: QemuFileSystem | null = null;
  private version: number = 0;

  // 数据变化回调
  onDataChanged?: (nodes: FileNode[], version: number) => void;

  bindFileSystem(qemuFs: QemuFileSystem): void {
    this.qemuFs = qemuFs;
  }

  isReady(): boolean {
    return this.qemuFs !== null && this.qemuFs.isReady();
  }

  /**
   * 加载根目录 /
   */
  async loadRootDirectory(): Promise<void> {
    if (!this.qemuFs || !this.qemuFs.isReady()) {
      console.warn('[QemuFileTreeService] QemuFileSystem 未就绪');
      return;
    }
    try {
      const nodes: FileNode[] = await this.qemuFs.listDirectory('/');
      console.info('[QemuFileTreeService] 根目录加载完成，节点数:', nodes.length);
      this.version++;
      if (this.onDataChanged) {
        this.onDataChanged(nodes, this.version);
      }
    } catch (err) {
      console.error('[QemuFileTreeService] 加载根目录失败:', err);
    }
  }

  /**
   * 加载子目录（用于展开文件夹时懒加载）
   */
  async loadChildren(path: string): Promise<FileNode[]> {
    if (!this.qemuFs || !this.qemuFs.isReady()) {
      return [];
    }
    try {
      const nodes = await this.qemuFs.listDirectory(path);
      return nodes;
    } catch (err) {
      console.error('[QemuFileTreeService] 加载子目录失败:', path, err);
      return [];
    }
  }

  /**
   * 刷新根目录（供手动刷新、创建/删除后调用）
   */
  async refresh(): Promise<void> {
    await this.loadRootDirectory();
  }

  getVersion(): number {
    return this.version;
  }
}