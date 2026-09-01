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

  build() {
    Row() {
      Scroll() {
        Row() {
          ForEach(
            this.tabs,
            (tab: EditorTab) => {
              Row() {
                Text(tab.name)
                  .fontSize(13)
                  .fontColor(tab.isActive ? '#ffffff' : '#888888')
                  .fontWeight(tab.isActive ? FontWeight.Bold : FontWeight.Normal)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)

                Text('×')
                  .fontSize(15)
                  .fontColor(tab.isActive ? '#cccccc' : '#777777')
                  .margin({ left: 4 })
                  .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                  .width(24)
                  .height(24)
                  .textAlign(TextAlign.Center)
                  .onClick(() => {
                    if (this.onTabClose) {
                      this.onTabClose(tab.path);
                    }
                  })
              }
              .padding({ left: 10, right: 4, top: 4, bottom: 4 })
              .margin({ right: 3 })
              .width(150)                // 固定宽度保证每个标签大小一致
              .height(32)
              .backgroundColor(tab.isActive ? '#2d2d2d' : '#252525')
              .borderRadius(4)
              .border({ width: tab.isActive ? 1 : 0, color: '#3d3d3d' })
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
        // 关键：不设置 width，让 Row 自适应内容宽度
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Start)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Auto)
      .layoutWeight(1)          // 占据剩余宽度，限制视口
      .height('100%')
      .align(Alignment.Start)   // 确保滚动条从左侧开始
    }
    .width('100%')
    .height(36)
    .backgroundColor('#252525')
    .padding({ left: 4, right: 4 })
  }
}