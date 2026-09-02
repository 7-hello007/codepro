// entry/src/main/ets/components/CreateDialog.ets
@CustomDialog
export struct CreateDialog {
  controller: CustomDialogController;
  @Prop dialogType: 'file' | 'folder';
  @Prop dialogParentPath: string; // 传入父路径（未使用但保留）
  @State inputValue: string = '';
  onConfirm: (name: string) => void = () => {};

  build() {
    Column() {
      Text(this.dialogType === 'file' ? '新建文件' : '新建文件夹')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 16 })
        .width('100%')
        .textAlign(TextAlign.Center)

      TextInput({
        placeholder: '请输入名称',
        text: this.inputValue
      })
        .width('100%')
        .defaultFocus(true)          // 自动获取焦点
        .onChange((value: string) => {
          this.inputValue = value;
        })
        .onSubmit(() => {            // 回车提交
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
    const name = this.inputValue.trim();
    if (name) {
      this.onConfirm(name);
      this.controller.close();
    }
  }
}