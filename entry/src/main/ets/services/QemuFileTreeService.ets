// entry/src/main/ets/services/QemuFileTreeService.ets
import { FileNode } from '../components/FileTree';
import { QemuFileSystem } from '../lib/QemuFileSystem';

export class QemuFileTreeService {
  private qemuFs: QemuFileSystem | null = null;
  private version: number = 0;
  private currentRoot: string = '/';
  private rootNodes: FileNode[] = [];

  onDataChanged?: (nodes: FileNode[], version: number) => void;

  bindFileSystem(qemuFs: QemuFileSystem): void {
    this.qemuFs = qemuFs;
    console.info('[FileTreeCheck] QemuFileTreeService 绑定 QemuFileSystem');
  }

  isReady(): boolean {
    const ready = this.qemuFs !== null && this.qemuFs.isReady();
    console.info('[FileTreeCheck] QemuFileTreeService.isReady:', ready);
    return ready;
  }

  async loadRootDirectory(path?: string): Promise<void> {
    console.info('[FileTreeCheck] loadRootDirectory 入口, path:', path, 'currentRoot:', this.currentRoot);
    if (!this.qemuFs || !this.qemuFs.isReady()) {
      console.warn('[FileTreeCheck] QemuFileSystem 未就绪，无法加载根目录');
      return;
    }
    if (path !== undefined) {
      this.currentRoot = path;
      console.info('[FileTreeCheck] currentRoot 更新为:', this.currentRoot);
    }
    try {
      let nodes: FileNode[];
      if (this.currentRoot === '/') {
        console.info('[FileTreeCheck] 加载根目录 /');
        nodes = await this.qemuFs.listDirectory('/');
      } else {
        console.info('[FileTreeCheck] 加载非根目录:', this.currentRoot);
        const children = await this.qemuFs.listDirectory(this.currentRoot);
        const dirName = this.currentRoot.split('/').filter(p => p !== '').pop() || this.currentRoot;
        const rootNode: FileNode = {
          name: dirName,
          path: this.currentRoot,
          isDir: true,
          isExpanded: false,
          children: children
        };
        nodes = [rootNode];
        console.info('[FileTreeCheck] 创建根节点:', dirName, '子节点数:', children.length);
      }
      this.rootNodes = nodes;
      this.version++;
      console.info('[FileTreeCheck] 目录加载完成，根节点数:', nodes.length, 'version:', this.version);
      if (this.onDataChanged) {
        this.onDataChanged(nodes, this.version);
        console.info('[FileTreeCheck] 已触发 onDataChanged 回调');
      }
    } catch (err) {
      console.error('[FileTreeCheck] 加载目录失败:', this.currentRoot, err);
    }
  }

  async loadChildren(path: string): Promise<FileNode[]> {
    console.info('[FileTreeCheck] loadChildren 入口:', path);
    if (!this.qemuFs || !this.qemuFs.isReady()) {
      console.warn('[FileTreeCheck] QemuFileSystem 未就绪，返回空数组');
      return [];
    }
    try {
      const nodes = await this.qemuFs.listDirectory(path);
      console.info('[FileTreeCheck] loadChildren 成功，路径:', path, '子节点数:', nodes.length);
      return nodes;
    } catch (err) {
      console.error('[FileTreeCheck] loadChildren 失败:', path, err);
      return [];
    }
  }

  // ★ 新增 toggleExpand 方法 ★
  async toggleExpand(path: string): Promise<void> {
    console.info('[FileTreeCheck] toggleExpand 入口:', path);
    const node = this.findNode(this.rootNodes, path);
    if (!node) {
      console.warn('[FileTreeCheck] 未找到节点:', path);
      return;
    }
    console.info('[FileTreeCheck] 找到节点，当前 isExpanded:', node.isExpanded, 'children 数量:', node.children?.length || 0);

    if (node.isExpanded) {
      // 收缩
      node.isExpanded = false;
      console.info('[FileTreeCheck] 收缩节点:', path);
      this.version++;
      console.info('[FileTreeCheck] version 增加到:', this.version);
      if (this.onDataChanged) {
        this.onDataChanged(this.rootNodes, this.version);
        console.info('[FileTreeCheck] 收缩后触发回调');
      }
      return;
    }

    // 展开：懒加载子节点
    if (!node.children || node.children.length === 0) {
      console.info('[FileTreeCheck] 节点 children 为空，开始加载:', path);
      const children = await this.loadChildren(path);
      node.children = children;
      console.info('[FileTreeCheck] 加载完成，子节点数:', children.length);
    } else {
      console.info('[FileTreeCheck] 使用已缓存的子节点，数量:', node.children.length);
    }
    node.isExpanded = true;
    this.version++;
    console.info('[FileTreeCheck] 展开节点，version 增加到:', this.version);
    if (this.onDataChanged) {
      this.onDataChanged(this.rootNodes, this.version);
      console.info('[FileTreeCheck] 展开后触发回调');
    }
  }

  private findNode(nodes: FileNode[], path: string): FileNode | null {
    for (const node of nodes) {
      if (node.path === path) {
        console.info('[FileTreeCheck] findNode 命中:', path);
        return node;
      }
      if (node.children) {
        const found = this.findNode(node.children, path);
        if (found) return found;
      }
    }
    return null;
  }

  async refresh(): Promise<void> {
    console.info('[FileTreeCheck] refresh 入口');
    await this.loadRootDirectory();
  }

  getCurrentRoot(): string {
    return this.currentRoot;
  }

  getVersion(): number {
    return this.version;
  }

  getRootNodes(): FileNode[] {
    return this.rootNodes;
  }
}