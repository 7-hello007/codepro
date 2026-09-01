// entry/src/main/ets/services/FileTreeManager.ets
import { FileNode } from '../components/FileTree';
import fs from '@ohos.file.fs';

/**
 * 文件树管理器
 * 负责从宿主文件系统加载目录结构、展开/收起文件夹
 */
export class FileTreeManager {
  // 数据
  private rootNodes: FileNode[] = [];
  private folderVersion: number = 0;

  // 回调：数据发生变化时通知 UI 更新
  onDataChanged?: (nodes: FileNode[], version: number) => void;

  /**
   * 加载根目录
   */
  loadRootDirectory(path: string): void {
    try {
      const files: string[] = fs.listFileSync(path);
      const nodes: FileNode[] = [];
      for (const name of files) {
        const fullPath = path + '/' + name;
        let isDir = false;
        try {
          const stat = fs.statSync(fullPath);
          isDir = stat.isDirectory();
        } catch (e) {}
        const shouldExpand = isDir && (name === 'src' || name === 'utils');
        nodes.push({
          name: name,
          isDir: isDir,
          path: fullPath,
          isExpanded: shouldExpand,
          children: isDir ? [] : undefined
        });
      }
      this.sortFileNodes(nodes);
      this.rootNodes = nodes;
      this.folderVersion++;
      this.notifyChanged();

      // 自动展开预设目录
      for (const node of nodes) {
        if (node.isDir && node.isExpanded) {
          this.loadSubDirectory(node.path);
        }
      }
    } catch (err) {
      console.error('❌ 读取目录失败:', err);
      this.rootNodes = [];
      this.folderVersion++;
      this.notifyChanged();
    }
  }

  /**
   * 加载子目录（懒加载）
   */
  loadSubDirectory(path: string): void {
    try {
      const files: string[] = fs.listFileSync(path);
      const children: FileNode[] = [];
      for (const name of files) {
        const fullPath = path + '/' + name;
        let isDir = false;
        try {
          const stat = fs.statSync(fullPath);
          isDir = stat.isDirectory();
        } catch (e) {}
        children.push({
          name: name,
          isDir: isDir,
          path: fullPath,
          isExpanded: false,
          children: isDir ? [] : undefined
        });
      }
      this.sortFileNodes(children);

      const updatedTree = this.cloneNodes(this.rootNodes);
      const success = this.setChildrenForPath(updatedTree, path, children);
      if (success) {
        this.rootNodes = updatedTree;
        this.folderVersion++;
        this.notifyChanged();
      }
    } catch (err) {
      console.error('❌ 加载子目录失败:', path, err);
    }
  }

  /**
   * 切换文件夹展开/收起状态
   */
  toggleDirectory(path: string): void {
    const updatedTree = this.cloneNodes(this.rootNodes);
    const node = this.findNodeByPath(updatedTree, path);
    if (!node) return;
    node.isExpanded = !node.isExpanded;
    this.rootNodes = updatedTree;
    this.folderVersion++;
    this.notifyChanged();

    if (node.isExpanded && (!node.children || node.children.length === 0)) {
      this.loadSubDirectory(path);
    }
  }

  /**
   * 获取当前文件树数据（只读）
   */
  getNodes(): FileNode[] {
    return this.rootNodes;
  }

  getVersion(): number {
    return this.folderVersion;
  }

  // ---------- 内部辅助方法 ----------
  private setChildrenForPath(nodes: FileNode[], targetPath: string, children: FileNode[]): boolean {
    for (const node of nodes) {
      if (node.path === targetPath) {
        node.children = children;
        return true;
      }
      if (node.children && node.children.length > 0) {
        if (this.setChildrenForPath(node.children, targetPath, children)) return true;
      }
    }
    return false;
  }

  private cloneNodes(nodes: FileNode[]): FileNode[] {
    const result: FileNode[] = [];
    for (const node of nodes) {
      result.push({
        name: node.name,
        path: node.path,
        isDir: node.isDir,
        isExpanded: node.isExpanded,
        children: node.children ? this.cloneNodes(node.children) : undefined
      });
    }
    return result;
  }

  private sortFileNodes(nodes: FileNode[]): void {
    nodes.sort((a, b) => {
      if (a.isDir && !b.isDir) return -1;
      if (!a.isDir && b.isDir) return 1;
      return a.name.localeCompare(b.name);
    });
  }

  private findNodeByPath(nodes: FileNode[], path: string): FileNode | undefined {
    for (const node of nodes) {
      if (node.path === path) return node;
      if (node.children && node.children.length > 0) {
        const result = this.findNodeByPath(node.children, path);
        if (result) return result;
      }
    }
    return undefined;
  }

  private notifyChanged(): void {
    if (this.onDataChanged) {
      this.onDataChanged(this.rootNodes, this.folderVersion);
    }
  }
}