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

  private onSelectedPathChange(): void {
    console.info('[FileTree] selectedPath 已变化:', this.selectedPath);
  }

  build() {
    // 外层：垂直滚动
    Scroll() {
      // 内层：水平滚动（整体左右滑动）
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
        .width('auto')          // 宽度由内容撑开，触发水平滚动
        .alignItems(HorizontalAlign.Start)
        .padding({ right: 16 }) // 留出滚动空间
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Auto)   // 显示水平滚动条
      .width('100%')
      .height('auto')            // 关键：高度由内容决定，垂直滚动交给外层
      .align(Alignment.TopStart)
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Auto)     // 显示垂直滚动条
    .width('100%')
    .height('100%')
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

        // 展开/收起箭头（仅文件夹）
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
          .flexShrink(0)

        // 文件名：完整显示，不截断，不压缩
        Text(node.name)
          .fontSize(13)
          .fontColor(node.path === this.selectedPath ? '#ffffff' : '#cccccc')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.None })
          .width('auto')
          .flexShrink(0)
      }
      .width('auto')          // 宽度由内容撑开，但点击区域包含 padding
      .height(36)             // 增加行高，扩大点击区域
      .padding({ left: 12, right: 12 })  // 左右 padding 扩大点击区域
      .backgroundColor(node.path === this.selectedPath ? '#37373d' : 'transparent')
      .borderRadius(3)
      .onClick(() => {
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

      // 递归子节点
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
    .width('auto')
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