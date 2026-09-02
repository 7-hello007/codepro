// entry/src/main/ets/services/QemuFileTreeService.ets
import { FileNode } from '../components/FileTree';
import { QemuFileSystem } from '../lib/QemuFileSystem';

/**
 * Qemu 文件树服务
 * 负责加载根目录、展开/收起子节点，支持动态切换根目录
 */
export class QemuFileTreeService {
  private qemuFs: QemuFileSystem | null = null;
  private version: number = 0;
  private currentRoot: string = '/';

  // 数据变化回调
  onDataChanged?: (nodes: FileNode[], version: number) => void;

  bindFileSystem(qemuFs: QemuFileSystem): void {
    this.qemuFs = qemuFs;
  }

  isReady(): boolean {
    return this.qemuFs !== null && this.qemuFs.isReady();
  }

  /**
   * 加载指定目录作为根目录
   * @param path 要加载的目录路径，若不传则使用当前的 currentRoot
   */
  async loadRootDirectory(path?: string): Promise<void> {
    if (!this.qemuFs || !this.qemuFs.isReady()) {
      console.warn('[QemuFileTreeService] QemuFileSystem 未就绪');
      return;
    }
    // 如果传入了路径，更新 currentRoot
    if (path !== undefined) {
      this.currentRoot = path;
    }
    try {
      const nodes: FileNode[] = await this.qemuFs.listDirectory(this.currentRoot);
      console.info('[QemuFileTreeService] 目录加载完成，路径:', this.currentRoot, '节点数:', nodes.length);
      this.version++;
      if (this.onDataChanged) {
        this.onDataChanged(nodes, this.version);
      }
    } catch (err) {
      console.error('[QemuFileTreeService] 加载目录失败:', this.currentRoot, err);
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
   * 刷新当前根目录（使用 currentRoot）
   */
  async refresh(): Promise<void> {
    // 调用 loadRootDirectory 但不传参，使用 currentRoot
    await this.loadRootDirectory();
  }

  /**
   * 获取当前根目录路径
   */
  getCurrentRoot(): string {
    return this.currentRoot;
  }

  getVersion(): number {
    return this.version;
  }
}