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

  triggerLayout(): void {
    this.webController.runJavaScript(`
      if (typeof window.triggerLayout === 'function') {
        window.triggerLayout();
      }
    `);
  }

  getCurrentContent(): string {
    return this.currentContent;
  }

  private applyContent(content: string, language: string): void {
    const safeContent = JSON.stringify(content);
    const safeLanguage = JSON.stringify(language);
    const jsCode = `
      (function() {
        try {
          if (typeof window.forceSetContent === 'function') {
            window.forceSetContent(${safeContent}, ${safeLanguage});
            return true;
          } else if (typeof window.setEditorContent === 'function') {
            window.setEditorContent(${safeContent}, ${safeLanguage});
            return true;
          } else {
            console.error('没有可用的设置内容方法');
            return false;
          }
        } catch (e) {
          console.error('写入 Monaco 失败:', e);
          return false;
        }
      })();
    `;
    console.info('📤 → Monaco:', 'language=' + language, 'length=' + content.length);
    this.webController.runJavaScript(jsCode, (err: Error | null) => {
      if (err) console.error('❌ Monaco JS 执行失败:', err.message);
      else console.info('✅ Monaco 内容写入成功');
    });
  }

  static getLanguageFromPath(path: string): string {
    const ext = path.split('.').pop()?.toLowerCase() || '';
    const map: Record<string, string> = {
      'ets': 'typescript', 'ts': 'typescript', 'js': 'javascript',
      'json': 'json', 'html': 'html', 'css': 'css',
      'xml': 'xml', 'py': 'python', 'java': 'java',
      'c': 'c', 'cpp': 'cpp', 'go': 'go', 'md': 'markdown'
    };
    return map[ext] || 'plaintext';
  }
}