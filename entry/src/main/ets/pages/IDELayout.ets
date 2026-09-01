// entry/src/main/ets/pages/IDELayout.ets
import WebTerminal from '../components/WebTerminal';
import { webview } from '@kit.ArkWeb';
import { FileTree, FileNode } from '../components/FileTree';
import { EditorTabs, EditorTab } from '../components/EditorTabs';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';

import { HostFileService } from '../services/HostFileService';
import { FileTreeManager } from '../services/FileTreeManager';
import { TabManager } from '../services/TabManager';
import { EditorController } from '../services/EditorController';
import { StatusBarManager, StatusBarInfo } from '../services/StatusBarManager';

import { QemuAgentManager } from '../lib/QemuAgentManager';
import { QemuFileSystem } from '../lib/QemuFileSystem';
import { QemuAgent } from '../lib/QemuAgent';

@Component
export struct IdeLayout {
  // ---------- UI 状态变量 ----------
  @State isShowSideBar: boolean = true;
  @State fileTreeData: FileNode[] = [];
  @State folderVersion: number = 0;
  @State selectedTreePath: string = '';
  @State openedTabs: EditorTab[] = [];
  @State tabVersion: number = 0;
  @State activeTabPath: string = '';
  @State editorContent: string = '';
  @State currentLine: number = 1;
  @State currentColumn: number = 1;
  @State currentFileType: string = '';
  @State currentFilePath: string = '';
  @State lastModifiedTime: string = '';
  @State currentTime: string = '';
  @State wifiName: string = 'WiFi';
  @State wifiStatus: number = 0;

  @State useQemuFs: boolean = true;
  @State currentQemuPath: string = '/';

  // ---------- 管理器实例 ----------
  private hostFileService: HostFileService = new HostFileService();
  private fileTreeManager: FileTreeManager = new FileTreeManager();
  private tabManager: TabManager = new TabManager();
  private editorController!: EditorController;
  private statusBarManager: StatusBarManager = new StatusBarManager();

  private webController: webview.WebviewController = new webview.WebviewController();
  private qemuFs: QemuFileSystem = new QemuFileSystem();

  // ---------- 生命周期 ----------
  aboutToAppear(): void {
    console.info('======= IDELayout aboutToAppear 开始执行 =======');
    const context = getContext(this) as common.UIAbilityContext;
    this.hostFileService.initializeWorkDirectory(context);
    this.hostFileService.createSampleFiles();

    this.editorController = new EditorController(this.webController);
    this.editorController.onCursorChanged = (line: number, col: number): void => {
      this.currentLine = line;
      this.currentColumn = col;
    };
    this.editorController.onContentChanged = (content: string): void => {
      this.editorContent = content;
    };
    this.editorController.onEditorBlurred = (content: string): void => {
      this.editorContent = content;
      this.saveCurrentFile();
    };

    this.fileTreeManager.onDataChanged = (nodes: FileNode[], version: number): void => {
      this.fileTreeData = nodes;
      this.folderVersion = version;
    };
    const workDir = this.hostFileService.getWorkDir();
    this.fileTreeManager.loadRootDirectory(workDir);

    this.tabManager.onTabsChanged = (tabs: EditorTab[]): void => {
      this.openedTabs = tabs;
      this.tabVersion++;
    };
    this.tabManager.onActiveTabChanged = (path: string): void => {
      this.activeTabPath = path;
      this.selectedTreePath = path;
      if (path) {
        this.loadFileContent(path);
      } else {
        this.showEmptyState();
      }
    };

    this.statusBarManager.onStatusChanged = (info: StatusBarInfo): void => {
      this.currentTime = info.currentTime;
      this.wifiName = info.wifiName;
      this.wifiStatus = info.wifiStatus;
    };
    this.statusBarManager.startTimer();

    const defaultFile = workDir + '/src/main.ets';
    try {
      this.hostFileService.readFile(defaultFile);
      setTimeout((): void => {
        this.tabManager.openFile(defaultFile);
      }, 300);
    } catch (e) {
      console.warn('⚠️ 默认示例文件不存在:', defaultFile);
      const fallbackFile = workDir + '/README.md';
      try {
        this.hostFileService.readFile(fallbackFile);
        setTimeout((): void => {
          this.tabManager.openFile(fallbackFile);
        }, 300);
      } catch (e2) {
        console.warn('⚠️ 没有找到任何示例文件');
      }
    }

    console.info('准备获取 QemuAgent...');
    this.acquireAgentWithRetry();
  }

  aboutToDisappear(): void {
    this.statusBarManager.stopTimer();
    this.saveCurrentFile();
    QemuAgentManager.release('IDELayout')
      .catch((err: Error) => console.error('[IDELayout] release agent error:', err));
  }

  // ---------- Qemu Agent 重试获取（强制每次重新连接） ----------
  private acquireAgentWithRetry(maxRetries: number = 30, delayMs: number = 2000): void {
    let attempt = 0;
    const tryAcquire = (): void => {
      attempt++;
      console.info(`[IDELayout] 尝试获取 QemuAgent (${attempt}/${maxRetries})...`);

      QemuAgentManager.release('IDELayout')
        .catch(() => {})
        .finally(() => {
          QemuAgentManager.acquire('IDELayout')
            .then((agent: QemuAgent | null) => {
              if (agent) {
                this.qemuFs.bindAgent(agent);
                console.info(`[IDELayout] ✅ QemuAgent 获取成功 (尝试 ${attempt} 次)`);
                if (this.useQemuFs) {
                  this.loadFileTreeFromQemu('/');
                }
                return;
              } else {
                console.warn(`[IDELayout] agent 为 null (尝试 ${attempt}/${maxRetries})，${delayMs}ms 后重试...`);
                if (attempt < maxRetries) {
                  setTimeout(tryAcquire, delayMs);
                } else {
                  console.error(`[IDELayout] ❌ 经过 ${maxRetries} 次尝试，仍无法获取 QemuAgent`);
                  promptAction.showToast({
                    message: '无法连接到虚拟机 QGA，请检查虚拟机状态',
                    duration: 3000
                  });
                }
              }
            })
            .catch((err: Error) => {
              console.error(`[IDELayout] acquire 异常 (尝试 ${attempt}/${maxRetries}):`, err);
              if (attempt < maxRetries) {
                setTimeout(tryAcquire, delayMs);
              }
            });
        });
    };

    tryAcquire();
  }

  // ---------- Qemu 文件树加载 ----------
  private async loadFileTreeFromQemu(path: string = '/'): Promise<void> {
    if (!this.qemuFs.isReady()) {
      console.warn('[IDELayout] QemuAgent 未就绪，无法加载 Qemu 文件树');
      return;
    }
    try {
      const nodes: FileNode[] = await this.qemuFs.listDirectory(path);
      console.info('[IDELayout] Qemu 文件树加载完成，节点数:', nodes.length);
      this.fileTreeData = nodes;
      this.folderVersion++;
      this.currentQemuPath = path;
    } catch (err) {
      console.error('[IDELayout] 加载 Qemu 文件树失败:', err);
    }
  }

  // ---------- Qemu 目录切换 ----------
  private toggleQemuDirectory(path: string): void {
    const updateNode = (nodes: FileNode[]): boolean => {
      for (const node of nodes) {
        if (node.path === path) {
          node.isExpanded = !node.isExpanded;
          if (node.isExpanded && (!node.children || node.children.length === 0)) {
            this.qemuFs.listDirectory(path).then((children: FileNode[]): void => {
              if (children) {
                node.children = children;
                this.fileTreeData = [...this.fileTreeData];
                this.folderVersion++;
              }
            }).catch((err: Error): void => {
              console.error('[IDELayout] 加载子目录失败:', path, err);
            });
          }
          return true;
        }
        if (node.children && node.children.length > 0) {
          if (updateNode(node.children)) return true;
        }
      }
      return false;
    };
    const newData: FileNode[] = [...this.fileTreeData];
    updateNode(newData);
    this.fileTreeData = newData;
    this.folderVersion++;
  }

  // ---------- UI 事件处理 ----------
  private handleDirToggle(path: string): void {
    if (this.useQemuFs && this.qemuFs.isReady()) {
      this.toggleQemuDirectory(path);
    } else {
      this.fileTreeManager.toggleDirectory(path);
    }
  }

  private onFileClick(path: string): void {
    if (this.useQemuFs && this.qemuFs.isReady()) {
      console.warn('[IDELayout] Qemu 文件打开功能尚未实现');
      promptAction.showToast({
        message: 'Qemu 文件打开功能开发中',
        duration: 2000
      });
      return;
    }
    this.tabManager.openFile(path);
  }

  private onDirToggle(path: string): void {
    this.handleDirToggle(path);
  }

  private onTabSwitch(path: string): void {
    this.tabManager.switchTab(path);
  }

  private onTabClose(path: string): void {
    const newActive: string | undefined = this.tabManager.closeTab(path);
    if (!newActive) {
      this.showEmptyState();
    }
  }

  private triggerLayout(): void {
    this.editorController.triggerLayout();
  }

  // ---------- 核心业务方法 ----------
  private loadFileContent(path: string): void {
    console.info('📂 loadFileContent:', path);
    if (!path) {
      this.showEmptyState();
      return;
    }
    this.currentFilePath = path;

    const ext: string = path.split('.').pop()?.toLowerCase() || '';
    const typeMap: Record<string, string> = {
      'ets': 'ArkTS', 'ts': 'TypeScript', 'js': 'JavaScript',
      'json': 'JSON', 'html': 'HTML', 'css': 'CSS',
      'xml': 'XML', 'py': 'Python', 'java': 'Java',
      'c': 'C', 'cpp': 'C++', 'go': 'Go', 'md': 'Markdown', 'txt': 'Text'
    };
    this.currentFileType = typeMap[ext] || 'Plain Text';

    let content: string = '';
    let fileExists: boolean = false;
    try {
      content = this.hostFileService.readFile(path);
      fileExists = true;
      console.info('✅ 真实文件读取成功:', path, 'length=' + content.length);
    } catch (err) {
      console.warn('⚠️ 真实文件读取失败，使用示例内容:', path);
      content = this.hostFileService.getDemoContent(path);
    }

    this.editorContent = content;
    const language: string = EditorController.getLanguageFromPath(path);
    this.editorController.setContent(content, language);

    if (fileExists) {
      this.lastModifiedTime = this.hostFileService.getLastModifiedTime(path);
    } else {
      this.lastModifiedTime = '';
    }

    this.statusBarManager.setFileInfo(this.currentFileType, this.getDisplayPath(), this.lastModifiedTime);
  }

  private saveCurrentFile(): void {
    if (!this.activeTabPath || !this.currentFilePath || this.currentFilePath !== this.activeTabPath) {
      return;
    }
    try {
      const content: string = this.editorController.getCurrentContent();
      this.hostFileService.writeFile(this.currentFilePath, content);
      this.lastModifiedTime = this.hostFileService.getLastModifiedTime(this.currentFilePath);
      this.statusBarManager.setLastModified(this.lastModifiedTime);
      console.info('💾 文件保存成功:', this.currentFilePath);
    } catch (err) {
      console.error('❌ 保存文件失败:', err);
    }
  }

  private showEmptyState(): void {
    const content: string = '// 点击左侧文件树中的文件开始编辑';
    this.currentFilePath = '';
    this.currentFileType = '';
    this.lastModifiedTime = '';
    this.editorContent = content;
    this.editorController.setContent(content, 'typescript');
    this.statusBarManager.setFileInfo('', '', '');
  }

  private getDisplayPath(): string {
    if (!this.currentFilePath) return '';
    let path: string = this.currentFilePath;
    const workDir: string = this.hostFileService.getWorkDir();
    if (workDir && path.startsWith(workDir)) {
      path = path.substring(workDir.length);
      if (path.startsWith('/')) path = path.substring(1);
    }
    const parts: string[] = path.split('/').filter((p: string) => p !== '');
    if (parts.length === 0) return '';
    if (parts.length > 3) return '... > ' + parts.slice(-3).join(' > ');
    return parts.join(' > ');
  }

  // ---------- UI 构建 ----------
  build() {
    Column() {
      Row() {
        if (this.isShowSideBar) {
          Column() {
            Row() {
              Text('📂 文件')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#cccccc')
                .padding({ left: 12, right: 12 })
            }
            .width('100%')
            .height(36)
            .backgroundColor('#252525')
            .alignItems(VerticalAlign.Center)

            FileTree({
              rootNodes: this.fileTreeData,
              selectedPath: this.selectedTreePath,
              version: this.folderVersion,
              onFileClick: (path: string) => { this.onFileClick(path); },
              onDirToggle: (path: string) => { this.onDirToggle(path); }
            })
              .width('100%')
              .layoutWeight(1)
              .backgroundColor('#1e1e1e')
          }
          .width(240)
          .height('100%')
          .backgroundColor('#1e1e1e')
        }

        Column()
          .width(6)
          .height('100%')
          .backgroundColor('#3a3a3a')

        Column() {
          Row() {
            Text('☰')
              .fontSize(18)
              .fontColor('#cccccc')
              .padding({ left: 10, right: 8 })
              .onClick(() => { this.isShowSideBar = !this.isShowSideBar; })

            EditorTabs({
              tabs: this.openedTabs,
              version: this.tabVersion,
              onTabSwitch: (path: string) => { this.onTabSwitch(path); },
              onTabClose: (path: string) => { this.onTabClose(path); }
            })
              .layoutWeight(1)
              .height(36)
          }
          .width('100%')
          .height(36)
          .backgroundColor('#252525')
          .padding({ left: 4, right: 4 })

          Column() {
            Column() {
              Web({
                src: $rawfile('monaco_editor.html'),
                controller: this.webController
              })
                .width('100%')
                .height('100%')
                .javaScriptAccess(true)
                .zoomAccess(false)
                .javaScriptProxy({
                  permission: `{
                    "javascriptProxyPermission": {
                      "urlPermissionList": [
                        { "scheme": "https", "host": "cdnjs.cloudflare.com", "port": "", "path": "" },
                        { "scheme": "resource", "host": "rawfile", "port": "", "path": "" }
                      ]
                    }
                  }`,
                  object: this.editorController.getArkTSService(),
                  name: 'arkTSService',
                  methodList: ['onEditorReady', 'onContentChange', 'onCursorChange', 'onEditorBlur', 'log'],
                  controller: this.webController
                })
                .onPageEnd(() => {
                  console.info('🌐 Monaco HTML 加载完成');
                  setTimeout((): void => {
                    if (this.activeTabPath) {
                      this.loadFileContent(this.activeTabPath);
                    } else {
                      this.showEmptyState();
                    }
                    this.triggerLayout();
                  }, 500);
                })
                .onErrorReceive((event: ESObject) => {
                  let errorInfo: string = '未知错误';
                  try {
                    const e = event as Record<string, ESObject>;
                    if (typeof e.getErrorInfo === 'function') errorInfo = String(e.getErrorInfo());
                    else if (typeof e.errorInfo === 'string') errorInfo = e.errorInfo;
                    else if (typeof e.message === 'string') errorInfo = e.message;
                  } catch (e) { errorInfo = String(event); }
                  console.error('❌ WebView 错误:', errorInfo);
                })
                .onSizeChange(() => { this.triggerLayout(); })
            }
            .width('100%')
            .layoutWeight(7)
            .backgroundColor('#1a1a1a')
            .padding({ top: 4 })

            Column() {
              Divider()
                .height(2)
                .backgroundColor('#3a3a3c')
                .width('100%')
            }
            .width('100%')
            .height(2)

            Column() {
              WebTerminal({ virtKeyEnabled: false })
            }
            .width('100%')
            .layoutWeight(3)
            .backgroundColor('#0d0d0d')
            .padding({ left: 8 })
          }
          .width('100%')
          .layoutWeight(1)
          .padding(0)
        }
        .layoutWeight(1)
        .height('100%')
        .backgroundColor('#1e1e1e')
        .padding(0)
      }
      .width('100%')
      .height('100%')
      .layoutWeight(1)

      this.buildStatusBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1e1e1e')
  }

  @Builder
  buildStatusBar() {
    Row() {
      Row() {
        Text('行 ' + this.currentLine).fontSize(12).fontColor('#cccccc')
        Text('列 ' + this.currentColumn).fontSize(12).fontColor('#cccccc').margin({ left: 10 })
        if (this.currentFileType) {
          Text(this.currentFileType).fontSize(12).fontColor('#cccccc').margin({ left: 10 })
        }
        Text('UTF-8').fontSize(12).fontColor('#cccccc').margin({ left: 10 })
        Text(this.getDisplayPath())
          .fontSize(12)
          .fontColor('#cccccc')
          .margin({ left: 10 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .flexShrink(1)
      }
      .padding({ left: 16 })
      .height('100%')
      .alignItems(VerticalAlign.Center)
      .flexShrink(1)

      Blank()

      Row() {
        Row() {
          Text(this.wifiName).fontSize(12).fontColor('#cccccc').margin({ right: 4 })
          Circle()
            .width(8)
            .height(8)
            .fill(this.wifiStatus === 0 ? '#00ff00' : (this.wifiStatus === 1 ? '#f1c40f' : '#ff0000'))
        }
        .margin({ right: 12 })
        .flexShrink(0)

        Text() {
          Span(this.currentTime)
            .fontWeight(FontWeight.Bold)
            .fontSize(12)
            .fontColor('#ffffff')
          Span(' / ')
            .fontSize(12)
            .fontColor('#cccccc')
          Span(this.lastModifiedTime || '未保存')
            .fontSize(12)
            .fontColor('#888888')
        }
        .margin({ right: 12 })
        .flexShrink(0)

        Text('LF').fontSize(12).fontColor('#cccccc').flexShrink(0)
      }
      .padding({ right: 16 })
      .height('100%')
      .alignItems(VerticalAlign.Center)
      .flexShrink(0)
    }
    .width('100%')
    .height(28)
    .backgroundColor('#2d2d2d')
    .padding(0)
  }
}