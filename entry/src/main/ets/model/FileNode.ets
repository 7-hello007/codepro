// entry/src/main/ets/model/FileNode.ets

export interface FileNode {
  name: string;
  path: string;
  isDir: boolean;
  isExpanded: boolean;
  children?: FileNode[];
}