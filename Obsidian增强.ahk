#Requires AutoHotkey v2.0
#SingleInstance Force

; Obsidian增强脚本
; 作者：由Cursor AI辅助开发
; 版本：1.0
; 描述：增强Obsidian的使用体验，提供智能窗口管理和托盘功能

; 全局变量
global obsidianPath := "C:\Users\JS\AppData\Local\Programs\Obsidian\Obsidian.exe"
global obsidianProcess := "Obsidian.exe"
global obsidianVisible := false  ; 控制Obsidian是否可见
global obsidianRunning := false  ; 控制Obsidian是否运行

; 初始化
InitTray()
CheckObsidian()
AutoStartObsidian()  ; 添加自动启动功能

; 更新托盘菜单状态
UpdateTrayMenu() {
    global obsidianRunning
    
    ; 根据Obsidian运行状态更新菜单项
    if obsidianRunning {
        A_TrayMenu.Rename("启动Obsidian", "启动Obsidian (已运行)")
        A_TrayMenu.Disable("启动Obsidian (已运行)")
        A_TrayMenu.Enable("关闭Obsidian")
    } else {
        A_TrayMenu.Rename("启动Obsidian (已运行)", "启动Obsidian")
        A_TrayMenu.Enable("启动Obsidian")
        A_TrayMenu.Disable("关闭Obsidian")
    }
}

; 初始化托盘菜单
InitTray() {
    ; 设置托盘图标为Obsidian图标
    if FileExist(obsidianPath)
        TraySetIcon(obsidianPath, 1)
    
    ; 创建托盘菜单项
    A_TrayMenu.Delete() ; 清除默认菜单项
    A_TrayMenu.Add("显示/隐藏仓库 (Win+Z)", ToggleObsidian)
    A_TrayMenu.Add("启动Obsidian", StartObsidian)
    A_TrayMenu.Add("关闭Obsidian", CloseObsidian)
    A_TrayMenu.Add() ; 添加分隔线
    A_TrayMenu.Add("重启脚本", RestartScript)
    A_TrayMenu.Add("关闭脚本", ExitScript)
    A_TrayMenu.Add() ; 添加分隔线
    A_TrayMenu.Add("关于", ShowAbout)
    
    ; 设置默认菜单项
    A_TrayMenu.Default := "显示/隐藏仓库 (Win+Z)"
    
    ; 初始禁用关闭选项
    A_TrayMenu.Disable("关闭Obsidian")
}

; 检查Obsidian是否运行
CheckObsidian() {
    if ProcessExist(obsidianProcess) {
        obsidianRunning := true
        
        ; 检查是否有可见窗口
        windowList := WinGetList("ahk_exe " obsidianProcess)
        hasVisibleWindow := false
        
        for hwnd in windowList {
            if DllCall("IsWindowVisible", "Ptr", hwnd) {
                title := WinGetTitle("ahk_id " hwnd)
                if title != "" && !InStr(title, "仓库") && !InStr(title, "Vault") {
                    hasVisibleWindow := true
                    break
                }
            }
        }
        
        obsidianVisible := hasVisibleWindow
        TrayTip("Obsidian增强脚本", "Obsidian已在运行中", 1)
        
        ; 更新托盘菜单状态
        UpdateTrayMenu()
    }
}

; 切换Obsidian显示状态
ToggleObsidian(*) {
    global obsidianRunning, obsidianVisible
    
    if !obsidianRunning || !ProcessExist(obsidianProcess) {
        StartObsidian()
        return
    }
    
    ; 获取所有Obsidian窗口
    windowList := WinGetList("ahk_exe " obsidianProcess)
    
    ; 如果当前是可见状态，隐藏所有窗口
    if obsidianVisible {
        for hwnd in windowList {
            title := WinGetTitle("ahk_id " hwnd)
            ; 只隐藏主窗口，不隐藏仓库选择窗口
            if title != "" && !InStr(title, "仓库") && !InStr(title, "Vault") {
                WinHide("ahk_id " hwnd)
            }
        }
        obsidianVisible := false
        TrayTip("Obsidian增强脚本", "Obsidian已隐藏", 1)
    } 
    ; 如果当前是隐藏状态，显示所有窗口
    else {
        ; 先检查是否有隐藏的窗口
        DetectHiddenWindows(true)
        hiddenWindowList := WinGetList("ahk_exe " obsidianProcess)
        DetectHiddenWindows(false)
        
        hasShownWindow := false
        
        ; 显示所有隐藏的主窗口
        for hwnd in hiddenWindowList {
            DetectHiddenWindows(true)
            title := WinGetTitle("ahk_id " hwnd)
            isVisible := DllCall("IsWindowVisible", "Ptr", hwnd)
            DetectHiddenWindows(false)
            
            ; 只显示主窗口，不显示仓库选择窗口
            if title != "" && !InStr(title, "仓库") && !InStr(title, "Vault") && !isVisible {
                WinShow("ahk_id " hwnd)
                WinActivate("ahk_id " hwnd)
                hasShownWindow := true
            }
        }
        
        ; 如果没有找到隐藏的窗口，可能需要重新启动
        if !hasShownWindow {
            TrayTip("Obsidian增强脚本", "未找到隐藏的Obsidian窗口，尝试重新启动", 3)
            RestartObsidian()
            return
        }
        
        obsidianVisible := true
        TrayTip("Obsidian增强脚本", "Obsidian已显示", 1)
    }
}

; 启动Obsidian
StartObsidian(*) {
    global obsidianRunning, obsidianVisible
    
    if obsidianRunning && ProcessExist(obsidianProcess) {
        TrayTip("Obsidian增强脚本", "Obsidian已在运行中", 3)
        
        ; 尝试显示窗口
        ToggleObsidian()
        return
    }
    
    ; 启动Obsidian
    Run(obsidianPath)
    TrayTip("Obsidian增强脚本", "正在启动Obsidian...", 1)
    
    ; 等待Obsidian启动
    try {
        WinWait("ahk_exe " obsidianProcess, , 5)
        Sleep(2000) ; 给Obsidian一些时间加载
        
        obsidianRunning := true
        obsidianVisible := true  ; 首次启动时设置为可见
        
        ; 首次启动不隐藏窗口，保持所有窗口可见
        TrayTip("Obsidian增强脚本", "Obsidian已启动", 1)
        
        ; 更新托盘菜单状态
        UpdateTrayMenu()
    } catch {
        TrayTip("Obsidian增强脚本", "启动Obsidian超时", 3)
    }
}

; 重启Obsidian
RestartObsidian() {
    global obsidianRunning, obsidianVisible
    
    if ProcessExist(obsidianProcess) {
        ProcessClose(obsidianProcess)
        obsidianRunning := false
        obsidianVisible := false
        Sleep(1000)
        
        ; 更新托盘菜单状态
        UpdateTrayMenu()
    }
    
    StartObsidian()
}

; 关闭Obsidian
CloseObsidian(*) {
    global obsidianRunning, obsidianVisible
    
    if !obsidianRunning || !ProcessExist(obsidianProcess) {
        TrayTip("Obsidian增强脚本", "Obsidian未运行", 3)
        return
    }
    
    result := MsgBox("确定要关闭Obsidian吗？", "确认", "YesNo")
    if result = "Yes" {
        ProcessClose(obsidianProcess)
        obsidianRunning := false
        obsidianVisible := false
        TrayTip("Obsidian增强脚本", "Obsidian已关闭", 1)
        
        ; 更新托盘菜单状态
        UpdateTrayMenu()
    }
}

; 重启脚本
RestartScript(*) {
    Reload()
}

; 退出脚本
ExitScript(*) {
    result := MsgBox("是否同时关闭Obsidian？", "确认退出", "YesNoCancel")
    
    if result = "Cancel" {
        return
    } else if result = "Yes" {
        if ProcessExist(obsidianProcess)
            ProcessClose(obsidianProcess)
    }
    
    ExitApp()
}

; 显示关于信息
ShowAbout(*) {
    MsgBox("Obsidian增强脚本 v1.0`n`n由Cursor AI辅助开发`n`n增强Obsidian的使用体验，提供智能窗口管理和托盘功能", "关于", "OK")
}

; 自动启动Obsidian
AutoStartObsidian() {
    global obsidianRunning
    
    ; 如果Obsidian未运行，则自动启动并隐藏
    if !obsidianRunning {
        ; 启动Obsidian
        Run(obsidianPath)
        TrayTip("Obsidian增强脚本", "正在自动启动Obsidian...", 1)
        
        ; 等待Obsidian启动
        try {
            WinWait("ahk_exe " obsidianProcess, , 5)
            Sleep(2000) ; 给Obsidian一些时间加载
            
            obsidianRunning := true
            
            ; 隐藏所有主窗口
            windowList := WinGetList("ahk_exe " obsidianProcess)
            for hwnd in windowList {
                title := WinGetTitle("ahk_id " hwnd)
                ; 只隐藏主窗口，不隐藏仓库选择窗口
                if title != "" && !InStr(title, "仓库") && !InStr(title, "Vault") {
                    WinHide("ahk_id " hwnd)
                }
            }
            
            obsidianVisible := false
            TrayTip("Obsidian增强脚本", "Obsidian已自动启动并隐藏", 1)
            
            ; 更新托盘菜单状态
            UpdateTrayMenu()
        } catch {
            TrayTip("Obsidian增强脚本", "自动启动Obsidian超时", 3)
        }
    }
}

; 热键：Win+Z 切换Obsidian可见性
#z::ToggleObsidian() 