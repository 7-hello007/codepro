// entry/src/main/ets/components/PluginListDialog.ets

import { IPlugin } from '../plugin/IPlugin';

@CustomDialog
export struct PluginListDialog {
  @Prop plugins: IPlugin[] = [];
  controller?: CustomDialogController;
  onClose?: () => void;

  private testExtensions: string[] = [
    '.html', '.htm', '.js', '.ts', '.jsx', '.tsx',
    '.vue', '.py', '.json', '.css', '.scss', '.xml',
    '.yaml', '.yml', '.md', '.txt', '.sh', '.c', '.cpp'
  ];

  build() {
    Column() {
      Row() {
        Text('🔌 插件管理')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#ffffff')
        Blank()
        Text('✕')
          .fontSize(20)
          .fontColor('#888888')
          .onClick(() => {
            if (this.controller) {
              this.controller.close();
            }
            if (this.onClose) {
              this.onClose();
            }
          })
      }
      .width('100%')
      .padding({ bottom: 12 })

      Divider()
        .height(1)
        .color('#3a3a3c')
        .width('100%')

      Text(`共 ${this.plugins.length} 个插件`)
        .fontSize(14)
        .fontColor('#8b949e')
        .width('100%')
        .padding({ top: 8, bottom: 8 })

      Scroll() {
        Column() {
          ForEach(this.plugins, (plugin: IPlugin) => {
            this.buildPluginItem(plugin);
          }, (plugin: IPlugin) => plugin.id)
        }
        .width('100%')
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Auto)
      .layoutWeight(1)
    }
    .width('90%')
    .constraintSize({ maxWidth: 600 })
    .height('80%')
    .constraintSize({ maxHeight: 600 })
    .backgroundColor('#1e1e1e')
    .borderRadius(12)
    .padding(16)
    .justifyContent(FlexAlign.Start)   // 内容靠顶部
  }

  @Builder
  buildPluginItem(plugin: IPlugin) {
    Column() {
      Row() {
        Text('📦')
          .fontSize(16)
          .margin({ right: 8 })

        Text(plugin.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#e6edf3')
          .flexShrink(0)

        Text(`ID: ${plugin.id}`)
          .fontSize(12)
          .fontColor('#484f58')
          .margin({ left: 12 })
          .flexShrink(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .maxLines(1)

        Blank()

        Text('✅ 已启用')
          .fontSize(12)
          .fontColor('#3fb950')
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor('rgba(63,185,80,0.15)')
          .borderRadius(12)
      }
      .width('100%')
      .padding({ bottom: 8 })

      this.buildSupportedExtensions(plugin)

      Divider()
        .height(1)
        .color('#2d2d2d')
        .margin({ top: 10, bottom: 10 })
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
  }

  @Builder
  buildSupportedExtensions(plugin: IPlugin) {
    Row() {
      Text('📁 支持: ')
        .fontSize(13)
        .fontColor('#8b949e')
        .margin({ right: 4 })

      Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
        ForEach(this.testExtensions, (ext: string) => {
          if (plugin.canHandle('file' + ext)) {
            Text(ext)
              .fontSize(12)
              .fontColor('#e6edf3')
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .backgroundColor('#2d2d2d')
              .borderRadius(4)
              .margin({ right: 4, bottom: 4 })
          }
        }, (ext: string) => ext)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}