// entry/src/main/ets/services/EditorController.ets
import { webview } from '@kit.ArkWeb';

interface ArkTSService {
  onEditorReady: () => void;
  onContentChange: (content: string) => void;
  onCursorChange: (line: string, col: string) => void;
  onEditorBlur: (content: string) => void;
  log: (msg: string) => void;
}

export class EditorController {
  private webController: webview.WebviewController;
  private isEditorReady: boolean = false;
  private pendingContent: string = '';
  private pendingLanguage: string = 'plaintext';
  private hasPendingContent: boolean = false;
  private hasPendingLanguage: boolean = false;

  public currentContent: string = '';

  public onCursorChanged?: (line: number, col: number) => void;
  public onContentChanged?: (content: string) => void;
  public onEditorBlurred?: (content: string) => void;

  constructor(controller: webview.WebviewController) {
    this.webController = controller;
  }

  // 对外提供 ArkTSService 对象（用于 javaScriptProxy）
  getArkTSService(): ArkTSService {
    return {
      onEditorReady: (): void => {
        console.info('✅ Monaco Editor Ready');
        this.isEditorReady = true;
        if (this.hasPendingContent || this.hasPendingLanguage) {
          const content = this.hasPendingContent ? this.pendingContent : '';
          const language = this.hasPendingLanguage ? this.pendingLanguage : 'plaintext';
          this.hasPendingContent = false;
          this.hasPendingLanguage = false;
          this.pendingContent = '';
          this.pendingLanguage = 'plaintext';
          this.applyContent(content, language);
        }
        this.triggerLayout();
      },
      onContentChange: (content: string): void => {
        this.currentContent = content;
        if (this.onContentChanged) {
          this.onContentChanged(content);
        }
      },
      onCursorChange: (line: string, col: string): void => {
        const l = parseInt(line, 10) || 1;
        const c = parseInt(col, 10) || 1;
        if (this.onCursorChanged) {
          this.onCursorChanged(l, c);
        }
      },
      onEditorBlur: (content: string): void => {
        this.currentContent = content;
        if (this.onEditorBlurred) {
          this.onEditorBlurred(content);
        }
      },
      log: (msg: string): void => {
        console.info('📢 [Monaco]:', msg);
      }
    };
  }

  /**
   * 设置编辑器内容（自动处理未就绪缓存）
   */
  setContent(content: string, language: string = 'plaintext'): void {
    if (!this.isEditorReady) {
      this.pendingContent = content;
      this.pendingLanguage = language;
      this.hasPendingContent = true;
      this.hasPendingLanguage = true;
      console.info('⏳ Monaco 未 Ready，暂存内容');
      return;
    }
    this.applyContent(content, language);
  }

  /**
   * 显示空状态（覆盖层 + 只读）
   * @param message 显示的文字
   */
  showEmptyState(message: string = '未打开任何文件'): void {
    const js = `
      if (typeof window.showEmptyState === 'function') {
        window.showEmptyState(${JSON.stringify(message)});
      } else {
        console.warn('showEmptyState not available');
      }
    `;
    this.webController.runJavaScript(js);
    // 同时将当前内容置空，防止残留
    this.currentContent = '';
  }

  /**
   * 设置编辑器只读状态
   */
  setReadOnly(readonly: boolean): void {
    const js = `
      if (typeof window.setReadOnly === 'function') {
        window.setReadOnly(${readonly});
      }
    `;
    this.webController.runJavaScript(js);
  }

  /**
   * 触发布局更新
   */
  triggerLayout(): void {
    this.webController.runJavaScript(`
      if (typeof window.triggerLayout === 'function') {
        window.triggerLayout();
      }
    `);
  }

  /**
   * 获取当前编辑器内容（从缓存）
   */
  getCurrentContent(): string {
    return this.currentContent;
  }

  /**
   * 实际写入内容（内部方法）
   */
  private applyContent(content: string, language: string): void {
    const safeContent = JSON.stringify(content);
    const safeLanguage = JSON.stringify(language || 'plaintext');
    const hasContent = content && content.length > 0;
    const jsCode = `
      (function() {
        try {
          // 先设置语言（确保模型存在）
          if (typeof window.setEditorLanguage === 'function') {
            window.setEditorLanguage(${safeLanguage});
          }
          // 设置内容
          if (typeof window.forceSetContent === 'function') {
            window.forceSetContent(${safeContent}, ${safeLanguage});
          } else if (typeof window.setEditorContent === 'function') {
            window.setEditorContent(${safeContent}, ${safeLanguage});
          } else {
            console.error('没有可用的设置内容方法');
            return false;
          }
          // 根据内容是否非空设置只读
          if (typeof window.setReadOnly === 'function') {
            window.setReadOnly(${!hasContent});
          }
          // 再次确保语言（有时第一次可能未生效）
          if (typeof window.setEditorLanguage === 'function') {
            window.setEditorLanguage(${safeLanguage});
          }
          return true;
        } catch (e) {
          console.error('写入 Monaco 失败:', e);
          return false;
        }
      })();
    `;
    this.webController.runJavaScript(jsCode);
  }

  /**
   * 根据文件路径获取 Monaco 语言标识
   */
  static getLanguageFromPath(path: string): string {
    const ext = path.split('.').pop()?.toLowerCase() || '';
    const map: Record<string, string> = {
      'ets': 'typescript',
      'ts': 'typescript',
      'js': 'javascript',
      'json': 'json',
      'html': 'html',
      'css': 'css',
      'xml': 'xml',
      'py': 'python',
      'java': 'java',
      'c': 'c',
      'cpp': 'cpp',
      'go': 'go',
      'md': 'markdown'
    };
    return map[ext] || 'plaintext';
  }
}