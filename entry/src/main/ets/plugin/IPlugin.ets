// entry/src/main/ets/plugin/IPlugin.ets

import { QemuFileSystem } from '../lib/QemuFileSystem';

export interface PluginContext {
  qemuFs: QemuFileSystem;
}

export interface IPlugin {
  id: string;
  name: string;
  canHandle(filePath: string): boolean;
  activate(context: PluginContext, filePath: string): Promise<void>;
}