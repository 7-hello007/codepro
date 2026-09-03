// entry/src/main/ets/plugin/PluginManager.ets

import { IPlugin } from './IPlugin';

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
    console.info(`Plugin registered: ${plugin.id} (${plugin.name})`);
  }

  public findPlugin(filePath: string): IPlugin | undefined {
    return this.plugins.find(p => p.canHandle(filePath));
  }

  public getAllPlugins(): IPlugin[] {
    return [...this.plugins];
  }

  /**
   * 初始化默认插件，目前为空，阶段6.5会注册 HTML 预览插件
   */
  public initDefaultPlugins(): void {
    // 后续在此注册插件
    console.info('Default plugins initialized (none yet).');
  }
}