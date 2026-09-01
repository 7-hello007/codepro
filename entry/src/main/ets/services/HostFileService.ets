// entry/src/main/ets/services/HostFileService.ets
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import { common } from '@kit.AbilityKit';

export interface SampleFile {
  path: string;
  content: string;
}

/**
 * 宿主文件系统服务
 * 负责读写宿主设备上的文件，以及创建示例文件
 */
export class HostFileService {
  private workDir: string = '';

  /**
   * 初始化工作目录（应用沙箱内的 files 目录）
   */
  initializeWorkDirectory(context: common.UIAbilityContext): void {
    try {
      this.workDir = context.filesDir;
      console.info('📂 工作目录:', this.workDir);
    } catch (e) {
      console.error('❌ 获取上下文失败:', e);
      this.workDir = '/data/storage/el2/base/haps/entry/files';
    }
  }

  getWorkDir(): string {
    return this.workDir;
  }

  /**
   * 创建示例文件（如果不存在）
   */
  createSampleFiles(): void {
    const sampleFiles: SampleFile[] = [
      {
        path: this.workDir + '/src/main.ets',
        content: `// main.ets\n// HiSH-IDE 示例项目\n// ArkTS 应用入口\n\nimport { UIAbility } from '@kit.AbilityKit';\n\nexport default class MainAbility extends UIAbility {\n  onCreate(): void {\n    console.info('HiSH-IDE 应用启动');\n  }\n  onDestroy(): void {\n    console.info('HiSH-IDE 应用退出');\n  }\n}\n`
      },
      {
        path: this.workDir + '/README.md',
        content: `# HiSH-IDE\n\n这是一个运行在 HarmonyOS 平台上的轻量级 IDE 示例项目。\n\n## 功能\n\n- 文件树\n- Monaco 代码编辑器\n- 多文件 Tab\n- 文件保存\n- 终端模拟器\n\n## 使用方式\n\n点击左侧文件即可在中间编辑器打开。\n`
      },
      {
        path: this.workDir + '/utils/helper.ets',
        content: `// helper.ets\n// 工具函数\n\nexport function add(a: number, b: number): number {\n  return a + b;\n}\n\nexport function multiply(a: number, b: number): number {\n  return a * b;\n}\n`
      },
      {
        path: this.workDir + '/config.json',
        content: `{\n  "name": "HiSH-IDE",\n  "version": "1.0.0",\n  "platform": "HarmonyOS",\n  "editor": "Monaco"\n}\n`
      }
    ];

    for (const file of sampleFiles) {
      try {
        fs.statSync(file.path);
        continue; // 已存在，跳过
      } catch (e) {
        // 创建目录
        const dir = file.path.substring(0, file.path.lastIndexOf('/'));
        try {
          fs.statSync(dir);
        } catch (e) {
          fs.mkdirSync(dir);
        }
        let fd: number = -1;
        try {
          const f = fs.openSync(file.path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
          fd = f.fd;
          fs.writeSync(fd, file.content);
          console.info('✅ 创建示例文件:', file.path);
        } catch (err) {
          console.error('❌ 创建示例文件失败:', file.path, err);
        } finally {
          if (fd !== -1) fs.closeSync(fd);
        }
      }
    }
  }

  /**
   * 读取文件内容（文本）
   */
  readFile(path: string): string {
    let fd: number = -1;
    try {
      const f = fs.openSync(path, fs.OpenMode.READ_ONLY);
      fd = f.fd;
      const stat = fs.statSync(path);
      const buffer = new ArrayBuffer(stat.size);
      fs.readSync(fd, buffer);
      const decoder = new util.TextDecoder('utf-8');
      return decoder.decode(new Uint8Array(buffer));
    } catch (err) {
      console.error('❌ 读取文件失败:', path, err);
      throw new Error(String(err));
    } finally {
      if (fd !== -1) fs.closeSync(fd);
    }
  }

  /**
   * 写入文件内容（文本）
   */
  writeFile(path: string, content: string): void {
    let fd: number = -1;
    try {
      const f = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fd = f.fd;
      fs.writeSync(fd, content);
    } catch (err) {
      console.error('❌ 写入文件失败:', path, err);
      throw new Error(String(err));
    } finally {
      if (fd !== -1) fs.closeSync(fd);
    }
  }

  /**
   * 获取文件的最后修改时间字符串
   */
  getLastModifiedTime(path: string): string {
    try {
      const stat = fs.statSync(path);
      const mtime = new Date(stat.mtime);
      return (
        String(mtime.getHours()).padStart(2, '0') + ':' +
        String(mtime.getMinutes()).padStart(2, '0') + ':' +
        String(mtime.getSeconds()).padStart(2, '0') + ' ' +
        mtime.getFullYear() + '-' +
        String(mtime.getMonth() + 1).padStart(2, '0') + '-' +
        String(mtime.getDate()).padStart(2, '0')
      );
    } catch (e) {
      return '';
    }
  }

  /**
   * 生成演示内容（当真实文件不存在时使用）
   */
  getDemoContent(path: string): string {
    const fileName = path.split('/').pop() || '';
    const ext = path.split('.').pop()?.toLowerCase() || '';
    const exactDemos: Record<string, string> = {
      'main.ets': `// main.ets\n// HiSH-IDE 示例代码\n\nimport { UIAbility } from '@kit.AbilityKit';\n\nexport default class MainAbility extends UIAbility {\n  onCreate(): void {\n    console.info('应用已启动');\n  }\n}\n`,
      'helper.ets': `// helper.ets\n\nexport function add(a: number, b: number): number {\n  return a + b;\n}\n`,
      'readme.md': `# HiSH-IDE\n\nHarmonyOS IDE 示例项目。\n\n点击左侧文件查看代码。\n`,
      'config.json': `{\n  "name": "HiSH-IDE",\n  "version": "1.0.0"\n}\n`
    };
    const lowerFileName = fileName.toLowerCase();
    for (const key of Object.keys(exactDemos)) {
      if (lowerFileName === key.toLowerCase()) return exactDemos[key];
    }
    switch (ext) {
      case 'ets': return `// ${fileName}\n\n@Component\nexport struct ${this.safeIdentifier(fileName)} {\n  build() {\n    Column() {\n      Text('${fileName}')\n        .fontSize(20)\n    }\n  }\n}\n`;
      case 'ts': return `// ${fileName}\n\nexport function hello(): string {\n  return 'Hello from ${fileName}';\n}\n`;
      case 'js': return `// ${fileName}\n\nfunction hello() {\n  console.log('Hello from ${fileName}');\n}\n`;
      case 'json': return `{\n  "file": "${fileName}",\n  "type": "json"\n}\n`;
      case 'py': return `# ${fileName}\n\ndef main():\n    print("Hello from ${fileName}")\n\nif __name__ == "__main__":\n    main()\n`;
      case 'md': return `# ${fileName}\n\n这是一个示例 Markdown 文件。\n`;
      default: return `// ${fileName}\n\n// 请编辑此文件\n`;
    }
  }

  private safeIdentifier(fileName: string): string {
    const base = fileName.replace(/\.[^.]+$/, '');
    const clean = base.replace(/[^a-zA-Z0-9_]/g, '_');
    if (!clean) return 'Example';
    if (/^[0-9]/.test(clean)) return '_' + clean;
    return clean;
  }
}