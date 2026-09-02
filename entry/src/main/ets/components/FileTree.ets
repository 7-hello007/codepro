// entry/src/main/ets/components/FileTree.ets

export interface FileNode {
  name: string;
  path: string;
  isDir: boolean;
  isExpanded: boolean;
  children?: FileNode[];
}

@Component
export struct FileTree {

  @Prop rootNodes: FileNode[] = [];
  @Prop selectedPath: string = '';
  @Prop version: number = 0;

  onFileClick?: (path: string) => void;
  onDirToggle?: (path: string) => void;
  // 新增：右键点击回调（长按触发）
  onFileRightClick?: (path: string, isDir: boolean) => void;

  build() {
    Scroll() {
      Column() {
        if (this.rootNodes.length === 0) {
          Row() {
            Text('暂无文件')
              .fontSize(13)
              .fontColor('#777777')
          }
          .width('100%')
          .height(40)
          .padding({ left: 16 })
          .alignItems(VerticalAlign.Center)
        } else {
          ForEach(
            this.rootNodes,
            (node: FileNode) => {
              this.buildNode(node, 0);
            },
            (node: FileNode) => node.path + '_' + this.version
          )
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .scrollable(ScrollDirection.Vertical)
    .align(Alignment.TopStart)
  }

  @Builder
  private buildNode(node: FileNode, level: number) {
    Column() {
      Row() {
        // 缩进
        if (level > 0) {
          Blank().width(level * 18)
        }

        // 展开/折叠箭头
        if (node.isDir) {
          Text(node.isExpanded ? '▼' : '▶')
            .fontSize(10)
            .fontColor('#999999')
            .width(18)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              if (this.onDirToggle) {
                this.onDirToggle(node.path);
              }
            })
        } else {
          Blank().width(18)
        }

        // 图标
        Text(node.isDir ? (node.isExpanded ? '📂' : '📁') : this.getFileIcon(node.name))
          .fontSize(14)
          .width(24)
          .textAlign(TextAlign.Center)

        // 文件名
        Text(node.name)
          .fontSize(13)
          .fontColor(this.selectedPath === node.path ? '#ffffff' : '#cccccc')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .height(32)
      .padding({ left: 4, right: 8 })
      .backgroundColor(this.selectedPath === node.path ? '#37373d' : '#1e1e1e')
      .borderRadius(3)
      // ----- 单击事件 -----
      .onClick(() => {
        if (node.isDir) {
          if (this.onDirToggle) {
            this.onDirToggle(node.path);
          }
        } else {
          if (this.onFileClick) {
            this.onFileClick(node.path);
          }
        }
      })
      // ----- 新增：长按事件（右键菜单） -----
      .gesture(
        LongPressGesture({ repeat: false, duration: 500 })
          .onAction(() => {
            if (this.onFileRightClick) {
              this.onFileRightClick(node.path, node.isDir);
            }
          })
      )

      // 子节点
      if (node.isDir && node.isExpanded && node.children && node.children.length > 0) {
        ForEach(
          node.children,
          (child: FileNode) => {
            this.buildNode(child, level + 1);
          },
          (child: FileNode) => child.path + '_' + this.version
        )
      }
    }
    .width('100%')
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