// entry/src/main/ets/components/OpenFolderDialog.ets
// import { CustomDialogController } from '@ohos.arkui';

@CustomDialog
export struct OpenFolderDialog {
  controller: CustomDialogController;
  @State inputValue: string = '/';
  onConfirm: (path: string) => void = () => {};

  build() {
    Column() {
      Text('打开文件夹')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 16 })
        .width('100%')
        .textAlign(TextAlign.Center)

      TextInput({
        placeholder: '请输入路径，如 /root 或 /mnt/share',
        text: this.inputValue
      })
        .width('100%')
        .defaultFocus(true)
        .onChange((value: string) => {
          this.inputValue = value;
        })
        .onSubmit(() => {
          this.submit();
        })
        .margin({ bottom: 16 })

      Row() {
        Button('取消')
          .width('45%')
          .onClick(() => {
            this.controller.close();
          })
        Button('确定')
          .width('45%')
          .enabled(this.inputValue.trim().length > 0)
          .onClick(() => {
            this.submit();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .padding(20)
    .width('90%')
    .backgroundColor('#2d2d2d')
    .borderRadius(12)
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
  }

  private submit() {
    const path = this.inputValue.trim();
    if (path) {
      this.onConfirm(path);
      this.controller.close();
    }
  }
}