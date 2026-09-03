// entry/src/main/ets/components/EditorTabs.ets

import promptAction from '@ohos.promptAction';

export interface EditorTab {
  path: string;
  name: string;
  isActive: boolean;
}

// 扩展 ClickEvent，增加可选的 stopPropagation 方法
interface ClickEventWithStop extends ClickEvent {
  stopPropagation?: () => void;
}

@Component
export struct EditorTabs {
  @Prop tabs: string[] = [];
  @Prop activeTab: string = '';
  @Prop version: number = 0;
  @Prop showRunButton: boolean = false;

  onTabSwitch?: (path: string) => void;
  onTabClose?: (path: string) => void;
  onRunClick?: (path: string) => void;

  build() {
    Row() {
      Scroll() {
        Row() {
          ForEach(this.tabs, (tab: string) => {
            this.buildTabItem(tab);
          }, (tab: string) => tab)
        }
        .height('100%')
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Start)
        .width('auto')
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .height('100%')
      .align(Alignment.Start)

      if (this.showRunButton) {
        this.buildRunButton()
      } else {
        Row().width(32).height(32)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#252526')
    .padding({ left: 4, right: 4 })
  }

  @Builder
  buildTabItem(tab: string) {
    Row() {
      Text(this.getFileName(tab))
        .fontSize(13)
        .fontColor(tab === this.activeTab ? '#FFFFFF' : '#969696')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('✕')
        .fontSize(12)
        .fontColor('#969696')
        .margin({ left: 6 })
        .onClick((event: ClickEvent) => {
          // 转换为扩展接口，安全调用
          const evt = event as ClickEventWithStop;
          if (evt.stopPropagation) {
            evt.stopPropagation();
          }
          if (this.onTabClose) {
            this.onTabClose(tab);
          }
        })
        .width(16)
        .height(16)
        .textAlign(TextAlign.Center)
        .borderRadius(2)
        .backgroundColor(tab === this.activeTab ? '#3C3C3C' : 'transparent')
    }
    .padding({ left: 10, right: 6, top: 4, bottom: 4 })
    .backgroundColor(tab === this.activeTab ? '#3C3C3C' : 'transparent')
    .borderRadius(4)
    .margin({ right: 2 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      if (this.onTabSwitch) {
        this.onTabSwitch(tab);
      }
    })
    .height(30)
  }

  @Builder
  buildRunButton() {
    Text('▶')
      .fontSize(18)
      .fontColor(this.activeTab ? '#FFFFFF' : '#666666')
      .width(32)
      .height(32)
      .textAlign(TextAlign.Center)
      .borderRadius(4)
      .backgroundColor(this.activeTab ? '#007ACC' : 'transparent')
      .onClick(() => {
        if (this.activeTab) {
          if (this.onRunClick) {
            this.onRunClick(this.activeTab);
          }
        } else {
          promptAction.showToast({ message: '没有打开的文件' });
        }
      })
      .enabled(!!this.activeTab)
      .margin({ left: 4 })
  }

  private getFileName(fullPath: string): string {
    if (!fullPath) return '';
    const parts = fullPath.split('/');
    return parts[parts.length - 1] || fullPath;
  }
}