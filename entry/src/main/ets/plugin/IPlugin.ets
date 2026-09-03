// entry/src/main/ets/plugin/IPlugin.ets

/**
 * 插件上下文接口，用于向插件传递所需服务
 */
export interface PluginContext {
  agent: object;      // 实际类型为 QemuFileSystem，但为避免循环引用，使用 object
  fileSystem: object; // 同上，或具体定义
  // 可按需扩展其他服务，如日志、通知等
}

/**
 * 插件接口，所有插件必须实现
 */
export interface IPlugin {
  id: string;
  name: string;
  canHandle(filePath: string): boolean;
  activate(context: PluginContext, filePath: string): Promise<void>;
}