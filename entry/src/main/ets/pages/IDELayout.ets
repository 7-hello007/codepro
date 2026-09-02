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

@Component
export struct IdeLayout {
  // ---------- UI 状态 ----------
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
  @State useQemuFs: boolean = true;   // 当前固定为 QEMU 模式

  // ---------- 对话框 ----------
  private dialogController: CustomDialogController | null = null;
  private dialogType: 'file' | 'folder' = 'file';
  private dialogParentPath: string = '';

  // ---------- 服务 ----------
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

  // ---------- 展开路径追踪 ----------
  private expandedPaths: Set<string> = new Set();
  private isProcessingRefresh: boolean = false; // 防止并发刷新处理

  aboutToAppear(): void {
    console.info('======= IDELayout aboutToAppear 开始执行 =======');
    const context = getContext(this) as common.UIAbilityContext;
    this.hostFileService.initializeWorkDirectory(context);
    // this.hostFileService.createSampleFiles();

    this.initEditor();
    this.initFileOperationManager();
    this.initFileTreeManager();
    this.initTabManager();
    this.initStatusBar();
    this.loadFallbackFileTree();
    this.openDefaultFile();
    this.initQemuServices();
    this.initDialog();
    this.initPollingCallbacks();

    this.qemuCoordinator.start();
  }

  aboutToDisappear(): void {
    this.statusBarManager.stopTimer();
    // 保存当前文件
    this.fileOperationManager.saveCurrentFile(this.activeTabPath, this.currentFilePath);
    this.pollingService.stop();
    this.qemuCoordinator.stop();
    QemuAgentManager.release('IDELayout').catch((err: Error) => console.error('[IDELayout] release error:', err));
    if (this.dialogController) this.dialogController.close();
  }

  // ---------- 初始化方法 ----------
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
      // 失焦时自动保存
      this.fileOperationManager.saveCurrentFile(this.activeTabPath, this.currentFilePath);
    };
  }

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

  private initFileTreeManager(): void {
    this.fileTreeManager.onDataChanged = (nodes, version) => {
      // 仅在非 QEMU 模式下使用宿主文件树（此处作为后备）
      if (!this.useQemuFs || !this.qemuFs.isReady()) {
        this.fileTreeData = nodes;
        this.folderVersion = version;
      }
    };
  }

  private initTabManager(): void {
    this.tabManager.onTabsChanged = (tabs) => { this.openedTabs = tabs; this.tabVersion++; };
    this.tabManager.onActiveTabChanged = (path) => {
      this.activeTabPath = path;
      this.selectedTreePath = path;
      if (path) {
        // 打开文件（由 FileOperationManager 处理 QEMU/宿主）
        this.fileOperationManager.loadFileContent(path);
      } else {
        // 无活动标签，显示空状态
        this.fileOperationManager.showEmptyState('未打开任何文件');
      }
    };
  }

  private initStatusBar(): void {
    this.statusBarManager.onStatusChanged = (info: StatusBarInfo) => {
      this.currentTime = info.currentTime;
      this.wifiName = info.wifiName;
      this.wifiStatus = info.wifiStatus;
    };
    this.statusBarManager.startTimer();
  }

  private loadFallbackFileTree(): void {
    const workDir = this.hostFileService.getWorkDir();
    this.fileTreeManager.loadRootDirectory(workDir);
  }

  private openDefaultFile(): void {
    // 在 QEMU 模式下，等待 QEMU 就绪后会自动加载根目录，不再打开默认宿主文件
    if (this.useQemuFs) {
      console.info('[IDELayout] QEMU 模式，不自动打开宿主示例文件');
      return;
    }
    const workDir = this.hostFileService.getWorkDir();
    const defaultFile = workDir + '/src/main.ets';
    try {
      this.hostFileService.readFile(defaultFile);
      setTimeout(() => this.tabManager.openFile(defaultFile), 300);
    } catch (e) {
      const fallbackFile = workDir + '/README.md';
      try {
        this.hostFileService.readFile(fallbackFile);
        setTimeout(() => this.tabManager.openFile(fallbackFile), 300);
      } catch (e2) { console.warn('⚠️ 没有找到任何示例文件'); }
    }
  }

  private initQemuServices(): void {
    this.qemuFileTreeService.bindFileSystem(this.qemuFs);

    // 核心：文件树数据刷新回调，保留展开状态
    this.qemuFileTreeService.onDataChanged = (nodes, version) => {
      // 防止并发处理
      if (this.isProcessingRefresh) return;
      this.isProcessingRefresh = true;

      // 异步处理恢复展开状态和子目录加载
      this.processFileTreeRefresh(nodes, version).then(() => {
        this.isProcessingRefresh = false;
      }).catch((err:Error) => {
        console.error('[IDELayout] 刷新文件树失败:', err);
        this.isProcessingRefresh = false;
        // 降级：直接更新
        this.fileTreeData = nodes;
        this.folderVersion = version;
      });
    };

    this.qemuContextMenuManager.bindFileSystem(this.qemuFs);
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
    this.qemuCoordinator.setOnReady(() => {
      console.info('[IDELayout] Qemu 服务已就绪');
      // 如果当前没有打开任何标签，显示空状态
      if (!this.activeTabPath) {
        this.fileOperationManager.showEmptyState('未打开任何文件');
      }
    });
  }

  /**
   * 处理文件树刷新，递归恢复展开状态并重新加载子目录
   */
  private async processFileTreeRefresh(nodes: FileNode[], version: number): Promise<void> {
    // 深拷贝节点以避免修改原始引用（可选）
    const processedNodes = JSON.parse(JSON.stringify(nodes)) as FileNode[];

    // 递归处理每个节点
    await this.restoreExpandedState(processedNodes);

    // 更新 UI
    this.fileTreeData = processedNodes;
    this.folderVersion = version;
    console.info('[IDELayout] 文件树刷新完成，展开路径数:', this.expandedPaths.size);
  }

  /**
   * 递归恢复展开状态并重新加载子目录
   */
  private async restoreExpandedState(nodes: FileNode[]): Promise<void> {
    for (const node of nodes) {
      if (this.expandedPaths.has(node.path)) {
        // 该节点应展开
        node.isExpanded = true;
        // 重新加载子目录（无论之前有无子节点，都重新获取最新）
        try {
          const children = await this.qemuFileTreeService.loadChildren(node.path);
          if (children && children.length > 0) {
            node.children = children;
            // 递归处理子节点（保留子节点的展开状态）
            await this.restoreExpandedState(children);
          } else {
            node.children = [];
          }
        } catch (err) {
          console.error('[IDELayout] 加载子目录失败:', node.path, err);
          node.children = [];
        }
      } else {
        // 该节点收缩，清空子节点（可选，可保留已有子节点以节省请求）
        node.isExpanded = false;
        // 如果之前有子节点但未展开，可以保留，但为保持一致性，清空或保留？
        // 为了保持数据最新，建议清空，但考虑到性能，如果已有子节点且未展开，可以不请求，但可能导致数据陈旧。
        // 稳妥方案：不清空，但展开时会重新加载。这里我们保留现有 children（如果有）。
        // 但为了确保数据一致性，我们可以在展开时总是重新加载，因此这里不做清空。
        // 但如果有子节点，递归处理（虽然不会展开，但子节点可能之前有展开状态，需要保留）
        if (node.children && node.children.length > 0) {
          // 子节点虽然不展开，但其内部可能有展开的子节点，要递归保留
          await this.restoreExpandedState(node.children);
        }
      }
    }
  }

  private initDialog(): void {
    this.dialogController = new CustomDialogController({
      builder: CreateDialog({
        dialogType: this.dialogType,
        dialogParentPath: this.dialogParentPath,
        inputValue: '',
        onConfirm: (name) => {
          this.qemuContextMenuManager.executeCreate(this.dialogParentPath, name, this.dialogType)
            .then((success) => {
              promptAction.showToast({ message: success ? '创建成功' : '创建失败', duration: 1000 });
            });
        }
      })
    });
  }

  private initPollingCallbacks(): void {
    this.pollingService.onDirectoryChanged = (nodes) => {
      console.info('[IDELayout] 轮询检测到目录变化，更新文件树');
      // 直接调用刷新，会触发 onDataChanged 处理
      this.fileTreeData = nodes;
      this.folderVersion++;
    };
    this.pollingService.onError = (err) => console.warn('[IDELayout] 轮询错误:', err);
  }

  // ---------- 对话框方法 ----------
  private showCreateDialog(): void {
    if (!this.dialogController) return;
    this.dialogController = new CustomDialogController({
      builder: CreateDialog({
        dialogType: this.dialogType,
        dialogParentPath: this.dialogParentPath,
        inputValue: '',
        onConfirm: (name) => {
          this.qemuContextMenuManager.executeCreate(this.dialogParentPath, name, this.dialogType)
            .then((success) => {
              promptAction.showToast({ message: success ? '创建成功' : '创建失败', duration: 1000 });
            });
        }
      })
    });
    this.dialogController.open();
  }

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
              if (this.activeTabPath === path) this.tabManager.closeTab(path);
            } else {
              promptAction.showToast({ message: '删除失败', duration: 1000 });
            }
          });
        }
      })
      .catch(() => {});
  }

  // ---------- UI 事件 ----------
  private handleDirToggle(path: string): void {
    if (this.useQemuFs && this.qemuFs.isReady()) {
      this.toggleQemuDirectory(path);
    } else {
      this.fileTreeManager.toggleDirectory(path);
    }
  }

  /**
   * 切换 QEMU 目录展开/收缩，并记录状态
   */
  private toggleQemuDirectory(path: string): void {
    // 先在当前数据中查找节点并切换状态
    const findAndToggle = (nodes: FileNode[]): boolean => {
      for (const node of nodes) {
        if (node.path === path) {
          // 切换状态
          node.isExpanded = !node.isExpanded;
          if (node.isExpanded) {
            // 展开：记录路径
            this.expandedPaths.add(path);
            // 如果尚无子节点，加载
            if (!node.children || node.children.length === 0) {
              this.qemuFileTreeService.loadChildren(path).then((children) => {
                if (children && children.length > 0) {
                  node.children = children;
                  this.fileTreeData = [...this.fileTreeData];
                  this.folderVersion++;
                }
              }).catch((err: Error) => console.error('[IDELayout] 加载子目录失败:', path, err));
            }
          } else {
            // 收缩：从集合中移除
            this.expandedPaths.delete(path);
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

  /**
   * 点击文件事件：通过 TabManager 打开，会自动触发加载内容
   */
  private onFileClick(path: string): void {
    // 无论 QEMU 还是宿主，统一交给 TabManager 管理
    this.tabManager.openFile(path);
  }

  private onDirToggle(path: string): void { this.handleDirToggle(path); }
  private onFileRightClick(path: string, isDir: boolean): void { this.qemuContextMenuManager.showContextMenu(path, isDir); }
  private onTabSwitch(path: string): void { this.tabManager.switchTab(path); }
  private onTabClose(path: string): void {
    const newActive = this.tabManager.closeTab(path);
    if (!newActive) {
      this.fileOperationManager.showEmptyState('未打开任何文件');
    }
  }
  private triggerLayout(): void { this.editorController.triggerLayout(); }

  // ---------- UI 构建 ----------
  build() {
    Column() {
      Row() {
        if (this.isShowSideBar) {
          Column() {
            Row() {
              Text('📂 文件').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#cccccc').padding({ left: 12, right: 4 })
              Text('🔄').fontSize(14).fontColor('#aaaaaa').padding({ left: 4, right: 4 })
                .onClick(() => this.fileOperationManager.refreshFileTree())
              Blank()
            }
            .width('100%').height(36).backgroundColor('#252525').alignItems(VerticalAlign.Center)

            FileTree({
              rootNodes: this.fileTreeData,
              selectedPath: this.selectedTreePath,
              version: this.folderVersion,
              onFileClick: (path) => this.onFileClick(path),
              onDirToggle: (path) => this.onDirToggle(path),
              onFileRightClick: (path, isDir) => this.onFileRightClick(path, isDir)
            })
              .width('100%').layoutWeight(1).backgroundColor('#1e1e1e')
          }
          .width(240).height('100%').backgroundColor('#1e1e1e')
        }

        Column().width(6).height('100%').backgroundColor('#3a3a3a')

        Column() {
          Row() {
            Text('☰').fontSize(18).fontColor('#cccccc').padding({ left: 10, right: 8 })
              .onClick(() => { this.isShowSideBar = !this.isShowSideBar; })
            EditorTabs({
              tabs: this.openedTabs,
              version: this.tabVersion,
              onTabSwitch: (path) => this.onTabSwitch(path),
              onTabClose: (path) => this.onTabClose(path)
            })
              .layoutWeight(1).height(36)
          }
          .width('100%').height(36).backgroundColor('#252525').padding({ left: 4, right: 4 })

          Column() {
            Column() {
              Web({ src: $rawfile('monaco_editor.html'), controller: this.webController })
                .width('100%').height('100%')
                .javaScriptAccess(true).zoomAccess(false)
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
                  setTimeout(() => {
                    // 如果已有活动标签，加载其内容；否则显示空状态
                    if (this.activeTabPath) {
                      this.fileOperationManager.loadFileContent(this.activeTabPath);
                    } else {
                      this.fileOperationManager.showEmptyState('未打开任何文件');
                    }
                    this.triggerLayout();
                  }, 500);
                })
                .onErrorReceive((event) => {
                  let errorInfo = '未知错误';
                  try {
                    const e = event as Record<string, ESObject>;
                    if (typeof e.getErrorInfo === 'function') errorInfo = String(e.getErrorInfo());
                    else if (typeof e.errorInfo === 'string') errorInfo = e.errorInfo;
                    else if (typeof e.message === 'string') errorInfo = e.message;
                  } catch (e) { errorInfo = String(event); }
                  console.error('❌ WebView 错误:', errorInfo);
                })
                .onSizeChange(() => this.triggerLayout())
            }
            .width('100%').layoutWeight(7).backgroundColor('#1a1a1a').padding({ top: 4 })

            Column() { Divider().height(2).backgroundColor('#3a3a3c').width('100%') }
            .width('100%').height(2)

            Column() { WebTerminal({ virtKeyEnabled: false }) }
            .width('100%').layoutWeight(3).backgroundColor('#0d0d0d').padding({ left: 8 })
          }
          .width('100%').layoutWeight(1).padding(0)
        }
        .layoutWeight(1).height('100%').backgroundColor('#1e1e1e').padding(0)
      }
      .width('100%').height('100%').layoutWeight(1)

      this.buildStatusBar()
    }
    .width('100%').height('100%').backgroundColor('#1e1e1e')
  }

  @Builder
  buildStatusBar() {
    Row() {
      Row() {
        Text('行 ' + this.currentLine).fontSize(12).fontColor('#cccccc')
        Text('列 ' + this.currentColumn).fontSize(12).fontColor('#cccccc').margin({ left: 10 })
        if (this.currentFileType) Text(this.currentFileType).fontSize(12).fontColor('#cccccc').margin({ left: 10 })
        Text('UTF-8').fontSize(12).fontColor('#cccccc').margin({ left: 10 })
        Text(this.fileOperationManager.getDisplayPath(this.currentFilePath))
          .fontSize(12).fontColor('#cccccc').margin({ left: 10 })
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1).flexShrink(1)
      }
      .padding({ left: 16 }).height('100%').alignItems(VerticalAlign.Center).flexShrink(1)

      Blank()

      Row() {
        Row() {
          Text(this.wifiName).fontSize(12).fontColor('#cccccc').margin({ right: 4 })
          Circle().width(8).height(8)
            .fill(this.wifiStatus === 0 ? '#00ff00' : (this.wifiStatus === 1 ? '#f1c40f' : '#ff0000'))
        }
        .margin({ right: 12 }).flexShrink(0)

        Text() {
          Span(this.currentTime).fontWeight(FontWeight.Bold).fontSize(12).fontColor('#ffffff')
          Span(' / ').fontSize(12).fontColor('#cccccc')
          Span(this.lastModifiedTime || '未保存').fontSize(12).fontColor('#888888')
        }
        .margin({ right: 12 }).flexShrink(0)

        Text('LF').fontSize(12).fontColor('#cccccc').flexShrink(0)
      }
      .padding({ right: 16 }).height('100%').alignItems(VerticalAlign.Center).flexShrink(0)
    }
    .width('100%').height(28).backgroundColor('#2d2d2d').padding(0)
  }
}