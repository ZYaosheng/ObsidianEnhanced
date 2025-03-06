# Obsidian增强脚本

## 简介
这是一个使用AutoHotkey v2编写的Obsidian增强脚本，旨在提升Obsidian的使用体验。脚本提供智能窗口管理、托盘功能和快捷键支持。

## 功能特点
- **智能窗口管理**：自动区分仓库管理窗口和主窗口
- **静默启动**：启动Obsidian时不显示界面
- **托盘菜单**：提供丰富的托盘菜单功能
- **热键支持**：使用Win+Z快速切换Obsidian窗口可见性
- **关闭按钮增强**：
  - 左键点击关闭按钮：最小化到托盘而非退出程序
  - 右键点击关闭按钮：真正关闭窗口（无需确认）

## 托盘菜单功能
- 显示/隐藏仓库 (Win+Z)
- 启动/关闭Obsidian
- 重启脚本
- 关闭脚本（询问确认）
- 关于（作者信息）

## 使用方法
1. 确保已安装AutoHotkey v2
2. 复制`config.template.ini`为`config.local.ini`并根据您的环境修改配置
3. 双击运行`Obsidian增强.ahk`脚本
4. 使用Win+Z快捷键或托盘菜单控制Obsidian
5. 关闭按钮操作：
   - 左键点击：将Obsidian最小化到托盘
   - 右键点击：直接关闭Obsidian窗口（无需确认）

## 配置文件
脚本使用INI格式的配置文件来存储个人设置，避免敏感信息被提交到版本控制系统：

1. 项目包含一个`config.template.ini`模板文件
2. 首次使用时，请复制该文件为`config.local.ini`
3. 在`config.local.ini`中修改Obsidian路径等个人设置
4. `config.local.ini`已被添加到`.gitignore`中，不会被提交到Git仓库

### 配置文件示例
```ini
[Paths]
; Obsidian安装路径
ObsidianPath=C:\Users\YourUsername\AppData\Local\Programs\Obsidian\Obsidian.exe

[Settings]
; 其他设置可以在此添加
; OtherSetting=value
```

## 注意事项
- 如果没有找到`config.local.ini`文件，脚本将使用默认设置
- 默认Obsidian安装路径为：`C:\Program Files\Obsidian\Obsidian.exe`
- 关闭脚本时会询问是否同时关闭Obsidian
- 右键点击关闭按钮会直接关闭窗口，不会有确认提示

## 开发信息
- 由Cursor AI辅助开发
- 基于AutoHotkey v2.0
- 版本：1.0

## 许可证
MIT 