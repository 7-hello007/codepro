// entry/src/main/ets/services/PortMappingService.ets

import { Emulator, PortMapping } from '../model/Emulator';

/**
 * 端口映射服务
 * 负责获取、查询和选择端口映射
 */
export class PortMappingService {
  private static instance: PortMappingService;
  private mappings: PortMapping[] = [];

  // 约定端口配置：文件扩展名 -> 默认虚拟机端口
  private defaultGuestPorts: Record<string, number> = {
    '.html': 8000,
    '.htm': 8000,
    '.js': 3000,
    '.ts': 3000,
    '.jsx': 5173,
    '.tsx': 5173,
    '.vue': 8080,
    '.py': 8000,
  };

  private constructor() {}

  public static getInstance(): PortMappingService {
    if (!PortMappingService.instance) {
      PortMappingService.instance = new PortMappingService();
    }
    return PortMappingService.instance;
  }

  /**
   * 从 AppStorage 加载端口映射配置
   * 三级回退：AppStorage → 模拟器配置 → 默认映射 (8000)
   */
  public loadMappings(): void {
    try {
      // 方案1: 从 AppStorage 读取（QEMU 启动时保存）
      const stored = AppStorage.get<string>('qemuPortMappings');
      if (stored) {
        const parsed = JSON.parse(stored) as PortMapping[];
        if (parsed && parsed.length > 0) {
          const loadedMappings: PortMapping[] = [];
          for (const item of parsed) {
            const mapping: PortMapping = {
              host: item.host,
              guest: item.guest
            };
            loadedMappings.push(mapping);
          }
          this.mappings = loadedMappings;
          console.info('[PortMappingService] 从 AppStorage 加载映射:', this.mappings);
          return;
        }
      }

      // 方案2: 从当前模拟器配置读取
      const emulator = AppStorage.get<Emulator>('currentEmulator');
      if (emulator && emulator.portMapping && emulator.portMapping.length > 0) {
        const loadedMappings: PortMapping[] = [];
        for (const m of emulator.portMapping) {
          const mapping: PortMapping = {
            host: m.host ?? 0,
            guest: m.guest ?? 0
          };
          loadedMappings.push(mapping);
        }
        this.mappings = loadedMappings;
        console.info('[PortMappingService] 从模拟器配置加载映射:', this.mappings);
        return;
      }

      // 方案3: 使用默认端口映射（无需用户配置）
      const defaultMapping: PortMapping = { host: 8000, guest: 8000 };
      this.mappings = [defaultMapping];
      console.info('[PortMappingService] 使用默认端口映射 (8000→8000):', this.mappings);

    } catch (e) {
      const error = e as Error;
      console.error('[PortMappingService] 加载失败:', error.message);
      // 即使加载失败，也使用默认映射
      const defaultMapping: PortMapping = { host: 8000, guest: 8000 };
      this.mappings = [defaultMapping];
      console.info('[PortMappingService] 加载失败，使用默认端口映射 (8000→8000)');
    }
  }

  /**
   * 获取所有映射
   */
  public getMappings(): PortMapping[] {
    return [...this.mappings];
  }

  /**
   * 根据宿主机端口查找映射
   */
  public findByHostPort(hostPort: number): PortMapping | undefined {
    for (const m of this.mappings) {
      if (m.host === hostPort) {
        return m;
      }
    }
    return undefined;
  }

  /**
   * 根据虚拟机端口查找映射
   */
  public findByGuestPort(guestPort: number): PortMapping | undefined {
    for (const m of this.mappings) {
      if (m.guest === guestPort) {
        return m;
      }
    }
    return undefined;
  }

  /**
   * 获取宿主机端口（非空）
   */
  public getHostPort(mapping: PortMapping): number {
    return mapping.host ?? 0;
  }

  /**
   * 获取虚拟机端口（非空）
   */
  public getGuestPort(mapping: PortMapping): number {
    return mapping.guest ?? 0;
  }

  /**
   * 根据文件类型获取最佳匹配的端口映射
   */
  public getBestMatchForFile(filePath: string): PortMapping | null {
    const ext = this.getFileExtension(filePath).toLowerCase();

    // 1. 如果有约定端口，优先匹配
    const defaultGuestPort = this.defaultGuestPorts[ext];
    if (defaultGuestPort !== undefined) {
      const match = this.findByGuestPort(defaultGuestPort);
      if (match) {
        console.info(`[PortMappingService] 约定端口匹配: ${ext} -> ${defaultGuestPort}`);
        return match;
      }
      console.warn(`[PortMappingService] 约定端口 ${defaultGuestPort} 未配置映射`);
    }

    // 2. 如果只有一个映射，直接使用
    if (this.mappings.length === 1) {
      const only = this.mappings[0];
      console.info(`[PortMappingService] 使用唯一映射: ${only.host}->${only.guest}`);
      return only;
    }

    // 3. 如果有多个映射，返回 null（由调用方弹窗让用户选择）
    if (this.mappings.length > 1) {
      console.info('[PortMappingService] 多个映射，需要用户选择');
      return null;
    }

    console.warn('[PortMappingService] 没有可用的端口映射');
    return null;
  }

  /**
   * 获取所有映射的宿主机端口列表（用于选择器）
   */
  public getHostPorts(): number[] {
    const result: number[] = [];
    for (const m of this.mappings) {
      if (m.host !== undefined) {
        result.push(m.host);
      }
    }
    return result;
  }

  /**
   * 获取所有映射的虚拟机端口列表（用于选择器）
   */
  public getGuestPorts(): number[] {
    const result: number[] = [];
    for (const m of this.mappings) {
      if (m.guest !== undefined) {
        result.push(m.guest);
      }
    }
    return result;
  }

  private getFileExtension(path: string): string {
    const lastDot = path.lastIndexOf('.');
    if (lastDot === -1) return '';
    return path.substring(lastDot).toLowerCase();
  }

  /**
   * 更新配置（当用户修改端口映射时调用）
   */
  public updateMappings(newMappings: PortMapping[]): void {
    this.mappings = [...newMappings];
    // 同步到 AppStorage
    AppStorage.setOrCreate('qemuPortMappings', JSON.stringify(newMappings));
    console.info('[PortMappingService] 映射已更新:', this.mappings);
  }
}