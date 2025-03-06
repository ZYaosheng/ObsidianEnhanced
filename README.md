# Obsidian增强脚本

## 简介
这是一个使用AutoHotkey v2编写的Obsidian增强脚本，旨在提升Obsidian的使用体验。脚本提供智能窗口管理、托盘功能和快捷键支持。

## 功能特点
- **智能窗口管理**：自动区分仓库管理窗口和主窗口
- **静默启动**：启动Obsidian时不显示界面
- **托盘菜单**：提供丰富的托盘菜单功能
- **热键支持**：使用Win+Z快速切换Obsidian窗口可见性
- **关闭按钮重定向**：点击关闭按钮时最小化到托盘而非退出程序

## 托盘菜单功能
- 显示/隐藏仓库 (Win+Z)
- 启动/关闭Obsidian
- 重启脚本
- 关闭脚本（询问确认）
- 关于（作者信息）

## 使用方法
1. 确保已安装AutoHotkey v2
2. 双击运行`Obsidian增强.ahk`脚本
3. 使用Win+Z快捷键或托盘菜单控制Obsidian
4. 点击窗口关闭按钮会将Obsidian最小化到托盘而非关闭

## 注意事项
- 脚本默认Obsidian安装路径为：`C:\Users\用户名\AppData\Local\Programs\Obsidian\Obsidian.exe`
- 如需修改路径，请编辑脚本中的`obsidianPath`变量
- 关闭脚本时会询问是否同时关闭Obsidian

## 开发信息
- 由Cursor AI辅助开发
- 基于AutoHotkey v2.0
- 版本：1.0

## 许可证
MIT 