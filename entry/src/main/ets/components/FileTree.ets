// entry/src/main/ets/components/FileTree.ets

import { FileNode } from '../model/FileNode';

export { FileNode };

@Component
export struct FileTree {

  @Prop rootNodes: FileNode[] = [];
  @Prop @Watch('onSelectedPathChange') selectedPath: string = '';
  @Prop version: number = 0;

  onFileClick?: (path: string) => void;
  onDirToggle?: (path: string) => void;
  onFileRightClick?: (path: string, isDir: boolean) => void;

  // ====== 监听 selectedPath 变化，打印日志 ======
  private onSelectedPathChange(): void {
    console.info('[FileTree] selectedPath 已变化:', this.selectedPath);
  }

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
              if (this.onDirToggle) {
                this.onDirToggle(node.path);
              }
            })
        } else {
          Blank().width(18)
        }

        Text(node.isDir ? (node.isExpanded ? '📂' : '📁') : this.getFileIcon(node.name))
          .fontSize(14)
          .width(24)
          .textAlign(TextAlign.Center)

        Text(node.name)
          .fontSize(13)
          .fontColor(node.path === this.selectedPath ? '#ffffff' : '#cccccc')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .height(32)
      .padding({ left: 4, right: 8 })
      .backgroundColor(node.path === this.selectedPath ? '#37373d' : '#1e1e1e')
      .borderRadius(3)
      .onClick(() => {
        // ====== 点击时打印节点路径和当前 selectedPath ======
        console.info('[FileTree] 点击节点:', node.path, 'isDir:', node.isDir);
        console.info('[FileTree] 当前 selectedPath:', this.selectedPath);
        if (!node.isDir) {
          if (this.onFileClick) {
            this.onFileClick(node.path);
          }
        } else {
          if (this.onDirToggle) {
            this.onDirToggle(node.path);
          }
        }
      })
      .gesture(
        LongPressGesture({ repeat: false, duration: 500 })
          .onAction(() => {
            if (this.onFileRightClick) {
              this.onFileRightClick(node.path, node.isDir);
            }
          })
      )

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