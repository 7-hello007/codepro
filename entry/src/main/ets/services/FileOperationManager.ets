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
      this.showEmptyState();
      return;
    }

    // 判断文件类型
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

    if (this.useQemuFs && this.qemuFs.isReady()) {
      // ----- QEMU 模式：从虚拟机读取 -----
      try {
        content = await this.qemuFs.readFile(path);
        if (content !== null) {
          fileExists = true;
          // QEMU 下暂时无法获取修改时间，留空或可考虑 stat 命令
        } else {
          console.warn('⚠️ QEMU 读取文件失败:', path);
        }
      } catch (err) {
        console.error('❌ QEMU 读取异常:', err);
      }
    } else {
      // ----- 宿主模式（后备） -----
      try {
        content = this.hostFileService.readFile(path);
        fileExists = true;
        lastModified = this.hostFileService.getLastModifiedTime(path);
      } catch (err) {
        console.warn('⚠️ 真实文件读取失败，使用示例内容:', path);
        content = this.hostFileService.getDemoContent(path);
      }
    }

    // 如果内容为空，显示空状态
    if (content === null || content === undefined) {
      this.editorController.showEmptyState('无法读取文件内容');
      this.statusBarManager.setFileInfo('', '', '');
      if (this.onStateUpdate) {
        this.onStateUpdate({
          currentFilePath: path,
          currentFileType: '',
          editorContent: '',
          lastModifiedTime: ''
        });
      }
      return;
    }

    // 写入编辑器
    this.editorController.setContent(content, language);
    this.statusBarManager.setFileInfo(fileType, this.getDisplayPath(path), lastModified);

    if (this.onStateUpdate) {
      this.onStateUpdate({
        currentFilePath: path,
        currentFileType: fileType,
        editorContent: content,
        lastModifiedTime: lastModified
      });
    }
  }

  /**
   * 保存当前文件（根据 useQemuFs 自动选择目标）
   */
  async saveCurrentFile(activeTabPath: string, currentFilePath: string): Promise<void> {
    if (!activeTabPath || !currentFilePath || currentFilePath !== activeTabPath) return;

    const content = this.editorController.getCurrentContent();
    let success = false;

    if (this.useQemuFs && this.qemuFs.isReady()) {
      // ----- QEMU 模式：写入虚拟机 -----
      try {
        success = await this.qemuFs.writeFile(currentFilePath, content);
        if (success) {
          console.info('💾 QEMU 文件保存成功:', currentFilePath);
          // 可考虑获取修改时间（暂略）
        } else {
          console.error('❌ QEMU 保存失败:', currentFilePath);
        }
      } catch (err) {
        console.error('❌ QEMU 保存异常:', err);
      }
    } else {
      // ----- 宿主模式 -----
      try {
        this.hostFileService.writeFile(currentFilePath, content);
        success = true;
        const lastModified = this.hostFileService.getLastModifiedTime(currentFilePath);
        this.statusBarManager.setLastModified(lastModified);
        if (this.onStateUpdate) {
          this.onStateUpdate({ lastModifiedTime: lastModified });
        }
        console.info('💾 宿主文件保存成功:', currentFilePath);
      } catch (err) {
        console.error('❌ 宿主保存失败:', err);
      }
    }

    if (!success) {
      // 保存失败时提示（可扩展 Toast）
      console.warn('⚠️ 文件保存未成功');
    }
  }

  /**
   * 显示空状态（编辑器只读，显示提示信息）
   */
  showEmptyState(message: string = '未打开任何文件'): void {
    this.editorController.showEmptyState(message);
    this.statusBarManager.setFileInfo('', '', '');
    if (this.onStateUpdate) {
      this.onStateUpdate({
        currentFilePath: '',
        currentFileType: '',
        editorContent: '',
        lastModifiedTime: ''
      });
    }
  }

  /**
   * 获取显示用的相对路径（与原有逻辑一致）
   */
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

  /**
   * 刷新文件树（仅 QEMU 模式有效）
   */
  refreshFileTree(): void {
    if (this.useQemuFs && this.qemuFs.isReady()) {
      this.qemuFileTreeService.refresh();
    } else {
      console.warn('[FileOperationManager] Qemu未就绪或非Qemu模式，无法刷新');
    }
  }

  /**
   * 更新光标位置（透传）
   */
  updateCursor(line: number, col: number): void {
    if (this.onStateUpdate) {
      this.onStateUpdate({ currentLine: line, currentColumn: col });
    }
  }
}