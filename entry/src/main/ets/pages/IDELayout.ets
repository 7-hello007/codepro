// entry/src/main/ets/pages/IDELayout.ets
import WebTerminal from '../components/WebTerminal';
import { webview } from '@kit.ArkWeb';
import { FileTree, FileNode } from '../components/FileTree';
import { EditorTabs, EditorTab } from '../components/EditorTabs';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import { CreateDialog } from '../components/CreateDialog';

import { HostFileService } from '../services/HostFileService';
import { FileTreeManager } from '../services/FileTreeManager';
import { TabManager } from '../services/TabManager';
import { EditorController } from '../services/EditorController';
import { StatusBarManager, StatusBarInfo } from '../services/StatusBarManager';
import { FileTreePollingService } from '../services/FileTreePollingService';
import { QemuFileTreeService } from '../services/QemuFileTreeService';
import { QemuContextMenuManager } from '../services/QemuContextMenuManager';
import { QemuCoordinator } from '../services/QemuCoordinator';
import { FileOperationManager } from '../services/FileOperationManager';

import { QemuAgentManager } from '../lib/QemuAgentManager';
import { QemuFileSystem } from '../lib/QemuFileSystem';

import { OpenFolderDialog } from '../components/OpenFolderDialog';
import { PluginManager } from '../plugin/PluginManager';
import { PluginContext } from '../plugin/IPlugin';

import { util } from '@kit.ArkTS';
import preferences from '@ohos.data.preferences';

// 运行配置接口
interface RunConfig {
  extensions: string[];
}

@Component
export struct IdeLayout {

  // ============================================================
  // UI 状态
  // ============================================================

  @State isShowSideBar: boolean = true;
  @State fileTreeData: FileNode[] = [];
  @State folderVersion: number = 0;
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
  @State isOperationInProgress: boolean = false;
  @State operationMessage: string = '';
  @State currentRootPath: string = '/';
  @State showRunButton: boolean = false;

  // 布局模式
  @State layoutMode: 'vscode' | 'terminal-full' = 'vscode';

  // ===== 新增：QEMU 连接状态（自动更新 UI）=====
  @State isQemuReady: boolean = false;

  // ============================================================
  // Dialog
  // ============================================================

  private dialogController: CustomDialogController | null = null;
  private dialogType: 'file' | 'folder' = 'file';
  private dialogParentPath: string = '';
  private openFolderDialogController: CustomDialogController | null = null;

  // ============================================================
  // Service
  // ============================================================

  private hostFileService: HostFileService = new HostFileService();
  private fileTreeManager: FileTreeManager = new FileTreeManager();
  private tabManager: TabManager = new TabManager();
  private editorController!: EditorController;
  private statusBarManager: StatusBarManager = new StatusBarManager();
  private pollingService: FileTreePollingService = new FileTreePollingService();
  private qemuFileTreeService: QemuFileTreeService = new QemuFileTreeService();
  private qemuContextMenuManager: QemuContextMenuManager = new QemuContextMenuManager();
  private qemuCoordinator: QemuCoordinator = new QemuCoordinator();
  private fileOperationManager!: FileOperationManager;

  private webController: webview.WebviewController = new webview.WebviewController();
  private qemuFs: QemuFileSystem = new QemuFileSystem();

  private runExtensions: Set<string> = new Set();

  // ============================================================
  // QEMU 状态
  // ============================================================

  private expandedPaths: Set<string> = new Set();
  private isProcessingRefresh: boolean = false;

  private connectionPollingTimer: number | null = null;

  // ============================================================
  // 生命周期
  // ============================================================

  aboutToAppear(): void {
    const context = getContext(this) as common.UIAbilityContext;
    this.hostFileService.initializeWorkDirectory(context);
    this.initEditor();
    this.initFileOperationManager();
    this.initFileTreeManager();
    this.initTabManager();
    this.initStatusBar();
    this.loadFallbackFileTree();
    this.openDefaultFile();
    this.initQemuServices();
    this.initPollingCallbacks();
    this.initOpenFolderDialog();
    this.qemuCoordinator.start();
    // 初始化插件管理器
    const pluginManager = PluginManager.getInstance();
    pluginManager.initDefaultPlugins();

    // 加载运行配置
    this.loadRunConfig();

    // 恢复布局模式
    this.restoreLayoutMode();

    // ===== 新增：初始设置为未连接 =====
    this.isQemuReady = false;
  }

  aboutToDisappear(): void {
    this.statusBarManager.stopTimer();
    this.fileOperationManager.saveCurrentFile(this.activeTabPath, this.currentFilePath);
    this.pollingService.stop();
    this.qemuCoordinator.stop();
    QemuAgentManager.release('IDELayout').catch(() => {});
    if (this.dialogController) this.dialogController.close();
    if (this.openFolderDialogController) this.openFolderDialogController.close();

    // 保存布局模式
    this.saveLayoutMode();

    // ===== 清理连接状态轮询定时器 =====
    if (this.connectionPollingTimer !== null) {
      clearInterval(this.connectionPollingTimer);
      this.connectionPollingTimer = null;
    }

    // ===== 新增：断开连接时重置状态 =====
    this.isQemuReady = false;
  }

  // ============================================================
  // Editor 初始化
  // ============================================================

  private initEditor(): void {
    this.editorController = new EditorController(this.webController);
    this.editorController.onCursorChanged = (line, col) => {
      this.currentLine = line;
      this.currentColumn = col;
    };
    this.editorController.onContentChanged = (content) => {
      this.editorContent = content;
    };
    this.editorController.onEditorBlurred = (content) => {
      this.editorContent = content;
      this.fileOperationManager.saveCurrentFile(this.activeTabPath, this.currentFilePath);
    };
  }

  // ============================================================
  // FileOperationManager 初始化
  // ============================================================

  private initFileOperationManager(): void {
    this.fileOperationManager = new FileOperationManager(
      this.hostFileService,
      this.tabManager,
      this.editorController,
      this.statusBarManager,
      this.qemuFileTreeService,
      this.qemuFs,
      this.useQemuFs
    );
    this.fileOperationManager.onStateUpdate = (data) => {
      if (data.currentFilePath !== undefined) this.currentFilePath = data.currentFilePath;
      if (data.currentFileType !== undefined) this.currentFileType = data.currentFileType;
      if (data.editorContent !== undefined) this.editorContent = data.editorContent;
      if (data.lastModifiedTime !== undefined) this.lastModifiedTime = data.lastModifiedTime;
      if (data.currentLine !== undefined) this.currentLine = data.currentLine;
      if (data.currentColumn !== undefined) this.currentColumn = data.currentColumn;
    };
  }

  // ============================================================
  // FileTreeManager 初始化
  // ============================================================

  private initFileTreeManager(): void {
    this.fileTreeManager.onDataChanged = (nodes, version) => {
      if (!this.useQemuFs || !this.qemuFs.isReady()) {
        this.fileTreeData = nodes;
        this.folderVersion = version;
      }
    };
  }

  // ============================================================
  // TabManager 初始化
  // ============================================================

  private initTabManager(): void {
    this.tabManager.onTabsChanged = (tabs) => {
      this.openedTabs = tabs;
      this.tabVersion++;
    };

    this.tabManager.onActiveTabChanged = (path) => {
      const normalizedPath = this.normalizePath(path);
      console.info('[IDELayout] Tab 切换到:', normalizedPath);

      this.activeTabPath = normalizedPath;

      this.fileTreeData = [...this.fileTreeData];
      this.folderVersion++;

      if (path) {
        this.fileOperationManager.loadFileContent(path);
      } else {
        this.fileOperationManager.showEmptyState('未打开任何文件');
      }

      // 更新运行按钮
      this.updateRunButtonVisibility(path);
    };
  }

  // ============================================================
  // StatusBar
  // ============================================================

  private initStatusBar(): void {
    this.statusBarManager.onStatusChanged = (info: StatusBarInfo) => {
      this.currentTime = info.currentTime;
      this.wifiName = info.wifiName;
      this.wifiStatus = info.wifiStatus;
      this.isOperationInProgress = info.isOperationInProgress;
      this.operationMessage = info.operationMessage;
    };
    this.statusBarManager.startTimer();
  }

  // ============================================================
  // Host 文件树（后备）
  // ============================================================

  private loadFallbackFileTree(): void {
    const workDir = this.hostFileService.getWorkDir();
    this.fileTreeManager.loadRootDirectory(workDir);
  }

  private openDefaultFile(): void {
    if (this.useQemuFs) return;
  }

  // ============================================================
  // QEMU Service 初始化
  // ============================================================

  private initQemuServices(): void {
    this.qemuFileTreeService.bindFileSystem(this.qemuFs);
    // 加载根目录
    this.qemuFileTreeService.loadRootDirectory('/');

    this.qemuFileTreeService.onDataChanged = (nodes, version) => {
      if (this.isProcessingRefresh) return;
      this.isProcessingRefresh = true;
      this.normalizeNodePaths(nodes);
      this.processFileTreeRefresh(nodes, version).then(() => {
        this.isProcessingRefresh = false;
      }).catch(() => {
        this.isProcessingRefresh = false;
        this.fileTreeData = nodes;
        this.folderVersion = version;
      });
    };

    this.qemuContextMenuManager.bindFileSystem(this.qemuFs);
    this.qemuContextMenuManager.bindStatusBarManager(this.statusBarManager);
    this.qemuContextMenuManager.setRefreshCallback(() => this.fileOperationManager.refreshFileTree());
    this.qemuContextMenuManager.onShowCreateDialog = (parentPath, type) => {
      this.dialogParentPath = parentPath;
      this.dialogType = type;
      this.showCreateDialog();
    };
    this.qemuContextMenuManager.onShowDeleteDialog = (path, isDir) => {
      this.showDeleteConfirm(path, isDir);
    };

    this.qemuCoordinator.bindServices(this.qemuFs, this.qemuFileTreeService, this.pollingService);
    // ===== 新增：连接成功时更新状态 =====
    this.qemuCoordinator.setOnReady(() => {
      if (!this.activeTabPath) {
        this.fileOperationManager.showEmptyState('未打开任何文件');
      }
      // 标记已连接，UI 自动更新
      this.isQemuReady = true;
    });

    this.startConnectionPolling();
  }

  // ============================================================
  // 打开文件夹对话框初始化
  // ============================================================

  private initOpenFolderDialog(): void {
    this.openFolderDialogController = new CustomDialogController({
      builder: OpenFolderDialog({
        onConfirm: (path: string) => {
          this.changeRootDirectory(path);
        }
      })
    });
  }

  // ============================================================
  // 切换文件树根目录
  // ============================================================

  private changeRootDirectory(newPath: string): void {
    if (!this.useQemuFs || !this.qemuFs.isReady()) {
      promptAction.showToast({ message: 'Qemu 未就绪', duration: 1000 });
      return;
    }
    const normalized = this.normalizePath(newPath);
    if (!normalized.startsWith('/')) {
      promptAction.showToast({ message: '请输入绝对路径（以 / 开头）', duration: 1000 });
      return;
    }
    this.expandedPaths.clear();
    this.fileTreeData = [];
    this.folderVersion++;
    this.currentRootPath = normalized;
    this.qemuFileTreeService.loadRootDirectory(normalized);
    this.pollingService.setCurrentPath(normalized);
    promptAction.showToast({ message: `切换到 ${normalized}`, duration: 1000 });
  }

  // ============================================================
  // 构建文件菜单
  // ============================================================

  @Builder
  buildFileMenu() {
    Menu() {
      MenuItem({ content: '📂 打开文件夹' })
        .onClick(() => {
          this.openFolderDialogController?.open();
        })
      MenuItem({ content: '🔌 插件' })
        .onClick(() => {
          promptAction.showToast({ message: '插件功能开发中', duration: 1000 });
        })
    }
  }

  // ============================================================
  // 路径规范化工具
  // ============================================================

  private normalizePath(path: string): string {
    if (!path) return '';
    return path.replace(/\/+/g, '/');
  }

  private normalizeNodePaths(nodes: FileNode[]): void {
    for (const node of nodes) {
      node.path = this.normalizePath(node.path);
      if (node.children) {
        this.normalizeNodePaths(node.children);
      }
    }
  }

  // ============================================================
  // QEMU 文件树刷新
  // ============================================================

  private async processFileTreeRefresh(nodes: FileNode[], version: number): Promise<void> {
    const processedNodes = JSON.parse(JSON.stringify(nodes)) as FileNode[];
    this.normalizeNodePaths(processedNodes);
    await this.restoreExpandedState(processedNodes);
    this.fileTreeData = processedNodes;
    this.folderVersion = version;
    console.info('[IDELayout] 文件树刷新完成, folderVersion:', this.folderVersion);
  }

  // ============================================================
  // 恢复目录展开状态
  // ============================================================

  private async restoreExpandedState(nodes: FileNode[]): Promise<void> {
    for (const node of nodes) {
      if (this.expandedPaths.has(node.path)) {
        node.isExpanded = true;
        try {
          const children = await this.qemuFileTreeService.loadChildren(node.path);
          if (children && children.length > 0) {
            node.children = children;
            this.normalizeNodePaths(children);
            await this.restoreExpandedState(children);
          } else {
            node.children = [];
          }
        } catch {
          node.children = [];
        }
      } else {
        node.isExpanded = false;
        if (node.children && node.children.length > 0) {
          await this.restoreExpandedState(node.children);
        }
      }
    }
  }

  // ============================================================
  // 新建文件
  // ============================================================

  private addNewFileToTree(parentPath: string, fileName: string): void {
    const newFilePath = this.normalizePath(parentPath + '/' + fileName);
    const parentNode = this.findNode(this.fileTreeData, parentPath);
    if (!parentNode) return;
    if (!parentNode.isExpanded) {
      parentNode.isExpanded = true;
      this.expandedPaths.add(parentPath);
    }
    if (!parentNode.children) parentNode.children = [];
    if (!parentNode.children.some(child => child.path === newFilePath)) {
      parentNode.children.push({
        name: fileName,
        path: newFilePath,
        isDir: false,
        isExpanded: false,
        children: []
      });
    }
    this.tabManager.openFile(newFilePath);
  }

  // ============================================================
  // 新建文件夹
  // ============================================================

  private addNewFolderToTree(parentPath: string, folderName: string): void {
    const newFolderPath = this.normalizePath(parentPath + '/' + folderName);
    const parentNode = this.findNode(this.fileTreeData, parentPath);
    if (!parentNode) return;
    if (!parentNode.isExpanded) {
      parentNode.isExpanded = true;
      this.expandedPaths.add(parentPath);
    }
    if (!parentNode.children) parentNode.children = [];
    if (!parentNode.children.some(child => child.path === newFolderPath)) {
      parentNode.children.push({
        name: folderName,
        path: newFolderPath,
        isDir: true,
        isExpanded: false,
        children: []
      });
    }
    this.fileTreeData = [...this.fileTreeData];
    this.folderVersion++;
  }

  // ============================================================
  // 查找文件树节点
  // ============================================================

  private findNode(nodes: FileNode[], path: string): FileNode | null {
    const normPath = this.normalizePath(path);
    for (const node of nodes) {
      if (this.normalizePath(node.path) === normPath) {
        return node;
      }
      if (node.children) {
        const result = this.findNode(node.children, normPath);
        if (result) return result;
      }
    }
    return null;
  }

  // ============================================================
  // 创建 Dialog
  // ============================================================

  private showCreateDialog(): void {
    this.dialogController = new CustomDialogController({
      builder: CreateDialog({
        dialogType: this.dialogType,
        dialogParentPath: this.dialogParentPath,
        inputValue: '',
        onConfirm: (name) => {
          this.qemuContextMenuManager.executeCreate(this.dialogParentPath, name, this.dialogType)
            .then((success) => {
              if (success) {
                promptAction.showToast({ message: '创建成功', duration: 1000 });
                if (this.dialogType === 'file') {
                  this.addNewFileToTree(this.dialogParentPath, name);
                } else {
                  this.addNewFolderToTree(this.dialogParentPath, name);
                }
                this.fileOperationManager.refreshFileTree();
              } else {
                promptAction.showToast({ message: '创建失败', duration: 1000 });
              }
            })
            .catch(() => {
              promptAction.showToast({ message: '创建失败', duration: 1000 });
            });
        }
      })
    });
    this.dialogController.open();
  }

  // ============================================================
  // 删除确认
  // ============================================================

  private showDeleteConfirm(path: string, isDir: boolean): void {
    const type = isDir ? '文件夹' : '文件';
    promptAction.showDialog({
      title: '确认删除',
      message: `确定要删除 ${type} "${path}" 吗？`,
      buttons: [{ text: '取消', color: '#666666' }, { text: '删除', color: '#ff3b30' }]
    })
      .then((data) => {
        if (data.index === 1) {
          this.qemuContextMenuManager.executeDelete(path).then((success) => {
            if (success) {
              promptAction.showToast({ message: '删除成功', duration: 1000 });
              const normPath = this.normalizePath(path);
              if (this.activeTabPath === normPath) {
                this.tabManager.closeTab(normPath);
              }
              this.fileOperationManager.refreshFileTree();
            } else {
              promptAction.showToast({ message: '删除失败', duration: 1000 });
            }
          });
        }
      })
      .catch(() => {});
  }

  // ============================================================
  // 文件树轮询
  // ============================================================

  private initPollingCallbacks(): void {
    this.pollingService.onDirectoryChanged = (nodes) => {
      this.normalizeNodePaths(nodes);
      this.fileTreeData = nodes;
      this.folderVersion++;
      console.info('[IDELayout] 轮询更新文件树, folderVersion:', this.folderVersion);
    };
    this.pollingService.onError = () => {};
  }

  // ============================================================
  // 文件夹切换
  // ============================================================

  private handleDirToggle(path: string): void {
    if (this.useQemuFs && this.qemuFs.isReady()) {
      this.toggleQemuDirectory(path);
    } else {
      this.fileTreeManager.toggleDirectory(path);
    }
  }

  // ============================================================
  // QEMU 文件夹展开/收起
  // ============================================================

  private toggleQemuDirectory(path: string): void {
    const normPath = this.normalizePath(path);
    const findAndToggle = (nodes: FileNode[]): boolean => {
      for (const node of nodes) {
        if (node.path === normPath) {
          node.isExpanded = !node.isExpanded;
          if (node.isExpanded) {
            this.expandedPaths.add(normPath);
            if (!node.children || node.children.length === 0) {
              this.qemuFileTreeService.loadChildren(normPath).then((children) => {
                if (children && children.length > 0) {
                  this.normalizeNodePaths(children);
                  node.children = children;
                  this.fileTreeData = [...this.fileTreeData];
                  this.folderVersion++;
                }
              }).catch(() => {});
            }
          } else {
            this.expandedPaths.delete(normPath);
          }
          return true;
        }
        if (node.children && node.children.length > 0) {
          if (findAndToggle(node.children)) return true;
        }
      }
      return false;
    };
    const newData = [...this.fileTreeData];
    findAndToggle(newData);
    this.fileTreeData = newData;
    this.folderVersion++;
  }

  // ============================================================
  // 文件点击
  // ============================================================

  private onFileClick(path: string): void {
    const normPath = this.normalizePath(path);
    console.info('[IDELayout] 点击文件:', normPath);
    this.tabManager.openFile(normPath);
  }

  // ============================================================
  // 文件夹点击
  // ============================================================

  private onDirToggle(path: string): void {
    this.handleDirToggle(path);
  }

  // ============================================================
  // 右键 / 长按
  // ============================================================

  private onFileRightClick(path: string, isDir: boolean): void {
    this.qemuContextMenuManager.showContextMenu(path, isDir);
  }

  // ============================================================
  // Tab 切换
  // ============================================================

  private onTabSwitch(path: string): void {
    this.tabManager.switchTab(path);
  }

  // ============================================================
  // Tab 关闭
  // ============================================================

  private onTabClose(path: string): void {
    const newActive = this.tabManager.closeTab(path);
    if (!newActive) {
      this.activeTabPath = '';
      this.fileOperationManager.showEmptyState('未打开任何文件');
      this.showRunButton = false;
    }
  }

  /**
   * 处理运行按钮点击
   */
  private async handleRun(filePath: string): Promise<void> {
    try {
      const pluginManager = PluginManager.getInstance();
      const plugin = pluginManager.findPlugin(filePath);
      if (!plugin) {
        promptAction.showToast({ message: '没有可用的插件处理此文件' });
        return;
      }

      const context: PluginContext = {
        agent: this.qemuFs,
        fileSystem: this.qemuFs,
      };

      await plugin.activate(context, filePath);
      promptAction.showToast({ message: `插件 ${plugin.name} 执行成功` });
    } catch (error) {
      console.error('Run plugin error:', error);
      promptAction.showToast({ message: `运行失败: ${(error as Error).message || '未知错误'}` });
    }
  }

  // ============================================================
  // 运行配置加载与显示控制
  // ============================================================

  private async loadRunConfig(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const rawFile = await context.resourceManager.getRawFileContent('run_config.json');
      const decoder = new util.TextDecoder('utf-8');
      const jsonStr = decoder.decode(rawFile);
      const config = JSON.parse(jsonStr) as RunConfig;
      if (config.extensions && Array.isArray(config.extensions)) {
        this.runExtensions = new Set(config.extensions);
        console.info('[RunConfig] 加载成功，扩展名列表:', Array.from(this.runExtensions));
      } else {
        console.warn('[RunConfig] 配置格式错误，使用默认空集合');
      }
    } catch (e) {
      console.error('[RunConfig] 加载失败:', e);
    }
    this.updateRunButtonVisibility(this.activeTabPath);
  }

  private updateRunButtonVisibility(filePath: string): void {
    if (!filePath) {
      this.showRunButton = false;
      return;
    }
    const ext = this.getFileExtension(filePath);
    const shouldShow = this.runExtensions.has(ext);
    if (this.showRunButton !== shouldShow) {
      this.showRunButton = shouldShow;
    }
  }

  private getFileExtension(path: string): string {
    const lastDot = path.lastIndexOf('.');
    if (lastDot === -1) return '';
    return path.substring(lastDot).toLowerCase();
  }

  // ============================================================
  // 布局切换
  // ============================================================

  private async saveLayoutMode(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const pref = await preferences.getPreferences(context, 'ide_settings');
      await pref.put('layoutMode', this.layoutMode);
      await pref.flush();
      console.info('[Layout] 保存模式:', this.layoutMode);
    } catch (e) {
      console.error('[Layout] 保存失败:', e);
    }
  }

  private async restoreLayoutMode(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const pref = await preferences.getPreferences(context, 'ide_settings');
      const mode = await pref.get('layoutMode', 'vscode') as string;
      if (mode === 'vscode' || mode === 'terminal-full') {
        this.layoutMode = mode;
        console.info('[Layout] 恢复模式:', this.layoutMode);
      }
    } catch (e) {
      console.error('[Layout] 恢复失败:', e);
    }
  }

  private toggleLayoutMode(): void {
    const newMode = this.layoutMode === 'vscode' ? 'terminal-full' : 'vscode';
    this.layoutMode = newMode;
    this.saveLayoutMode();
  }

  // ============================================================
  // 连接状态轮询（新增）
  // ============================================================

  private startConnectionPolling(): void {
    // 清除旧定时器
    if (this.connectionPollingTimer !== null) {
      clearInterval(this.connectionPollingTimer);
      this.connectionPollingTimer = null;
    }

    this.connectionPollingTimer = setInterval(() => {
      const ready = this.qemuFs.isReady();
      if (this.isQemuReady !== ready) {
        this.isQemuReady = ready;
        console.info('[IDELayout] 连接状态变化:', ready ? '已连接' : '未连接');
      }
    }, 2000); // 每 2 秒检查一次
  }

  // ============================================================
  // Editor Layout
  // ============================================================

  private triggerLayout(): void {
    try {
      this.webController.runJavaScript('window.dispatchEvent(new Event("resize"));');
    } catch (e) {
      console.warn('[EditorController] triggerLayout 失败，Web 组件未就绪');
    }
  }

  // ============================================================
  // UI Build
  // ============================================================

  build() {
    Column() {
      if (this.layoutMode === 'vscode') {
        // ----- VSCode 风格布局 -----
        Row() {
          if (this.isShowSideBar) {
            Column() {
              Row() {
                Text('📂 文件')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#cccccc')
                  .padding({ left: 12, right: 4 })
                  .bindMenu(this.buildFileMenu())
                Text('🔄')
                  .fontSize(14)
                  .fontColor('#aaaaaa')
                  .padding({ left: 4, right: 4 })
                  .onClick(() => {
                    this.fileOperationManager.refreshFileTree();
                  })
                Blank()
              }
              .width('100%')
              .height(36)
              .backgroundColor('#252525')
              .alignItems(VerticalAlign.Center)

              FileTree({
                rootNodes: this.fileTreeData,
                selectedPath: this.activeTabPath,
                version: this.folderVersion,
                onFileClick: (path) => this.onFileClick(path),
                onDirToggle: (path) => this.onDirToggle(path),
                onFileRightClick: (path, isDir) => this.onFileRightClick(path, isDir)
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
                .onClick(() => {
                  this.isShowSideBar = !this.isShowSideBar;
                })
              EditorTabs({
                tabs: this.openedTabs.map(tab => tab.path),
                version: this.tabVersion,
                activeTab: this.activeTabPath,
                showRunButton: this.showRunButton,
                onTabSwitch: (path) => this.onTabSwitch(path),
                onTabClose: (path) => this.onTabClose(path),
                onRunClick: (path) => this.handleRun(path)
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
                    setTimeout(() => {
                      if (this.activeTabPath) {
                        this.fileOperationManager.loadFileContent(this.activeTabPath);
                      } else {
                        this.fileOperationManager.showEmptyState('未打开任何文件');
                      }
                      this.triggerLayout();
                    }, 500);
                  })
                  .onErrorReceive(() => {})
                // .onSizeChange(() => this.triggerLayout())  // 已移除，避免过早调用
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
      } else {
        // ----- 终端全屏模式（显示功能键）-----
        Column() {
          WebTerminal({ virtKeyEnabled: true })
            .width('100%')
            .layoutWeight(1)
            .backgroundColor('#0d0d0d')
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#1e1e1e')
      }

      // 状态栏始终显示
      this.buildStatusBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1e1e1e')
  }

  // ============================================================
  // Status Bar
  // ============================================================

  @Builder
  buildStatusBar() {
    Row() {
      // ===== 左侧区域 =====
      if (this.layoutMode === 'terminal-full') {
        // ----- 全屏模式：显示终端连接状态（自动刷新）-----
        Row() {
          Text('Alpine Linux')
            .fontSize(14)
            .fontColor('#4fc3f7')
            .margin({ right: 6 })

          Text('终端')
            .fontSize(12)
            .fontColor('#4fc3f7')
            .margin({ right: 8 })

          // 使用 @State 变量 isQemuReady，自动更新
          if (this.isQemuReady) {
            Text('已连接')
              .fontSize(12)
              .fontColor('#00ff00')
              .margin({ right: 8 })
          } else {
            Text('未连接')
              .fontSize(12)
              .fontColor('#ff6b6b')
              .margin({ right: 8 })
          }
        }
        .padding({ left: 16 })
        .height('100%')
        .alignItems(VerticalAlign.Center)
        .flexShrink(1)

      } else {
        // ----- VSCode 模式：显示编辑器信息 -----
        Row() {
          Text('行 ' + this.currentLine)
            .fontSize(12)
            .fontColor('#cccccc')
          Text('列 ' + this.currentColumn)
            .fontSize(12)
            .fontColor('#cccccc')
            .margin({ left: 10 })
          if (this.currentFileType) {
            Text(this.currentFileType)
              .fontSize(12)
              .fontColor('#cccccc')
              .margin({ left: 10 })
          }
          Text('UTF-8')
            .fontSize(12)
            .fontColor('#cccccc')
            .margin({ left: 10 })
          Text(this.fileOperationManager.getDisplayPath(this.currentFilePath))
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
      }

      // ===== 中间空白 =====
      Blank()

      // ===== 右侧区域（共用）=====
      Row() {
        if (this.isOperationInProgress) {
          Row() {
            LoadingProgress()
              .width(16)
              .height(16)
              .color('#4fc3f7')
              .margin({ right: 6 })
            Text(this.operationMessage)
              .fontSize(12)
              .fontColor('#4fc3f7')
              .maxLines(1)
          }
          .margin({ right: 12 })
          .flexShrink(0)
          .alignItems(VerticalAlign.Center)
        }

        Row() {
          Text(this.wifiName)
            .fontSize(12)
            .fontColor('#cccccc')
            .margin({ right: 4 })
          Circle()
            .width(8)
            .height(8)
            .fill(
              this.wifiStatus === 0
                ? '#00ff00'
                : (this.wifiStatus === 1
                ? '#f1c40f'
                : '#ff0000')
            )
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

        Text('LF')
          .fontSize(12)
          .fontColor('#cccccc')
          .flexShrink(0)

        // 设置按钮
        Text('⚙')
          .fontSize(16)
          .fontColor('#cccccc')
          .margin({ left: 12 })
          .onClick(() => {
            this.toggleLayoutMode();
          })
          .flexShrink(0)
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