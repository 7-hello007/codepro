// entry/src/main/ets/plugin/PluginManager.ets

import { IPlugin } from './IPlugin';
import { HtmlPreviewPlugin } from './HtmlPreviewPlugin';

export class PluginManager {
  private static instance: PluginManager;
  private plugins: IPlugin[] = [];

  private constructor() {}

  public static getInstance(): PluginManager {
    if (!PluginManager.instance) {
      PluginManager.instance = new PluginManager();
    }
    return PluginManager.instance;
  }

  public register(plugin: IPlugin): void {
    if (this.plugins.some(p => p.id === plugin.id)) {
      console.warn(`Plugin ${plugin.id} already registered, skip.`);
      return;
    }
    this.plugins.push(plugin);
    console.info(`[PluginManager] Plugin registered: ${plugin.id} (${plugin.name})`);
  }

  public findPlugin(filePath: string): IPlugin | undefined {
    console.info(`[PluginManager] findPlugin 查找文件: ${filePath}`);
    for (const plugin of this.plugins) {
      if (plugin.canHandle(filePath)) {
        console.info(`[PluginManager] 匹配到插件: ${plugin.id}`);
        return plugin;
      }
    }
    console.warn(`[PluginManager] 未找到匹配的插件`);
    return undefined;
  }

  public getAllPlugins(): IPlugin[] {
    return [...this.plugins];
  }

  public initDefaultPlugins(): void {
    console.info('[PluginManager] 初始化默认插件');
    this.register(new HtmlPreviewPlugin());
    console.info('[PluginManager] 默认插件初始化完成，当前插件数:', this.plugins.length);
  }
}