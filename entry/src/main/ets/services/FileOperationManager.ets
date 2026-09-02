// entry/src/main/ets/services/FileOperationManager.ets
import { FileNode } from '../components/FileTree';
import { EditorTab } from '../components/EditorTabs';
import { HostFileService } from './HostFileService';
import { TabManager } from './TabManager';
import { EditorController } from './EditorController';
import { StatusBarManager } from './StatusBarManager';
import { QemuFileTreeService } from './QemuFileTreeService';
import { QemuFileSystem } from '../lib/QemuFileSystem';
import { QemuAgent } from '../lib/QemuAgent';
import { util } from '@kit.ArkTS';

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
  private qemuAgent: QemuAgent | null;

  public onStateUpdate?: (data: StateUpdateData) => void;

  constructor(
    hostFileService: HostFileService,
    tabManager: TabManager,
    editorController: EditorController,
    statusBarManager: StatusBarManager,
    qemuFileTreeService: QemuFileTreeService,
    qemuFs: QemuFileSystem,
    useQemuFs: boolean,
    qemuAgent: QemuAgent | null = null
  ) {
    this.hostFileService = hostFileService;
    this.tabManager = tabManager;
    this.editorController = editorController;
    this.statusBarManager = statusBarManager;
    this.qemuFileTreeService = qemuFileTreeService;
    this.qemuFs = qemuFs;
    this.useQemuFs = useQemuFs;
    this.qemuAgent = qemuAgent;
    console.info('[FileTreeCheck] FileOperationManager 构造完成, useQemuFs:', this.useQemuFs, 'agent:', this.qemuAgent ? '存在' : 'null');
  }

  async loadFileContent(path: string): Promise<void> {
    console.info('[FileTreeCheck] loadFileContent 入口, 原始路径:', path);
    if (!path) {
      this.showEmptyState('未指定文件路径');
      return;
    }

    let absolutePath = path;
    if (!path.startsWith('/')) {
      absolutePath = '/root/' + path;
      console.warn('[FileTreeCheck] 路径非绝对，补全为:', absolutePath);
    } else {
      console.info('[FileTreeCheck] 路径已是绝对路径:', absolutePath);
    }

    let ext: string = absolutePath.split('.').pop()?.toLowerCase() || '';
    let typeMap: Record<string, string> = {
      'ets': 'ArkTS', 'ts': 'TypeScript', 'js': 'JavaScript',
      'json': 'JSON', 'html': 'HTML', 'css': 'CSS',
      'xml': 'XML', 'py': 'Python', 'java': 'Java',
      'c': 'C', 'cpp': 'C++', 'go': 'Go', 'md': 'Markdown', 'txt': 'Text'
    };
    let fileType: string = typeMap[ext] || 'Plain Text';
    let language: string = EditorController.getLanguageFromPath(absolutePath);

    let content: string | null = null;
    let fileExists: boolean = false;
    let lastModified: string = '';
    let detectedEncoding: string = 'utf-8';

    // ★★★ 核心修正：只要 useQemuFs 且 qemuFs 就绪，就走 QEMU 读取，不依赖 agent ★★★
    if (this.useQemuFs && this.qemuFs.isReady()) {
      console.info('[FileTreeCheck] 进入 QEMU 读取分支, agent就绪=', this.qemuAgent !== null);
      try {
        if (this.qemuAgent !== null) {
          // 有 agent，用 base64（支持编码检测）
          console.info('[FileTreeCheck] 使用 base64 读取:', absolutePath);
          let base64Str: string | null = await this.qemuAgent.execAndGetOutput('/bin/base64', ['-w', '0', absolutePath]);
          if (base64Str === null || base64Str.includes('No such file') || base64Str.includes('cannot open')) {
            throw new Error(`base64 读取失败: ${absolutePath}`);
          }
          let base64Helper: util.Base64Helper = new util.Base64Helper();
          let bytes: Uint8Array = base64Helper.decodeSync(base64Str) as Uint8Array;

          if (bytes.length === 0) {
            content = '';
            fileExists = true;
            detectedEncoding = 'utf-8';
          } else {
            let encoding: string = this.detectEncoding(bytes);
            detectedEncoding = encoding;
            let decoder: util.TextDecoder = new util.TextDecoder(encoding, { fatal: false });
            content = decoder.decode(bytes);
            fileExists = true;
          }
        } else {
          // 没有 agent，直接使用 qemuFs.readFile（cat）
          console.info('[FileTreeCheck] agent 不可用，降级使用 qemuFs.readFile (cat):', absolutePath);
          let catContent: string | null = await this.qemuFs.readFile(absolutePath);
          if (catContent === null) {
            throw new Error(`cat 读取失败: ${absolutePath}`);
          }
          content = catContent;
          fileExists = true;
          detectedEncoding = 'utf-8';
        }
      } catch (err) {
        // QEMU 读取失败，显示错误，不再降级到宿主模式
        console.error('[FileTreeCheck] QEMU 读取异常:', err);
        let errorMsg: string = `QEMU 读取文件失败: ${absolutePath}\n${err instanceof Error ? err.message : String(err)}`;
        this.editorController.showEmptyState(errorMsg);
        this.statusBarManager.setFileInfo('', '', '');
        this.updateState({ currentFilePath: absolutePath, currentFileType: '', editorContent: '', lastModifiedTime: '' });
        return;
      }
    } else {
      // 宿主模式（仅当 useQemuFs 为 false 或 qemuFs 未就绪时）
      console.info('[FileTreeCheck] 进入宿主读取分支');
      try {
        console.info('[FileTreeCheck] 调用 hostFileService.readFile:', absolutePath);
        content = this.hostFileService.readFile(absolutePath);
        fileExists = true;
        lastModified = this.hostFileService.getLastModifiedTime(absolutePath);
        detectedEncoding = 'utf-8';
        console.info('[FileTreeCheck] 宿主读取成功，内容长度:', content ? content.length : 0, '修改时间:', lastModified);
      } catch (err) {
        console.error('[FileTreeCheck] 宿主读取异常:', err);
        let errorMsg: string = `宿主文件读取失败: ${absolutePath}\n${err instanceof Error ? err.message : String(err)}`;
        console.error('[FileTreeCheck] 显示错误:', errorMsg);
        this.editorController.showEmptyState(errorMsg);
        this.statusBarManager.setFileInfo('', '', '');
        this.updateState({ currentFilePath: absolutePath, currentFileType: '', editorContent: '', lastModifiedTime: '' });
        return;
      }
    }

    let contentStr: string = content ?? '';
    console.info('[FileTreeCheck] 最终内容长度:', contentStr.length, '; 是否为空:', contentStr.length === 0);

    this.editorController.setContent(contentStr, language);
    let displayPath: string = this.getDisplayPath(absolutePath);
    this.statusBarManager.setFileInfo(fileType, displayPath, lastModified);

    if (fileExists && lastModified) {
      this.statusBarManager.setLastModified(lastModified);
    } else {
      let now: string = new Date().toLocaleString('zh-CN', { hour12: false });
      this.statusBarManager.setLastModified(now);
    }

    console.info(`[FileTreeCheck] 编码检测结果: ${detectedEncoding} (${absolutePath})`);

    this.updateState({
      currentFilePath: absolutePath,
      currentFileType: fileType,
      editorContent: contentStr,
      lastModifiedTime: lastModified || new Date().toLocaleString('zh-CN', { hour12: false })
    });

    this.editorController.setReadOnly(false);
    console.info('[FileTreeCheck] loadFileContent 完成');
  }

  async saveCurrentFile(activeTabPath: string, currentFilePath: string): Promise<void> {
    console.info('[FileTreeCheck] saveCurrentFile 入口, activeTabPath:', activeTabPath, 'currentFilePath:', currentFilePath);
    if (!activeTabPath || !currentFilePath || currentFilePath !== activeTabPath) {
      console.warn('[FileTreeCheck] 路径不匹配，跳过保存');
      return;
    }

    let content: string = this.editorController.getCurrentContent();
    let success: boolean = false;

    if (this.useQemuFs && this.qemuFs.isReady()) {
      try {
        console.info('[FileTreeCheck] QEMU 保存文件:', currentFilePath, '内容长度:', content.length);
        success = await this.qemuFs.writeFile(currentFilePath, content);
        if (success) {
          console.info('[FileTreeCheck] QEMU 保存成功');
          let now: string = new Date().toLocaleString('zh-CN', { hour12: false });
          this.statusBarManager.setLastModified(now);
          this.updateState({ lastModifiedTime: now });
        } else {
          console.error('[FileTreeCheck] QEMU 保存失败');
        }
      } catch (err) {
        console.error('[FileTreeCheck] QEMU 保存异常:', err);
      }
    } else {
      try {
        console.info('[FileTreeCheck] 宿主保存文件:', currentFilePath);
        this.hostFileService.writeFile(currentFilePath, content);
        success = true;
        let lastModified: string = this.hostFileService.getLastModifiedTime(currentFilePath);
        this.statusBarManager.setLastModified(lastModified);
        this.updateState({ lastModifiedTime: lastModified });
        console.info('[FileTreeCheck] 宿主保存成功');
      } catch (err) {
        console.error('[FileTreeCheck] 宿主保存失败:', err);
      }
    }

    if (!success) {
      console.warn('[FileTreeCheck] 文件保存未成功');
    }
  }

  showEmptyState(message: string = '未打开任何文件'): void {
    console.info('[FileTreeCheck] showEmptyState:', message);
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
    let workDir: string = this.hostFileService.getWorkDir();
    let displayPath: string = path;
    if (workDir && displayPath.startsWith(workDir)) {
      displayPath = displayPath.substring(workDir.length);
      if (displayPath.startsWith('/')) displayPath = displayPath.substring(1);
    }
    let parts: string[] = displayPath.split('/').filter(p => p !== '');
    if (parts.length === 0) return '';

    let maxFolderLen: number = 15;
    let processed: string[] = parts.map((p: string, index: number): string => {
      if (index === parts.length - 1) {
        return p;
      }
      if (p.length > maxFolderLen) {
        return p.substring(0, maxFolderLen) + '...';
      }
      return p;
    });
    return processed.join(' > ');
  }

  refreshFileTree(): void {
    console.info('[FileTreeCheck] refreshFileTree');
    if (this.useQemuFs && this.qemuFs.isReady()) {
      this.qemuFileTreeService.refresh();
    } else {
      console.warn('[FileTreeCheck] Qemu未就绪或非Qemu模式，无法刷新');
    }
  }

  updateCursor(line: number, col: number): void {
    this.updateState({ currentLine: line, currentColumn: col });
  }

  // ========== 内置编码检测器 ==========
  private detectEncoding(bytes: Uint8Array): string {
    if (bytes.length >= 3 && bytes[0] === 0xEF && bytes[1] === 0xBB && bytes[2] === 0xBF) {
      console.info('[FileTreeCheck] detectEncoding: BOM detected, return utf-8');
      return 'utf-8';
    }
    if (this.isValidUTF8(bytes)) {
      console.info('[FileTreeCheck] detectEncoding: valid UTF-8');
      return 'utf-8';
    }
    let scoreGBK: number = 0;
    let scoreBig5: number = 0;
    for (let i: number = 0; i < bytes.length; i++) {
      let b: number = bytes[i];
      if (b >= 0x81 && b <= 0xFE) {
        if (i + 1 < bytes.length) {
          let next: number = bytes[i + 1];
          if (next >= 0x40 && next <= 0xFE && next !== 0x7F) {
            scoreGBK++;
            if ((next >= 0x40 && next <= 0x7E) || (next >= 0xA1 && next <= 0xFE)) {
              scoreBig5++;
            }
          }
        }
      }
    }
    if (scoreGBK > 0 && scoreGBK > scoreBig5 * 1.2) {
      console.info('[FileTreeCheck] detectEncoding: heuristic GBK');
      return 'gbk';
    } else if (scoreBig5 > 0) {
      console.info('[FileTreeCheck] detectEncoding: heuristic Big5');
      return 'big5';
    }
    console.info('[FileTreeCheck] detectEncoding: fallback utf-8');
    return 'utf-8';
  }

  private isValidUTF8(bytes: Uint8Array): boolean {
    let i: number = 0;
    while (i < bytes.length) {
      let b: number = bytes[i];
      if (b <= 0x7F) {
        i++;
        continue;
      }
      let len: number = 0;
      if ((b & 0xE0) === 0xC0) len = 2;
      else if ((b & 0xF0) === 0xE0) len = 3;
      else if ((b & 0xF8) === 0xF0) len = 4;
      else return false;
      if (i + len > bytes.length) return false;
      for (let j: number = 1; j < len; j++) {
        if ((bytes[i + j] & 0xC0) !== 0x80) return false;
      }
      i += len;
    }
    return true;
  }

  private updateState(data: Partial<StateUpdateData>): void {
    if (this.onStateUpdate) {
      this.onStateUpdate(data as StateUpdateData);
    }
  }
}