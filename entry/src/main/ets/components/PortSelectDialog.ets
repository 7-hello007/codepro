// entry/src/main/ets/components/PortSelectDialog.ets

import { PortMapping } from '../services/PortMappingService';

@Component
export struct PortSelectDialog {
  @Prop mappings: PortMapping[] = [];
  @Prop onConfirm?: (mapping: PortMapping) => void;
  @Prop onCancel?: () => void;

  build() {
    Column() {
      Text('选择端口映射')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#ffffff')
        .margin({ bottom: 16 })

      Text(`检测到 ${this.mappings.length} 个端口映射，请选择要使用的端口：`)
        .fontSize(14)
        .fontColor('#cccccc')
        .margin({ bottom: 16 })

      ForEach(this.mappings, (mapping: PortMapping) => {
        this.buildMappingItem(mapping);
      }, (mapping: PortMapping) => `${mapping.hostPort}-${mapping.guestPort}`)

      Row() {
        Button('取消')
          .onClick(() => {
            if (this.onCancel) this.onCancel();
          })
          .margin({ right: 12 })

        Button('确定')
          .onClick(() => {
            // 默认选中第一个
            if (this.onConfirm && this.mappings.length > 0) {
              this.onConfirm(this.mappings[0]);
            }
          })
      }
      .margin({ top: 16 })
      .justifyContent(FlexAlign.End)
    }
    .padding(24)
    .width('80%')
    .backgroundColor('#2d2d2d')
    .borderRadius(12)
  }

  @Builder
  buildMappingItem(mapping: PortMapping) {
    Row() {
      Text(`宿主机: ${mapping.hostPort}  →  虚拟机: ${mapping.guestPort}`)
        .fontSize(14)
        .fontColor('#e0e0e0')
    }
    .width('100%')
    .padding({ top: 8, bottom: 8, left: 12, right: 12 })
    .backgroundColor('#3a3a3a')
    .borderRadius(4)
    .margin({ bottom: 6 })
    .onClick(() => {
      if (this.onConfirm) this.onConfirm(mapping);
    })
  }
}