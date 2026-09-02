// entry/src/main/ets/lib/QemuFileSystem.ets
import { QemuAgent } from './QemuAgent';
import { FileNode } from '../components/FileTree';

export class QemuFileSystem {
  private agent: QemuAgent | null = null;
  public currentPath: string = '/root';

  /**
   * 绑定 QemuAgent 实例
   */
  bindAgent(agent: QemuAgent): void {
    this.agent = agent;
    console.info('[QemuFileSystem] Agent bound successfully');
  }

  /**
   * 检查 agent 是否可用
   */
  isReady(): boolean {
    return this.agent !== null && this.agent.isAlive();
  }

  /**
   * 内部通用执行器
   */
  private async exec(cmd: string, args: string[] = []): Promise<string | null> {
    if (!this.agent) {
      console.error('[QemuFileSystem] Agent is not bound');
      return null;
    }
    // 注意：这里未使用 cd，直接执行
    return await this.agent.execAndGetOutput(cmd, args);
  }

  /**
   * 获取当前工作目录
   */
  async getCurrentDirectory(): Promise<string> {
    const output = await this.exec('/bin/pwd');
    return output ? output.trim() : this.currentPath;
  }

  // 在 QemuFileSystem 类中添加以下方法

  /**
   * 创建目录（支持递归）
   */
  async mkdir(path: string): Promise<boolean> {
    const result = await this.exec('/bin/mkdir', ['-p', path]);
    return result !== null;
  }

  /**
   * 创建空文件
   */
  async touch(path: string): Promise<boolean> {
    const result = await this.exec('/bin/touch', [path]);
    return result !== null;
  }

  /**
   * 删除文件或目录（默认递归删除）
   */
  async rm(path: string, recursive: boolean = true): Promise<boolean> {
    const args = recursive ? ['-rf', path] : ['-f', path];
    const result = await this.exec('/bin/rm', args);
    return result !== null;
  }

  /**
   * 列出指定目录内容
   */
  async listDirectory(path?: string): Promise<FileNode[]> {
    const targetPath = path || this.currentPath;
    this.currentPath = targetPath;

    const output = await this.exec('/bin/ls', ['-lA', targetPath]);
    if (!output) {
      console.warn('[QemuFileSystem] listDirectory 返回空，路径:', targetPath);
      return [];
    }
    return this.parseLsOutput(output, targetPath);
  }

  /**
   * 读取文件内容（UTF-8）
   * @param path 虚拟机内绝对路径
   * @returns 文件内容字符串，失败返回 null
   */
  async readFile(path: string): Promise<string | null> {
    if (!this.agent) {
      console.error('[QemuFileSystem] Agent not bound');
      return null;
    }
    try {
      const output = await this.agent.execAndGetOutput('/bin/cat', [path]);
      return output; // 已是 UTF-8 字符串
    } catch (e) {
      console.error(`[QemuFileSystem] readFile failed: ${path}`, e);
      return null;
    }
  }

  /**
   * 写入文件内容（覆盖模式）
   * @param path 虚拟机内绝对路径
   * @param content 文件内容
   * @returns 是否成功
   */
  async writeFile(path: string, content: string): Promise<boolean> {
    if (!this.agent) {
      console.error('[QemuFileSystem] Agent not bound');
      return false;
    }
    try {
      // 使用 printf 转义单引号，避免注入
      const escaped = content.replace(/'/g, "'\\''");
      const cmd = `printf '%s' '${escaped}' > ${path}`;
      const result = await this.agent.execAndGetOutput('/bin/sh', ['-c', cmd]);
      return result !== null;
    } catch (e) {
      console.error(`[QemuFileSystem] writeFile failed: ${path}`, e);
      return false;
    }
  }

  /**
   * 解析 ls -lA 输出
   */
  private parseLsOutput(output: string, basePath: string): FileNode[] {
    const lines = output.split('\n').filter(line => line.trim() !== '' && !line.startsWith('total '));
    const nodes: FileNode[] = [];

    for (const line of lines) {
      // 正则匹配：权限(10字符) + 空格 + 硬链接数 + 属主 + 组 + 大小 + 月 + 日 + 时间/年份 + 文件名
      const parts = line.match(
        /^([\-dl])([\-rwxs]){9}\s+\d+\s+\S+\s+\S+\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.*)$/
      );
      if (!parts) continue;

      const isDir = parts[1] === 'd';
      const size = parseInt(parts[3], 10) || 0;
      let name = parts[7];
      const arrowIndex = name.indexOf(' -> ');
      if (arrowIndex !== -1) {
        name = name.substring(0, arrowIndex);
      }
      if (name === '.' || name === '..') continue;

      const fullPath = basePath + '/' + name;
      nodes.push({
        name: name,
        path: fullPath,
        isDir: isDir,
        isExpanded: false,
        children: isDir ? [] : undefined
      } as FileNode);
    }

    nodes.sort((a, b) => {
      if (a.isDir && !b.isDir) return -1;
      if (!a.isDir && b.isDir) return 1;
      return a.name.localeCompare(b.name);
    });

    return nodes;
  }
}