// entry/src/main/ets/plugin/HtmlPreviewPlugin.ets

import { IPlugin, PluginContext } from './IPlugin';
import { PortMappingService } from '../services/PortMappingService';
import { PortMapping } from '../model/Emulator';
import { common } from '@kit.AbilityKit';
import { Want } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import { BusinessError } from '@kit.BasicServicesKit';
import { QemuFileSystem } from '../lib/QemuFileSystem';

export class HtmlPreviewPlugin implements IPlugin {
  id: string = 'html-preview';
  name: string = 'HTML 预览';

  canHandle(filePath: string): boolean {
    const ext = this.getFileExtension(filePath);
    console.info('[HtmlPreviewPlugin] canHandle:', filePath, 'ext:', ext);
    return ext === '.html' || ext === '.htm';
  }

  async activate(context: PluginContext, filePath: string): Promise<void> {
    console.info('[HtmlPreviewPlugin] activate 被调用, 文件:', filePath);

    try {
      const portService = PortMappingService.getInstance();
      portService.loadMappings();

      const allMappings = portService.getMappings();
      console.info('[HtmlPreviewPlugin] 映射数量:', allMappings.length);

      let mapping: PortMapping | null = portService.getBestMatchForFile(filePath);

      if (mapping === null && portService.getMappings().length > 1) {
        const mappings = portService.getMappings();
        if (mappings.length > 0) {
          mapping = mappings[0];
          const hostPort = portService.getHostPort(mapping);
          promptAction.showToast({
            message: `使用端口 ${hostPort}（共 ${mappings.length} 个映射）`,
            duration: 1500
          });
        }
      }

      if (mapping === null) {
        promptAction.showToast({ message: '请先配置端口映射（如：8000 -> 8000）' });
        return;
      }

      const hostPort = portService.getHostPort(mapping);
      const qemuFs: QemuFileSystem = context.qemuFs;
      const dirPath: string = this.getDirectoryPath(filePath);
      const fileName: string = this.getFileName(filePath);

      // ===== 启动 HTTP 服务 =====
      if (qemuFs) {
        console.info('[HtmlPreviewPlugin] 准备启动 HTTP 服务...');
        promptAction.showToast({ message: '正在启动 HTTP 服务...', duration: 2000 });

        await this.execCommand(qemuFs, 'pkill -f "python -m http.server" 2>/dev/null || true');
        await this.sleep(500);

        const startCmd: string = 'cd ' + dirPath + ' && python -m http.server ' + hostPort + ' > /dev/null 2>&1 &';
        await this.execCommand(qemuFs, startCmd);
        await this.sleep(1000);
        console.info('[HtmlPreviewPlugin] HTTP 服务已启动，根目录:', dirPath);
      } else {
        console.warn('[HtmlPreviewPlugin] 无法获取 QemuFileSystem');
        promptAction.showToast({ message: '无法自动启动 HTTP 服务，请手动启动', duration: 2000 });
        return;
      }

      // ===== 直接打开原文件（无热加载，手动刷新）=====
      const timestamp: number = Date.now();
      const finalUrl: string = `http://localhost:${hostPort}/${fileName}?t=${timestamp}`;
      console.info('[HtmlPreviewPlugin] 最终 URL:', finalUrl);

      const abilityContext = AppStorage.get<common.UIAbilityContext>('abilityContext');
      if (!abilityContext) {
        promptAction.showToast({ message: '无法获取 Ability Context' });
        return;
      }

      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: finalUrl,
        parameters: {
          'ohos.extra.param.key.contentTitle': `预览: ${fileName}`
        }
      };

      await abilityContext.startAbility(want);
      promptAction.showToast({ message: `浏览器已打开: ${finalUrl}` });

    } catch (error) {
      const err = error as BusinessError;
      console.error('[HtmlPreviewPlugin] 错误:', err.message);
      promptAction.showToast({ message: `预览失败: ${err.message || '未知错误'}` });
    }
  }

  // ===== 执行命令 =====
  private async execCommand(qemuFs: QemuFileSystem, command: string): Promise<string> {
    try {
      const result: string = await qemuFs.execAndGetOutput('/bin/sh', ['-c', command]);
      return result || '';
    } catch (error) {
      const err = error as Error;
      console.warn('[HtmlPreviewPlugin] 命令执行失败:', command, err.message);
      return '';
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, ms);
    });
  }

  private getDirectoryPath(filePath: string): string {
    const lastSlash: number = filePath.lastIndexOf('/');
    if (lastSlash > 0) {
      return filePath.substring(0, lastSlash);
    }
    return '/home';
  }

  private getFileName(filePath: string): string {
    const parts: string[] = filePath.split('/');
    return parts[parts.length - 1] || 'index.html';
  }

  private getFileExtension(path: string): string {
    const lastDot: number = path.lastIndexOf('.');
    if (lastDot === -1) return '';
    return path.substring(lastDot).toLowerCase();
  }
}