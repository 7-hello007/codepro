// entry/src/main/ets/services/TabManager.ets
import { EditorTab } from '../components/EditorTabs';

/**
 * 标签管理器
 */
export class TabManager {
  private openedTabs: EditorTab[] = [];
  private activePath: string = '';

  onTabsChanged?: (tabs: EditorTab[]) => void;
  onActiveTabChanged?: (path: string) => void;

  openFile(path: string): void {
    if (!path) return;
    if (this.activePath === path) return;

    for (const tab of this.openedTabs) {
      if (tab.path === path) {
        this.switchTab(path);
        return;
      }
    }

    const name = path.split('/').pop() || path;
    const newTabs: EditorTab[] = [];
    for (const tab of this.openedTabs) {
      const newTab: EditorTab = {
        path: tab.path,
        name: tab.name,
        isActive: false
      };
      newTabs.push(newTab);
    }
    const newTab: EditorTab = { path, name, isActive: true };
    newTabs.push(newTab);
    this.openedTabs = newTabs;
    this.activePath = path;
    this.notifyChanged();
  }

  switchTab(path: string): void {
    if (this.activePath === path) return;
    const newTabs: EditorTab[] = [];
    for (const tab of this.openedTabs) {
      const newTab: EditorTab = {
        path: tab.path,
        name: tab.name,
        isActive: tab.path === path
      };
      newTabs.push(newTab);
    }
    this.openedTabs = newTabs;
    this.activePath = path;
    this.notifyChanged();
  }

  closeTab(path: string): string | undefined {
    let index = -1;
    for (let i = 0; i < this.openedTabs.length; i++) {
      if (this.openedTabs[i].path === path) { index = i; break; }
    }
    if (index === -1) return undefined;

    const wasActive = this.openedTabs[index].isActive;
    const newTabs = this.openedTabs.filter((_, i) => i !== index);
    this.openedTabs = newTabs;

    if (newTabs.length === 0) {
      this.activePath = '';
      this.notifyChanged();
      return undefined;
    }

    if (!wasActive) {
      this.notifyChanged();
      return this.activePath;
    }

    let newIndex = index;
    if (newIndex >= newTabs.length) newIndex = newTabs.length - 1;
    const activeTab = newTabs[newIndex];
    const updatedTabs: EditorTab[] = [];
    for (let i = 0; i < newTabs.length; i++) {
      const updatedTab: EditorTab = {
        path: newTabs[i].path,
        name: newTabs[i].name,
        isActive: i === newIndex
      };
      updatedTabs.push(updatedTab);
    }
    this.openedTabs = updatedTabs;
    this.activePath = activeTab.path;
    this.notifyChanged();
    return this.activePath;
  }

  getTabs(): EditorTab[] {
    return this.openedTabs;
  }

  getActivePath(): string {
    return this.activePath;
  }

  private notifyChanged(): void {
    if (this.onTabsChanged) {
      this.onTabsChanged(this.openedTabs);
    }
    if (this.onActiveTabChanged) {
      this.onActiveTabChanged(this.activePath);
    }
  }
}