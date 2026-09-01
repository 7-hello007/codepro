// entry/src/main/ets/pages/Index.ets
import { CustomContentDialog } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import WebTerminal from '../components/WebTerminal';
import SettingsContent from '../components/SettingsContent';
import { SharedFolderContent } from '../components/SharedFolderContent';
import appOption from '../model/appOption';
import { util } from '@kit.ArkTS';
import EmulatorListGrid from '../components/EmulatorListGrid';
import EditEmulatorContent from '../components/EditEmulatorContent';
import { Emulator } from '../model/Emulator';
import RootfsManagementContent from '../components/RootfsManagementContent';
import UserGuide from '../components/UserGuide';
import { webview } from '@kit.ArkWeb';
import VmStatusBar from '../components/VmStatusBar';
import { IdeLayout } from './IDELayout';
import { window } from '@kit.ArkUI';
// ===== 只导入 common 用于类型转换 =====
import { common } from '@kit.AbilityKit';

@Component
struct PcIndex {
  // 完整的 PcIndex 代码（与之前相同，此处保留所有）
  @StorageProp(appOption.sharedHost) sharedHost?: string = undefined;
  @StorageProp(appOption.sharedGuest) sharedGuest?: string = undefined;
  @StorageProp(appOption.displayStatusBar) displayStatusBar: boolean = false;

  emulatorManagementController: CustomDialogController = new CustomDialogController({
    builder: CustomContentDialog({
      primaryTitle: $r('app.string.emulator_management_title'),
      contentBuilder: (): void => {
        this.buildSimulatorManagement();
      }
    })
  });

  rootfsManagementController: CustomDialogController = new CustomDialogController({
    builder: CustomContentDialog({
      primaryTitle: $r('app.string.image_management_title'),
      contentBuilder: (): void => {
        this.buildRootfsManagement();
      }
    })
  });

  sharedFolderController: CustomDialogController = new CustomDialogController({
    builder: CustomContentDialog({
      primaryTitle: $r('app.string.setting_shared_folder'),
      contentBuilder: (): void => {
        this.buildSharedFolder();
      }
    })
  });

  settingController: CustomDialogController = new CustomDialogController({
    builder: CustomContentDialog({
      primaryTitle: $r('app.string.Setting_title'),
      contentBuilder: (): void => {
        this.buildSettings();
      }
    })
  });

  userGuideController: CustomDialogController = new CustomDialogController({
    builder: CustomContentDialog({
      primaryTitle: $r('app.string.user_guide_title'),
      contentBuilder: (): void => {
        this.buildGuideList();
      }
    })
  });

  webController = new webview.WebviewController();

  build(): void {
    Column() {
      Row() {
        Row() {
          Image($r('app.media.startIcon')).width(20);
          Text($r('app.string.EntryAbility_label'))
            .fontColor($r('sys.color.white'))
            .margin({ left: 10 });
        }

        if (this.displayStatusBar) {
          VmStatusBar({ reactive: false }).margin({ left: 20 });
        }

        Blank();

        Row() {
          Button({
            type: ButtonType.Normal,
            buttonStyle: ButtonStyleMode.TEXTUAL,
            controlSize: ControlSize.SMALL
          }) {
            SymbolGlyph($r('sys.symbol.display'))
              .fontSize('20vp')
              .width(20)
              .height(20)
              .fontColor(['#ffffff']);
          }
          .borderRadius(4)
          .padding(4)
          .margin({ right: 10 })
          .onClick((): void => {
            const vncEnabled = AppStorage.get<boolean>(appOption.vncEnabled)!!;
            if (vncEnabled) {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/VncPage' });
            } else {
              this.getUIContext().getPromptAction().showToast({ message: $r('app.string.vnc_service_not_started') });
            }
          });

          Button({
            type: ButtonType.Normal,
            buttonStyle: ButtonStyleMode.TEXTUAL,
            controlSize: ControlSize.SMALL
          }) {
            SymbolGlyph($r('sys.symbol.more'))
              .fontSize('20vp')
              .width(20)
              .height(20)
              .fontColor(['#ffffff']);
          }
          .borderRadius(4)
          .padding(4)
          .margin({ right: 10 })
          .onClick((): void => {
            this.emulatorManagementController.open();
          });

          Button({
            type: ButtonType.Normal,
            buttonStyle: ButtonStyleMode.TEXTUAL,
            controlSize: ControlSize.SMALL
          }) {
            SymbolGlyph($r('sys.symbol.externaldrive_3'))
              .fontSize('20vp')
              .width(20)
              .height(20)
              .fontColor(['#ffffff']);
          }
          .borderRadius(4)
          .padding(4)
          .margin({ right: 10 })
          .onClick((): void => {
            this.rootfsManagementController.open();
          });

          Button({
            type: ButtonType.Normal,
            buttonStyle: ButtonStyleMode.TEXTUAL,
            controlSize: ControlSize.SMALL
          }) {
            Image($r('app.media.folder')).width(20);
          }
          .borderRadius(4)
          .padding(4)
          .margin({ right: 10 })
          .onClick((): void => {
            this.sharedFolderController.open();
          });

          Button({
            type: ButtonType.Normal,
            buttonStyle: ButtonStyleMode.TEXTUAL,
            controlSize: ControlSize.SMALL
          }) {
            Image($r('app.media.gearshape')).width(20);
          }
          .borderRadius(4)
          .padding(4)
          .margin({ right: 10 })
          .onClick((): void => {
            this.settingController.open();
          });

          Button({
            type: ButtonType.Normal,
            buttonStyle: ButtonStyleMode.TEXTUAL,
            controlSize: ControlSize.SMALL
          }) {
            SymbolGlyph($r('sys.symbol.book_pages'))
              .fontSize('20vp')
              .width(20)
              .height(20)
              .fontColor(['#ffffff']);
          }
          .borderRadius(4)
          .padding(4)
          .onClick((): void => {
            this.userGuideController.open();
          });
        }
      }
      .width('100%')
      .height(48)
      .padding({ left: 15, right: 150 });

      WebTerminal({ virtKeyEnabled: false }).layoutWeight(1);
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  buildSimulatorManagement(): void {
    Column() {
      EmulatorListGrid({
        onEditEmulator: (item, edit): void => {
          this.openEditEmulatorDialog(item, edit);
        },
        specifiedBreak: 'xs'
      });
      Button($r('app.string.btn_add'))
        .width('100%')
        .onClick((): void => {
          const id = util.generateRandomUUID();
          const emulatorToEdit: Emulator = {
            id,
            name: '',
            init: '/init',
            cpu: 1,
            memory: 512,
            portMapping: [],
            rootVda: '/dev/sda',
            rootFilesystem: '',
            sharedFolderReadonly: false
          };
          this.openEditEmulatorDialog(emulatorToEdit, true);
        });
    }
  }

  private openEditEmulatorDialog(item: Emulator, edit: boolean): void {
    const emulatorToEdit: Emulator = {
      id: item.id,
      name: item.name,
      init: item.init,
      cpu: item.cpu,
      memory: item.memory,
      portMapping: item.portMapping,
      rootVda: item.rootVda,
      rootFilesystem: item.rootFilesystem,
      sharedFolderReadonly: item.sharedFolderReadonly
    };
    const controller = new CustomDialogController({
      builder: CustomContentDialog({
        primaryTitle: edit ? $r('app.string.edit_emulator_title') : item.name,
        contentBuilder: (): void => {
          this.buildEditEmulator(emulatorToEdit, edit, (): void => controller.close());
        }
      })
    });
    controller.open();
  }

  @Builder
  buildRootfsManagement(): void {
    Column() {
      RootfsManagementContent({
        toolBar: false,
        specifiedBreak: 'xs'
      });
    }
  }

  @Builder
  buildEditEmulator(emulator: Emulator, edit: boolean, onFinished: (item: Emulator) => void): void {
    EditEmulatorContent({
      emulator: emulator,
      onFinished: onFinished,
      specifiedBreak: 'xs',
      titleBar: false,
      editing: edit
    });
  }

  @Builder
  buildGuideList(): void {
    UserGuide({
      openPage: (title: string | Resource, url: string): void => {
        const controller = new CustomDialogController({
          builder: CustomContentDialog({
            primaryTitle: title,
            contentBuilder: (): void => {
              this.buildGuideWebView(url);
            }
          })
        });
        controller.open();
      }
    });
  }

  @Builder
  private buildGuideWebView(url: string): void {
    Web({
      src: $rawfile(url),
      controller: this.webController
    })
      .javaScriptProxy({
        permission: `{
          "javascriptProxyPermission": {
            "urlPermissionList": [
              {
                "scheme": "resource",
                "host": "rawfile",
                "port": "",
                "path": ""
              }
            ]
          }
        }`,
        object: this,
        name: 'native',
        methodList: [],
        controller: this.webController
      })
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.black'));
  }

  @Builder
  buildSettings(): void {
    SettingsContent();
  }

  @Builder
  buildSharedFolder(): void {
    Row() {
      if (this.sharedHost) {
        SharedFolderContent({
          host: this.sharedHost,
          guest: this.sharedGuest
        });
      }
    }
  }
}

@Component
struct PhoneOrTablet {
  @StorageProp(appOption.displayStatusBar) displayStatusBar: boolean = false;

  build(): void {
    Column() {
      if (this.displayStatusBar) {
        Row() {
          VmStatusBar({ reactive: true }).layoutWeight(1);
        }
        .width('100%')
        .height(28)
        .padding({ left: 6, right: 6 })
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'));
      }

      WebTerminal({ virtKeyEnabled: true }).layoutWeight(1);
    }
    .width('100%')
    .height('100%');
  }
}

@Entry
@Component
struct Index {
  isPc: boolean = deviceInfo.deviceType === '2in1';
  @State isIdeMode: boolean = true;

  aboutToAppear(): void {
    // ===== 强制设置窗口背景色 =====
    try {
      // getContext 是全局函数，不需要导入
      const context = getContext(this) as common.UIAbilityContext;
      window.getLastWindow(context).then((win: window.Window) => {
        win.setWindowBackgroundColor('#1e1e1e');
      }).catch((err: Error) => {
        console.error('设置窗口背景失败:', err.message);
      });
    } catch (e) {
      console.error('获取上下文失败:', e);
    }
    // ===== 结束 =====
  }

  build(): void {
    // 直接使用 IdeLayout，不传任何参数
    if (this.isIdeMode) {
      IdeLayout();
    } else if (this.isPc) {
      PcIndex();
    } else {
      PhoneOrTablet();
    }
  }
}