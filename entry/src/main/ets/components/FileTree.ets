// entry/src/main/ets/components/FileTree.ets

import { FileNode } from '../model/FileNode';

export { FileNode };

@Component
export struct FileTree {
  // 用 @Watch 监听 rootNodes 变化，触发宽度重算
  @Prop @Watch('onDataChanged') rootNodes: FileNode[] = [];
  // 用 @Watch 监听 version 变化，触发宽度重算
  @Prop @Watch('onDataChanged') version: number = 0;
  @Prop @Watch('onSelectedPathChange') selectedPath: string = '';

  onFileClick?: (path: string) => void;
  onDirToggle?: (path: string) => void;
  onFileRightClick?: (path: string, isDir: boolean) => void;

  @State private columnWidth: number = 0;
  @State private forceUpdate: number = 0;

  private onSelectedPathChange(): void {
    console.info('[FileTreeCheck] selectedPath 已变化:', this.selectedPath);
  }

  private onDataChanged(): void {
    console.info('[FileTreeCheck] onDataChanged 触发, version:', this.version, 'rootNodes 数量:', this.rootNodes.length);
    this.columnWidth = this.calcMaxWidth();
    // 打印每个根节点信息
    for (let node of this.rootNodes) {
      console.info('[FileTreeCheck] 根节点:', node.path, 'isDir:', node.isDir, 'children 数量:', node.children?.length || 0);
      this.traverseLog(node, 0);
    }
  }

  private traverseLog(node: FileNode, level: number): void {
    if (node.isDir && node.isExpanded && node.children && node.children.length > 0) {
      for (let child of node.children) {
        console.info('[FileTreeCheck] 子节点:', child.path, '层级:', level + 1);
        this.traverseLog(child, level + 1);
      }
    }
  }

  private calcMaxWidth(): number {
    let maxWidth = 0;
    this.traverse(this.rootNodes, 0, (node, level) => {
      let nameWidth = node.name.length * 10;
      let total = level * 18 + nameWidth;
      if (total > maxWidth) maxWidth = total;
    });
    console.info('[FileTreeCheck] calcMaxWidth 结果:', maxWidth);
    return maxWidth;
  }

  private traverse(nodes: FileNode[], level: number, callback: (node: FileNode, level: number) => void): void {
    for (let node of nodes) {
      callback(node, level);
      if (node.isDir && node.isExpanded && node.children && node.children.length > 0) {
        this.traverse(node.children, level + 1, callback);
      }
    }
  }

  aboutToAppear(): void {
    console.info('[FileTreeCheck] aboutToAppear, 初始 rootNodes 数量:', this.rootNodes.length);
    this.columnWidth = this.calcMaxWidth();
  }

  build() {
    Scroll() {
      Scroll() {
        Column() {
          if (this.rootNodes.length === 0) {
            Text('暂无文件')
              .fontSize(13)
              .fontColor('#777777')
              .padding({ left: 16 })
              .height(36)
          } else {
            ForEach(
              this.rootNodes,
              (node: FileNode) => {
                this.buildNode(node, 0);
              },
              (node: FileNode) => {
                // key 函数中可以放 console（虽然不是纯函数，但为了调试）
                let key = node.path + '_' + this.version + '_' + this.forceUpdate;
                // console.info('[FileTreeCheck] 根节点 key:', key);  // 可选，为了减少日志可注释
                return key;
              }
            )
          }
        }
        .width(this.columnWidth > 0 ? this.columnWidth : 'auto')
        .alignItems(HorizontalAlign.Start)
        .padding({ right: 16 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.On)
      .width('100%')
      .height('auto')
      .align(Alignment.TopStart)
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Auto)
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
  }

  @Builder
  private buildNode(node: FileNode, level: number) {
    Column() {
      Row() {
        if (level > 0) {
          Blank().width(level * 18)
        }

        if (node.isDir) {
          Text(node.isExpanded ? '▼' : '▶')
            .fontSize(10)
            .fontColor('#999999')
            .width(18)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              console.info('[FileTreeCheck] 点击文件夹箭头:', node.path, '当前 isExpanded:', node.isExpanded);
              if (this.onDirToggle) {
                this.onDirToggle(node.path);
              }
              this.forceUpdate++;
              console.info('[FileTreeCheck] forceUpdate 自增后:', this.forceUpdate);
            })
        } else {
          Blank().width(18)
        }

        Text(node.isDir ? (node.isExpanded ? '📂' : '📁') : this.getFileIcon(node.name))
          .fontSize(14)
          .width(24)
          .textAlign(TextAlign.Center)
          .flexShrink(0)

        Text(node.name)
          .fontSize(13)
          .fontColor(node.path === this.selectedPath ? '#ffffff' : '#cccccc')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.None })
          .textAlign(TextAlign.Start)
          .flexShrink(0)
      }
      .width('100%')
      .height(36)
      .padding({ left: 12, right: 12 })
      .backgroundColor(node.path === this.selectedPath ? '#37373d' : 'transparent')
      .borderRadius(3)
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        console.info('[FileTreeCheck] 点击行:', node.path, 'isDir:', node.isDir);
        if (!node.isDir) {
          let filePath = node.path;
          if (!filePath.startsWith('/')) {
            filePath = '/' + filePath;
            console.warn('[FileTreeCheck] 路径非绝对，已补全为:', filePath);
          } else {
            console.info('[FileTreeCheck] 路径绝对，直接使用:', filePath);
          }
          console.info('[FileTreeCheck] 即将调用 onFileClick，路径:', filePath);
          this.onFileClick?.(filePath);
        } else {
          console.info('[FileTreeCheck] 点击文件夹，触发展开:', node.path);
          if (this.onDirToggle) {
            this.onDirToggle(node.path);
          }
          this.forceUpdate++;
          console.info('[FileTreeCheck] forceUpdate 自增后:', this.forceUpdate);
        }
      })
      .gesture(
        LongPressGesture({ repeat: false, duration: 500 })
          .onAction(() => {
            console.info('[FileTreeCheck] 长按:', node.path);
            this.onFileRightClick?.(node.path, node.isDir);
          })
      )

      if (node.isDir && node.isExpanded && node.children && node.children.length > 0) {
        ForEach(
          node.children,
          (child: FileNode) => {
            this.buildNode(child, level + 1);
          },
          (child: FileNode) => {
            let key = child.path + '_' + this.version + '_' + this.forceUpdate;
            // console.info('[FileTreeCheck] 子节点 key:', key);
            return key;
          }
        )
      }
    }
    .alignItems(HorizontalAlign.Start)
  }

  private getFileIcon(fileName: string): string {
    const lower = fileName.toLowerCase();
    if (lower.endsWith('.ets') || lower.endsWith('.ts')) return '📘';
    if (lower.endsWith('.js')) return '📒';
    if (lower.endsWith('.json')) return '⚙️';
    if (lower.endsWith('.md')) return '📝';
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return '🌐';
    if (lower.endsWith('.css')) return '🎨';
    if (lower.endsWith('.py')) return '🐍';
    if (lower.endsWith('.java')) return '☕';
    if (lower.endsWith('.cpp') || lower.endsWith('.c')) return '🔧';
    if (lower.endsWith('.xml')) return '📄';
    return '📄';
  }
}