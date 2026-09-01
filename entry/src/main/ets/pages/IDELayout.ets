// entry/src/main/ets/pages/IDELayout.ets

import WebTerminal from '../components/WebTerminal';
import { webview } from '@kit.ArkWeb';
import { FileTree, FileNode } from '../components/FileTree';
import { EditorTabs, EditorTab } from '../components/EditorTabs';
import { common } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import wifiManager from '@ohos.wifiManager';

interface SampleFile {
  path: string;
  content: string;
}

interface ArkTSService {
  onEditorReady: () => void;
  onContentChange: (content: string) => void;
  onCursorChange: (line: string, col: string) => void;
  onEditorBlur: (content: string) => void;
  log: (msg: string) => void;
}

@Component
export struct IdeLayout {

  private sideBarWidth: number = 240;
  private dividerWidth: number = 6;
  private dividerHeight: number = 2;

  @State isShowSideBar: boolean = true;
  @State editorContent: string = '';
  @State isEditorReady: boolean = false;

  @State fileTreeData: FileNode[] = [];
  @State selectedTreePath: string = '';

  @State openedTabs: EditorTab[] = [];
  @State activeTabPath: string = '';

  @State tabVersion: number = 0;
  @State folderVersion: number = 0;

  @State currentLine: number = 1;
  @State currentColumn: number = 1;
  @State currentFileType: string = '';
  @State currentEncoding: string = 'UTF-8';
  @State currentFilePath: string = '';
  @State currentLineEnding: string = 'LF';
  @State currentTime: string = '';
  @State lastModifiedTime: string = '';
  @State wifiName: string = 'WiFi';
  @State wifiStatus: number = 0;

  private webController: webview.WebviewController = new webview.WebviewController();
  private workDir: string = '';

  private pendingEditorContent: string = '';
  private pendingEditorLanguage: string = 'plaintext';
  private hasPendingEditorContent: boolean = false;
  private hasPendingEditorLanguage: boolean = false;
  private timeTimerId: number = -1;

  aboutToAppear(): void {
    this.initializeWorkDirectory();
    this.createSampleFiles();
    this.loadFileTree(this.workDir);
    this.updateTime();
    this.getWifiInfo();

    this.timeTimerId = setInterval(() => {
      this.updateTime();
    }, 60000);

    const defaultFile = this.workDir + '/src/main.ets';
    try {
      fs.statSync(defaultFile);
      console.info('📌 默认打开示例文件:', defaultFile);
      setTimeout(() => {
        this.openFile(defaultFile);
      }, 300);
    } catch (e) {
      console.warn('⚠️ 默认示例文件不存在:', defaultFile);
      const fallbackFile = this.workDir + '/README.md';
      try {
        fs.statSync(fallbackFile);
        console.info('📌 回退打开 README.md');
        setTimeout(() => {
          this.openFile(fallbackFile);
        }, 300);
      } catch (e2) {
        console.warn('⚠️ 没有找到任何示例文件');
      }
    }
  }

  aboutToDisappear(): void {
    if (this.timeTimerId !== -1) {
      clearInterval(this.timeTimerId);
      this.timeTimerId = -1;
    }
    this.saveCurrentFile();
  }

  private initializeWorkDirectory(): void {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      this.workDir = context.filesDir;
      console.info('📂 工作目录:', this.workDir);
    } catch (e) {
      console.error('❌ 获取上下文失败:', e);
      this.workDir = '/data/storage/el2/base/haps/entry/files';
    }
  }

  private getWifiInfo(): void {
    try {
      wifiManager.getLinkedInfo().then((info: wifiManager.WifiLinkedInfo) => {
        if (!info) {
          this.wifiName = '无WiFi';
          this.wifiStatus = 2;
          return;
        }
        this.wifiName = info.ssid || 'WiFi';
        const rssi = info.rssi ?? -100;
        if (rssi > -50) this.wifiStatus = 0;
        else if (rssi > -70) this.wifiStatus = 1;
        else this.wifiStatus = 2;
      }).catch(() => {
        this.wifiName = '无WiFi';
        this.wifiStatus = 2;
      });
    } catch (e) {
      this.wifiName = '无WiFi';
      this.wifiStatus = 2;
    }
  }

  private createSampleFiles(): void {
    const sampleFiles: SampleFile[] = [
      {
        path: this.workDir + '/src/main.ets',
        content: `// main.ets\n// HiSH-IDE 示例项目\n// ArkTS 应用入口\n\nimport { UIAbility } from '@kit.AbilityKit';\n\nexport default class MainAbility extends UIAbility {\n  onCreate(): void {\n    console.info('HiSH-IDE 应用启动');\n  }\n  onDestroy(): void {\n    console.info('HiSH-IDE 应用退出');\n  }\n}\n`
      },
      {
        path: this.workDir + '/README.md',
        content: `# HiSH-IDE\n\n这是一个运行在 HarmonyOS 平台上的轻量级 IDE 示例项目。\n\n## 功能\n\n- 文件树\n- Monaco 代码编辑器\n- 多文件 Tab\n- 文件保存\n- 终端模拟器\n\n## 使用方式\n\n点击左侧文件即可在中间编辑器打开。\n`
      },
      {
        path: this.workDir + '/utils/helper.ets',
        content: `// helper.ets\n// 工具函数\n\nexport function add(a: number, b: number): number {\n  return a + b;\n}\n\nexport function multiply(a: number, b: number): number {\n  return a * b;\n}\n`
      },
      {
        path: this.workDir + '/config.json',
        content: `{\n  "name": "HiSH-IDE",\n  "version": "1.0.0",\n  "platform": "HarmonyOS",\n  "editor": "Monaco"\n}\n`
      }
    ];

    for (const file of sampleFiles) {
      try {
        fs.statSync(file.path);
        continue;
      } catch (e) {
        const dir = file.path.substring(0, file.path.lastIndexOf('/'));
        try {
          fs.statSync(dir);
        } catch (e) {
          fs.mkdirSync(dir);
        }
        let fd: number = -1;
        try {
          const f = fs.openSync(file.path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
          fd = f.fd;
          fs.writeSync(fd, file.content);
          console.info('✅ 创建示例文件:', file.path);
        } catch (err) {
          console.error('❌ 创建示例文件失败:', file.path, err);
        } finally {
          if (fd !== -1) fs.closeSync(fd);
        }
      }
    }
  }

  private loadFileTree(path: string): void {
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
      this.fileTreeData = nodes;
      this.folderVersion++;

      for (const node of nodes) {
        if (node.isDir && node.isExpanded) {
          this.loadSubDirectory(node.path);
        }
      }
      console.info('✅ 根目录加载完成:', nodes.length);
    } catch (err) {
      console.error('❌ 读取目录失败:', err);
      this.fileTreeData = [];
    }
  }

  private loadSubDirectory(path: string): void {
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

      const updatedTree = this.cloneFileNodes(this.fileTreeData);
      const success = this.setChildrenForPath(updatedTree, path, children);
      if (success) {
        this.fileTreeData = updatedTree;
        this.folderVersion++;
        console.info('📂 子目录加载完成:', path, children.length);
      }
    } catch (err) {
      console.error('❌ 加载子目录失败:', path, err);
    }
  }

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

  private cloneFileNodes(nodes: FileNode[]): FileNode[] {
    const result: FileNode[] = [];
    for (const node of nodes) {
      result.push({
        name: node.name,
        path: node.path,
        isDir: node.isDir,
        isExpanded: node.isExpanded,
        children: node.children ? this.cloneFileNodes(node.children) : undefined
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

  private toggleDir(path: string): void {
    const updatedTree = this.cloneFileNodes(this.fileTreeData);
    const node = this.findNodeByPath(updatedTree, path);
    if (!node) return;
    node.isExpanded = !node.isExpanded;
    this.fileTreeData = updatedTree;
    this.folderVersion++;
    if (node.isExpanded && (!node.children || node.children.length === 0)) {
      this.loadSubDirectory(path);
    }
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

  private updateTime(): void {
    const now = new Date();
    this.currentTime = String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
  }

  private arkTSService: ArkTSService = {
    onEditorReady: (): void => {
      console.info('✅ Monaco Editor Ready');
      this.isEditorReady = true;
      if (this.hasPendingEditorContent || this.hasPendingEditorLanguage) {
        const content = this.hasPendingEditorContent ? this.pendingEditorContent : '';
        const language = this.hasPendingEditorLanguage ? this.pendingEditorLanguage : this.getLanguageFromPath(this.activeTabPath);
        this.hasPendingEditorContent = false;
        this.hasPendingEditorLanguage = false;
        this.pendingEditorContent = '';
        this.pendingEditorLanguage = 'plaintext';
        this.applyEditorToMonaco(content, language);
      }
      this.triggerLayout();
    },
    onContentChange: (content: string): void => {
      this.editorContent = content;
    },
    onCursorChange: (line: string, col: string): void => {
      this.currentLine = parseInt(line, 10) || 1;
      this.currentColumn = parseInt(col, 10) || 1;
    },
    onEditorBlur: (content: string): void => {
      this.editorContent = content;
      this.saveCurrentFile();
    },
    log: (msg: string): void => {
      console.info('📢 [Monaco]:', msg);
    }
  };

  // ====== 核心修改：使用 forceSetContent 强制覆盖 ======
  private applyEditorToMonaco(content: string, language: string): void {
    if (!this.webController) {
      console.error('❌ WebView Controller 不存在');
      return;
    }
    const safeContent = JSON.stringify(content);
    const safeLanguage = JSON.stringify(language);
    // 优先使用 forceSetContent（直接操作 model），不存在则回退到 setEditorContent
    const jsCode = `
      (function() {
        try {
          if (typeof window.forceSetContent === 'function') {
            window.forceSetContent(${safeContent}, ${safeLanguage});
            return true;
          } else if (typeof window.setEditorContent === 'function') {
            window.setEditorContent(${safeContent}, ${safeLanguage});
            return true;
          } else {
            console.error('没有可用的设置内容方法');
            return false;
          }
        } catch (e) {
          console.error('写入 Monaco 失败:', e);
          return false;
        }
      })();
    `;
    console.info('📤 → Monaco:', 'path=' + this.currentFilePath, 'language=' + language, 'length=' + content.length);
    const preview = content.substring(0, 50) + (content.length > 50 ? '...' : '');
    console.info('📄 内容预览:', preview);
    this.webController.runJavaScript(jsCode, (err: Error | null) => {
      if (err) console.error('❌ Monaco JS 执行失败:', err.message);
      else console.info('✅ Monaco 内容写入成功');
    });
  }

  setEditorContent(content: string, language: string = 'plaintext'): void {
    this.editorContent = content;
    if (!this.isEditorReady) {
      this.pendingEditorContent = content;
      this.pendingEditorLanguage = language;
      this.hasPendingEditorContent = true;
      this.hasPendingEditorLanguage = true;
      console.info('⏳ Monaco 未 Ready，暂存文件:', 'length=' + content.length, 'language=' + language);
      return;
    }
    this.applyEditorToMonaco(content, language);
  }

  private showEmptyState(): void {
    const content = '// 点击左侧文件树中的文件开始编辑';
    this.currentFilePath = '';
    this.currentFileType = '';
    this.lastModifiedTime = '';
    this.editorContent = content;
    this.applyEditorToMonaco(content, 'typescript');
  }

  private readFileContent(path: string): string {
    let fd: number = -1;
    try {
      const f = fs.openSync(path, fs.OpenMode.READ_ONLY);
      fd = f.fd;
      const stat = fs.statSync(path);
      const buffer = new ArrayBuffer(stat.size);
      fs.readSync(fd, buffer);
      const decoder = new util.TextDecoder('utf-8');
      return decoder.decode(new Uint8Array(buffer));
    } catch (err) {
      console.error('❌ 读取文件失败:', path, err);
      throw new Error(String(err));
    } finally {
      if (fd !== -1) fs.closeSync(fd);
    }
  }

  private writeFileContent(path: string, content: string): void {
    let fd: number = -1;
    try {
      const f = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fd = f.fd;
      fs.writeSync(fd, content);
    } catch (err) {
      console.error('❌ 写入文件失败:', path, err);
      throw new Error(String(err));
    } finally {
      if (fd !== -1) fs.closeSync(fd);
    }
  }

  private getDemoContent(path: string): string {
    const fileName = path.split('/').pop() || '';
    const ext = path.split('.').pop()?.toLowerCase() || '';
    const exactDemos: Record<string, string> = {
      'main.ets': `// main.ets\n// HiSH-IDE 示例代码\n\nimport { UIAbility } from '@kit.AbilityKit';\n\nexport default class MainAbility extends UIAbility {\n  onCreate(): void {\n    console.info('应用已启动');\n  }\n}\n`,
      'helper.ets': `// helper.ets\n\nexport function add(a: number, b: number): number {\n  return a + b;\n}\n`,
      'readme.md': `# HiSH-IDE\n\nHarmonyOS IDE 示例项目。\n\n点击左侧文件查看代码。\n`,
      'config.json': `{\n  "name": "HiSH-IDE",\n  "version": "1.0.0"\n}\n`
    };
    const lowerFileName = fileName.toLowerCase();
    for (const key of Object.keys(exactDemos)) {
      if (lowerFileName === key.toLowerCase()) return exactDemos[key];
    }
    switch (ext) {
      case 'ets': return `// ${fileName}\n\n@Component\nexport struct ${this.safeIdentifier(fileName)} {\n  build() {\n    Column() {\n      Text('${fileName}')\n        .fontSize(20)\n    }\n  }\n}\n`;
      case 'ts': return `// ${fileName}\n\nexport function hello(): string {\n  return 'Hello from ${fileName}';\n}\n`;
      case 'js': return `// ${fileName}\n\nfunction hello() {\n  console.log('Hello from ${fileName}');\n}\n`;
      case 'json': return `{\n  "file": "${fileName}",\n  "type": "json"\n}\n`;
      case 'py': return `# ${fileName}\n\ndef main():\n    print("Hello from ${fileName}")\n\nif __name__ == "__main__":\n    main()\n`;
      case 'md': return `# ${fileName}\n\n这是一个示例 Markdown 文件。\n`;
      default: return `// ${fileName}\n\n// 请编辑此文件\n`;
    }
  }

  private safeIdentifier(fileName: string): string {
    const base = fileName.replace(/\.[^.]+$/, '');
    const clean = base.replace(/[^a-zA-Z0-9_]/g, '_');
    if (!clean) return 'Example';
    if (/^[0-9]/.test(clean)) return '_' + clean;
    return clean;
  }

  private loadFileContent(path: string): void {
    console.info('📂 loadFileContent:', path);
    if (!path) {
      this.showEmptyState();
      return;
    }
    this.currentFilePath = path;

    const ext = path.split('.').pop()?.toLowerCase() || '';
    const typeMap: Record<string, string> = {
      'ets': 'ArkTS', 'ts': 'TypeScript', 'js': 'JavaScript',
      'json': 'JSON', 'html': 'HTML', 'css': 'CSS',
      'xml': 'XML', 'py': 'Python', 'java': 'Java',
      'c': 'C', 'cpp': 'C++', 'go': 'Go', 'md': 'Markdown', 'txt': 'Text'
    };
    this.currentFileType = typeMap[ext] || 'Plain Text';

    let content: string = '';
    let fileExists = false;
    try {
      content = this.readFileContent(path);
      fileExists = true;
      console.info('✅ 真实文件读取成功:', path, 'length=' + content.length);
    } catch (err) {
      console.warn('⚠️ 真实文件读取失败，使用示例内容:', path);
      content = this.getDemoContent(path);
    }

    this.editorContent = content;
    const language = this.getLanguageFromPath(path);
    // 直接调用 applyEditorToMonaco（内部会使用 forceSetContent）
    this.applyEditorToMonaco(content, language);

    if (fileExists) {
      try {
        const stat = fs.statSync(path);
        const mtime = new Date(stat.mtime);
        this.lastModifiedTime =
          String(mtime.getHours()).padStart(2, '0') + ':' +
          String(mtime.getMinutes()).padStart(2, '0') + ':' +
          String(mtime.getSeconds()).padStart(2, '0') + ' ' +
          mtime.getFullYear() + '-' +
          String(mtime.getMonth() + 1).padStart(2, '0') + '-' +
          String(mtime.getDate()).padStart(2, '0');
      } catch (e) { this.lastModifiedTime = ''; }
    } else {
      this.lastModifiedTime = '';
    }
  }

  private saveCurrentFile(): void {
    if (!this.activeTabPath || !this.currentFilePath || this.currentFilePath !== this.activeTabPath) return;
    try {
      this.writeFileContent(this.currentFilePath, this.editorContent);
      const now = new Date();
      this.lastModifiedTime =
        String(now.getHours()).padStart(2, '0') + ':' +
        String(now.getMinutes()).padStart(2, '0') + ':' +
        String(now.getSeconds()).padStart(2, '0') + ' ' +
        now.getFullYear() + '-' +
        String(now.getMonth() + 1).padStart(2, '0') + '-' +
        String(now.getDate()).padStart(2, '0');
      console.info('💾 文件保存成功:', this.currentFilePath);
    } catch (err) {
      console.error('❌ 保存文件失败:', err);
    }
  }

  private getLanguageFromPath(path: string): string {
    const ext = path.split('.').pop()?.toLowerCase() || '';
    const map: Record<string, string> = {
      'ets': 'typescript', 'ts': 'typescript', 'js': 'javascript',
      'json': 'json', 'html': 'html', 'css': 'css',
      'xml': 'xml', 'py': 'python', 'java': 'java',
      'c': 'c', 'cpp': 'cpp', 'go': 'go', 'md': 'markdown'
    };
    return map[ext] || 'plaintext';
  }

  openFile(path: string): void {
    console.info('📂 openFile:', path);
    if (!path) return;
    this.selectedTreePath = path;
    if (this.activeTabPath === path) return;

    for (const tab of this.openedTabs) {
      if (tab.path === path) {
        this.switchTab(path);
        return;
      }
    }

    const name = path.split('/').pop() || path;
    const updatedTabs: EditorTab[] = [];
    for (const tab of this.openedTabs) {
      updatedTabs.push({ path: tab.path, name: tab.name, isActive: false });
    }
    updatedTabs.push({ path: path, name: name, isActive: true });
    this.openedTabs = updatedTabs;
    this.tabVersion++;
    this.activeTabPath = path;
    this.loadFileContent(path);
  }

  switchTab(path: string): void {
    if (this.activeTabPath === path) return;
    this.saveCurrentFile();
    this.selectedTreePath = path;
    const updatedTabs: EditorTab[] = [];
    for (const tab of this.openedTabs) {
      updatedTabs.push({ path: tab.path, name: tab.name, isActive: tab.path === path });
    }
    this.openedTabs = updatedTabs;
    this.tabVersion++;
    this.activeTabPath = path;
    this.loadFileContent(path);
  }

  closeTab(path: string): void {
    let index = -1;
    for (let i = 0; i < this.openedTabs.length; i++) {
      if (this.openedTabs[i].path === path) { index = i; break; }
    }
    if (index === -1) return;
    const wasActive = this.openedTabs[index].isActive;
    if (wasActive) this.saveCurrentFile();

    const newTabs = this.openedTabs.filter((_, i) => i !== index);
    this.openedTabs = newTabs;
    this.tabVersion++;

    if (newTabs.length === 0) {
      this.activeTabPath = '';
      this.selectedTreePath = '';
      this.showEmptyState();
      return;
    }

    if (!wasActive) return;
    let newIndex = index;
    if (newIndex >= newTabs.length) newIndex = newTabs.length - 1;
    const activeTab = newTabs[newIndex];
    const updatedTabs: EditorTab[] = [];
    for (let i = 0; i < newTabs.length; i++) {
      updatedTabs.push({ path: newTabs[i].path, name: newTabs[i].name, isActive: i === newIndex });
    }
    this.openedTabs = updatedTabs;
    this.tabVersion++;
    this.activeTabPath = activeTab.path;
    this.selectedTreePath = activeTab.path;
    this.loadFileContent(activeTab.path);
  }

  triggerLayout(): void {
    this.webController.runJavaScript(`
      if (typeof window.triggerLayout === 'function') {
        window.triggerLayout();
      }
    `);
  }

  private getDisplayPath(): string {
    if (!this.currentFilePath) return '';
    let path = this.currentFilePath;
    if (this.workDir && path.startsWith(this.workDir)) {
      path = path.substring(this.workDir.length);
      if (path.startsWith('/')) path = path.substring(1);
    }
    const parts = path.split('/').filter(p => p !== '');
    if (parts.length === 0) return '';
    if (parts.length > 3) return '... > ' + parts.slice(-3).join(' > ');
    return parts.join(' > ');
  }

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
              onFileClick: (path: string) => { this.openFile(path); },
              onDirToggle: (path: string) => { this.toggleDir(path); }
            })
              .width('100%')
              .layoutWeight(1)
              .backgroundColor('#1e1e1e')
          }
          .width(this.sideBarWidth)
          .height('100%')
          .backgroundColor('#1e1e1e')
        }

        Column()
          .width(this.dividerWidth)
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
              onTabSwitch: (path: string) => { this.switchTab(path); },
              onTabClose: (path: string) => { this.closeTab(path); }
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
                        { "scheme": "https", "host": "cdnjs.cloudflare.com", "port": "", "path": "" }
                      ]
                    }
                  }`,
                  object: this.arkTSService,
                  name: 'arkTSService',
                  methodList: ['onEditorReady', 'onContentChange', 'onCursorChange', 'onEditorBlur', 'log'],
                  controller: this.webController
                })
                .onPageEnd(() => {
                  console.info('🌐 Monaco HTML 加载完成');
                  setTimeout(() => {
                    if (this.openedTabs.length > 0 && this.activeTabPath) {
                      this.loadFileContent(this.activeTabPath);
                    } else {
                      this.showEmptyState();
                    }
                    this.triggerLayout();
                  }, 500);
                })
                .onErrorReceive((event: ESObject) => {
                  let errorInfo = '未知错误';
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
            .height(this.dividerHeight)

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
        Text(this.currentEncoding).fontSize(12).fontColor('#cccccc').margin({ left: 10 })
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

        Text(this.currentLineEnding).fontSize(12).fontColor('#cccccc').flexShrink(0)
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