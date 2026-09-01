// entry/src/main/ets/model/FileNode.ets
export interface FileNode {
  name: string;           // 文件或文件夹名称
  path: string;           // 完整路径
  isDirectory: boolean;   // 是否为文件夹
  children?: FileNode[];  // 子节点（仅文件夹有效）
  isExpanded?: boolean;   // 是否展开（仅文件夹有效）
}