// entry/src/main/ets/services/FileOperationManager.ets
import { FileNode } from '../components/FileTree';
import { EditorTab } from '../components/EditorTabs';
import { HostFileService } from './HostFileService';
import { TabManager } from './TabManager';
import { EditorController } from './EditorController';
import { StatusBarManager } from './StatusBarManager';
import { QemuFileTreeService } from './QemuFileTreeService';
import { QemuFileSystem } from '../lib/QemuFileSystem';

interface StateUpdateData {
  fileTreeData?: FileNode[];
  folderVersion?: number;
  currentFilePath?: string;
  currentFileType?: string;
  editorContent?: string;
  lastModifiedTime?: string;
  currentLine?: number;
  currentColumn?: number;
}

export class FileOperationManager {
  private hostFileService: HostFileService;
  private tabManager: TabManager;
  private editorController: EditorController;
  private statusBarManager: StatusBarManager;
  private qemuFileTreeService: QemuFileTreeService;
  private qemuFs: QemuFileSystem;
  private useQemuFs: boolean;

  public onStateUpdate?: (data: StateUpdateData) => void;

  constructor(
    hostFileService: HostFileService,
    tabManager: TabManager,
    editorController: EditorController,
    statusBarManager: StatusBarManager,
    qemuFileTreeService: QemuFileTreeService,
    qemuFs: QemuFileSystem,
    useQemuFs: boolean
  ) {
    this.hostFileService = hostFileService;
    this.tabManager = tabManager;
    this.editorController = editorController;
    this.statusBarManager = statusBarManager;
    this.qemuFileTreeService = qemuFileTreeService;
    this.qemuFs = qemuFs;
    this.useQemuFs = useQemuFs;
  }

  /**
   * 加载文件内容（根据 useQemuFs 自动选择数据源）
   */
  async loadFileContent(path: string): Promise<void> {
    console.info('📂 loadFileContent:', path);
    if (!path) {
      this.showEmptyState('未指定文件路径');
      return;
    }

    const ext = path.split('.').pop()?.toLowerCase() || '';
    const typeMap: Record<string, string> = {
      'ets': 'ArkTS', 'ts': 'TypeScript', 'js': 'JavaScript',
      'json': 'JSON', 'html': 'HTML', 'css': 'CSS',
      'xml': 'XML', 'py': 'Python', 'java': 'Java',
      'c': 'C', 'cpp': 'C++', 'go': 'Go', 'md': 'Markdown', 'txt': 'Text'
    };
    const fileType = typeMap[ext] || 'Plain Text';
    const language = EditorController.getLanguageFromPath(path);

    let content: string | null = null;
    let fileExists = false;
    let lastModified = '';
    let readError: Error | null = null;

    if (this.useQemuFs && this.qemuFs.isReady()) {
      try {
        content = await this.qemuFs.readFile(path);
        // 关键：只要返回非 null，就认为文件存在（即使内容为空字符串）
        if (content !== null) {
          fileExists = true;
          // 如果内容为 null 但未抛异常，说明文件存在但读取失败？实际上 null 表示错误，我们视为不存在
        } else {
          // 返回 null 表示读取失败（文件不存在或无法读取）
          console.warn('⚠️ QEMU 读取文件失败（返回null）:', path);
          readError = new Error('文件不存在或无法读取');
        }
      } catch (err) {
        console.error('❌ QEMU 读取异常:', err);
        readError = err instanceof Error ? err : new Error(String(err));
      }
    } else {
      try {
        content = this.hostFileService.readFile(path);
        fileExists = true;
        lastModified = this.hostFileService.getLastModifiedTime(path);
      } catch (err) {
        console.warn('⚠️ 宿主读取失败，使用示例内容:', path);
        content = this.hostFileService.getDemoContent(path);
        // 对于宿主模式，即使失败也返回 demo 内容，视为存在
        fileExists = true;
      }
    }

    // 处理读取错误（仅当 QEMU 模式且未读取到内容）
    if (readError) {
      const errorMsg = `无法读取文件: ${path} – ${readError.message}`;
      this.editorController.showEmptyState(errorMsg);
      this.statusBarManager.setFileInfo('', '', '');
      this.updateState({ currentFilePath: path, currentFileType: '', editorContent: '', lastModifiedTime: '' });
      // 注意：此时编辑器只读，无法编辑
      return;
    }

    // 文件存在但内容为空字符串 或 有内容
    // 注意：content 可能是 null（如果上面未处理），但我们已经处理了 readError，所以这里 content 不会是 null（除非宿主模式 demo 返回 null，但不会）
    const contentStr = content ?? '';

    // 写入编辑器（内容可以是空字符串）
    this.editorController.setContent(contentStr, language);
    this.statusBarManager.setFileInfo(fileType, this.getDisplayPath(path), lastModified);

    // 更新修改时间
    if (fileExists && lastModified) {
      this.statusBarManager.setLastModified(lastModified);
    } else {
      const now = new Date().toLocaleString('zh-CN', { hour12: false });
      this.statusBarManager.setLastModified(now);
    }

    this.updateState({
      currentFilePath: path,
      currentFileType: fileType,
      editorContent: contentStr,
      lastModifiedTime: lastModified || new Date().toLocaleString('zh-CN', { hour12: false })
    });

    // 注意：setContent 内部会根据内容是否为空调用 setReadOnly
    // 但我们需要确保空内容时是可编辑的，所以强制取消只读
    // 因为 fileExists 为 true，无论内容是否为空，都应可编辑
    this.editorController.setReadOnly(false);
  }

  /**
   * 保存当前文件（根据 useQemuFs 自动选择目标）
   */
  async saveCurrentFile(activeTabPath: string, currentFilePath: string): Promise<void> {
    if (!activeTabPath || !currentFilePath || currentFilePath !== activeTabPath) return;

    const content = this.editorController.getCurrentContent();
    let success = false;

    if (this.useQemuFs && this.qemuFs.isReady()) {
      try {
        success = await this.qemuFs.writeFile(currentFilePath, content);
        if (success) {
          console.info('💾 QEMU 文件保存成功:', currentFilePath);
          const now = new Date().toLocaleString('zh-CN', { hour12: false });
          this.statusBarManager.setLastModified(now);
          this.updateState({ lastModifiedTime: now });
        } else {
          console.error('❌ QEMU 保存失败:', currentFilePath);
        }
      } catch (err) {
        console.error('❌ QEMU 保存异常:', err);
      }
    } else {
      try {
        this.hostFileService.writeFile(currentFilePath, content);
        success = true;
        const lastModified = this.hostFileService.getLastModifiedTime(currentFilePath);
        this.statusBarManager.setLastModified(lastModified);
        this.updateState({ lastModifiedTime: lastModified });
        console.info('💾 宿主文件保存成功:', currentFilePath);
      } catch (err) {
        console.error('❌ 宿主保存失败:', err);
      }
    }

    if (!success) {
      console.warn('⚠️ 文件保存未成功');
    }
  }

  /**
   * 显示空状态（真正的空状态，用于未打开文件或错误）
   */
  showEmptyState(message: string = '未打开任何文件'): void {
    this.editorController.showEmptyState(message);
    this.statusBarManager.setFileInfo('', '', '');
    this.updateState({
      currentFilePath: '',
      currentFileType: '',
      editorContent: '',
      lastModifiedTime: ''
    });
  }

  getDisplayPath(path: string): string {
    if (!path) return '';
    const workDir = this.hostFileService.getWorkDir();
    let displayPath = path;
    if (workDir && displayPath.startsWith(workDir)) {
      displayPath = displayPath.substring(workDir.length);
      if (displayPath.startsWith('/')) displayPath = displayPath.substring(1);
    }
    const parts = displayPath.split('/').filter(p => p !== '');
    if (parts.length === 0) return '';
    if (parts.length > 3) return '... > ' + parts.slice(-3).join(' > ');
    return parts.join(' > ');
  }

  refreshFileTree(): void {
    if (this.useQemuFs && this.qemuFs.isReady()) {
      this.qemuFileTreeService.refresh();
    } else {
      console.warn('[FileOperationManager] Qemu未就绪或非Qemu模式，无法刷新');
    }
  }

  updateCursor(line: number, col: number): void {
    this.updateState({ currentLine: line, currentColumn: col });
  }

  private updateState(data: Partial<StateUpdateData>): void {
    if (this.onStateUpdate) {
      this.onStateUpdate(data as StateUpdateData);
    }
  }
}