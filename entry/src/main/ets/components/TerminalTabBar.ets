// entry/src/main/ets/components/TerminalTabBar.ets

import { TerminalSession } from '../services/TerminalManager';

interface ClickEventWithStop extends ClickEvent {
  stopPropagation?: () => void;
}

@Component
export struct TerminalTabBar {
  @Prop sessions: TerminalSession[] = [];
  @Prop activeId: string = '';

  onSwitch?: (id: string) => void;
  onClose?: (id: string) => void;
  onCreate?: () => void;

  build() {
    Row() {
      // 标签列表（水平滚动，靠左对齐）
      Scroll() {
        Row() {
          ForEach(this.sessions, (session: TerminalSession) => {
            this.buildTabItem(session);
          }, (session: TerminalSession) => session.id)
        }
        .height('100%')
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Start)
        .width('auto')
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .align(Alignment.Start)
      .layoutWeight(1)
      .height('100%')

      // "+" 按钮（固定在右侧）
      this.buildAddButton()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#252525')
    .padding({ left: 4, right: 4 })
  }

  @Builder
  buildTabItem(session: TerminalSession) {

    Row() {
      Text('>_ ' + session.name)
        .fontSize(13)
        .fontColor(session.id === this.activeId ? '#FFFFFF' : '#969696')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .flexShrink(0)
        .constraintSize({ minWidth: 40 })   // ✅ 修正：使用 constraintSize

      if (this.sessions.length > 1) {
        Text('✕')
          .fontSize(10)
          .fontColor('#666666')
          .margin({ left: 6 })
          .width(16)
          .height(16)
          .textAlign(TextAlign.Center)
          .borderRadius(2)
          .backgroundColor(session.id === this.activeId ? '#3C3C3C' : 'transparent')
          .flexShrink(0)
          .onClick((event: ClickEvent) => {
            const evt = event as ClickEventWithStop;
            if (evt.stopPropagation) {
              evt.stopPropagation();
            }
            if (this.onClose) {
              this.onClose(session.id);
            }
          })
      }
    }
    .padding({ left: 8, right: 4, top: 4, bottom: 4 })
    .backgroundColor(session.id === this.activeId ? '#3C3C3C' : 'transparent')
    .borderRadius(4)
    .margin({ right: 2 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      if (this.onSwitch) {
        this.onSwitch(session.id);
      }
    })
    .height(28)
    .flexShrink(0)
    .constraintSize({ minWidth: 50 })
  }

  @Builder
  buildAddButton() {
    Text('+')
      .fontSize(18)
      .fontColor('#969696')
      .width(28)
      .height(28)
      .textAlign(TextAlign.Center)
      .borderRadius(4)
      .flexShrink(0)
      .onClick(() => {
        if (this.onCreate) {
          this.onCreate();
        }
      })
      .margin({ left: 4 })
  }
}