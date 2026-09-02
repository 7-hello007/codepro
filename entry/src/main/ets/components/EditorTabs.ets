// entry/src/main/ets/components/EditorTabs.ets

export interface EditorTab {
  path: string;
  name: string;
  isActive: boolean;
}

@Component
export struct EditorTabs {

  @Prop tabs: EditorTab[] = [];
  @Prop version: number = 0;

  onTabSwitch?: (path: string) => void;
  onTabClose?: (path: string) => void;

  // 格式化文件名：≤20完整显示，>20显示前17+...后缀
  private formatFileName(fullPath: string): string {
    const parts = fullPath.split('/');
    const fileName = parts[parts.length - 1] || fullPath;
    if (fileName.length <= 20) {
      return fileName;
    }
    const extIndex = fileName.lastIndexOf('.');
    if (extIndex === -1) {
      // 无扩展名，直接截取前17个字符
      return fileName.substring(0, 17) + '...';
    }
    const name = fileName.substring(0, extIndex);
    const ext = fileName.substring(extIndex);
    const maxNameLen = 17 - ext.length; // 留给名称的最大长度
    if (maxNameLen <= 0) {
      // 扩展名本身较长，仅显示扩展名
      return '...' + ext;
    }
    return name.substring(0, maxNameLen) + '...' + ext;
  }

  build() {
    Row() {
      Scroll() {
        Row() {
          ForEach(
            this.tabs,
            (tab: EditorTab) => {
              Row() {
                Text(this.formatFileName(tab.path))
                  .fontSize(13)
                  .fontColor(tab.isActive ? '#ffffff' : '#888888')
                  .fontWeight(tab.isActive ? FontWeight.Bold : FontWeight.Normal)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Clip }) // 因为我们自己截断，不会溢出
                  .flexShrink(0) // 防止压缩

                Text('×')
                  .fontSize(15)
                  .fontColor(tab.isActive ? '#cccccc' : '#777777')
                  .margin({ left: 4 })
                  .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                  .width(24)
                  .height(24)
                  .textAlign(TextAlign.Center)
                  .flexShrink(0)
                  .onClick(() => {
                    if (this.onTabClose) {
                      this.onTabClose(tab.path);
                    }
                  })
              }
              .padding({ left: 10, right: 4, top: 4, bottom: 4 })
              .margin({ right: 3 })
              .height(32)
              .backgroundColor(tab.isActive ? '#2d2d2d' : '#252525')
              .borderRadius(4)
              .border({ width: tab.isActive ? 1 : 0, color: '#3d3d3d' })
              .flexShrink(0)      // 不压缩，内容撑开
              .onClick(() => {
                if (this.onTabSwitch && !tab.isActive) {
                  this.onTabSwitch(tab.path);
                }
              })
            },
            (tab: EditorTab) => tab.path + '_' + this.version
          )
        }
        .padding({ left: 4, right: 4 })
        .height('100%')
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Start)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Auto)
      .layoutWeight(1)
      .height('100%')
      .align(Alignment.Start)
    }
    .width('100%')
    .height(36)
    .backgroundColor('#252525')
    .padding({ left: 4, right: 4 })
  }
}