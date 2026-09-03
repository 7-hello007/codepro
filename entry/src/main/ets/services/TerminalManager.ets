// entry/src/main/ets/services/TerminalManager.ets

export interface TerminalSession {
  id: string;
  name: string;
  createdAt: number;
}

export class TerminalManager {
  private static instance: TerminalManager;
  private sessions: TerminalSession[] = [];
  private activeId: string = '';
  private sessionCounter: number = 0;

  public onSessionsChanged?: (sessions: TerminalSession[]) => void;
  public onActiveChanged?: (sessionId: string) => void;

  private constructor() {}

  public static getInstance(): TerminalManager {
    if (!TerminalManager.instance) {
      TerminalManager.instance = new TerminalManager();
    }
    return TerminalManager.instance;
  }

  /**
   * 根据计数器生成终端名称
   */
  private generateTerminalName(): string {
    // 前五个特殊名称
    const specialNames: string[] = ['o', 't', 'th', 'f', 'fi'];

    if (this.sessionCounter <= 5) {
      return specialNames[this.sessionCounter - 1];
    } else {
      // 从第6个开始：01, 02, 03, ...
      const num = this.sessionCounter - 5;
      return num.toString().padStart(2, '0');
    }
  }

  public createTerminal(): TerminalSession {
    this.sessionCounter++;
    const id: string = 'terminal-' + this.sessionCounter;
    const name: string = this.generateTerminalName();

    const session: TerminalSession = {
      id: id,
      name: name,
      createdAt: Date.now()
    };

    this.sessions = [...this.sessions, session];
    this.activeId = id;

    this.notifySessionsChanged();
    this.notifyActiveChanged();

    return session;
  }

  public switchTerminal(id: string): void {
    if (this.activeId === id) return;
    const exists = this.sessions.some(s => s.id === id);
    if (!exists) return;

    this.activeId = id;
    this.notifyActiveChanged();
  }

  public closeTerminal(id: string): void {
    if (this.sessions.length <= 1) return;

    const index = this.sessions.findIndex(s => s.id === id);
    if (index === -1) return;

    this.sessions.splice(index, 1);
    this.sessions = [...this.sessions];

    if (this.activeId === id) {
      const newIndex = Math.min(index, this.sessions.length - 1);
      this.activeId = this.sessions[newIndex].id;
      this.notifyActiveChanged();
    }

    this.notifySessionsChanged();
  }

  public getSessions(): TerminalSession[] {
    return [...this.sessions];
  }

  public getActiveId(): string {
    return this.activeId;
  }

  public initDefault(): void {
    if (this.sessions.length === 0) {
      this.createTerminal();
    }
  }

  private notifySessionsChanged(): void {
    if (this.onSessionsChanged) {
      this.onSessionsChanged(this.getSessions());
    }
  }

  private notifyActiveChanged(): void {
    if (this.onActiveChanged) {
      this.onActiveChanged(this.activeId);
    }
  }
}