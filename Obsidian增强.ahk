#Requires AutoHotkey v2.0
#SingleInstance Force
; 作者: ZYaosheng
; Obsidian增强脚本 v1.2
; GitHub: https://github.com/ZYaosheng/ObsidianEnhanced

global Config := {
    ObsidianPath: "C:\Program Files\Obsidian\Obsidian.exe",
    ObsidianProcess: "Obsidian.exe"
}

global State := {
    IsVisible: false,
    IsRunning: false,
    ProcessCheckTimer: 0,
    CurrentWindow: 0
}

global SystemMetrics := {
    CXSIZEFRAME: DllCall("GetSystemMetrics", "Int", 32),
    CYSIZEFRAME: DllCall("GetSystemMetrics", "Int", 33),
    CXSIZE: DllCall("GetSystemMetrics", "Int", 30),
    CYSIZE: DllCall("GetSystemMetrics", "Int", 31)
}

LoadConfig()
InitTray()
CheckObsidian()
AutoStartObsidian()

SetTimer(MonitorObsidianProcess, 1000)
SetTimer(CheckMousePosition, 100)

LoadConfig() {
    if FileExist("config.local.ini") {
        try {
            iniPath := IniRead("config.local.ini", "Paths", "ObsidianPath", Config.ObsidianPath)
            if (iniPath && iniPath != "ERROR") {
                Config.ObsidianPath := iniPath
                LogMessage("已从配置文件加载Obsidian路径: " . Config.ObsidianPath)
            }
        } catch as err {
            LogMessage("加载配置文件失败: " . err.Message)
        }
    } else {
        LogMessage("未找到配置文件，使用默认设置")
    }
}

; ===== 托盘菜单管理 =====
; 更新托盘菜单状态
UpdateTrayMenu() {
    ; 根据Obsidian运行状态更新菜单项
    if State.IsRunning {
        try {
            A_TrayMenu.Rename("启动Obsidian", "启动Obsidian (已运行)")
        }
        try {
            A_TrayMenu.Disable("启动Obsidian (已运行)")
            A_TrayMenu.Enable("关闭Obsidian")
        }
    } else {
        try {
            A_TrayMenu.Rename("启动Obsidian (已运行)", "启动Obsidian")
        }
        try {
            A_TrayMenu.Enable("启动Obsidian")
            A_TrayMenu.Disable("关闭Obsidian")
        }
    }
}

; 初始化托盘菜单
InitTray() {
    ; 设置托盘图标为Obsidian图标
    if FileExist(Config.ObsidianPath)
        TraySetIcon(Config.ObsidianPath, 1)
    
    ; 创建托盘菜单项
    A_TrayMenu.Delete() ; 清除默认菜单项
    A_TrayMenu.Add("显示/隐藏仓库 (Win+Z)", ToggleObsidian)
    A_TrayMenu.Add("启动Obsidian", StartObsidian)  ; 初始菜单项名称
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

; ===== 窗口管理函数 =====
; 获取Obsidian窗口列表
GetObsidianWindows(includeHidden := false) {
    DetectHiddenWindows(includeHidden)
    windowList := WinGetList("ahk_exe " Config.ObsidianProcess)
    DetectHiddenWindows(false)
    return windowList
}

; 判断窗口是否为主窗口（非仓库选择窗口）
IsMainWindow(hwnd) {
    DetectHiddenWindows(true)
    title := WinGetTitle("ahk_id " hwnd)
    DetectHiddenWindows(false)
    return (title != "" && title != "Obsidian")
}

; 获取窗口可见性状态
IsWindowVisible(hwnd) {
    DetectHiddenWindows(true)
    isVisible := DllCall("IsWindowVisible", "Ptr", hwnd)
    DetectHiddenWindows(false)
    return isVisible
}

; 检查窗口是否存在
WindowExists(hwnd) {
    DetectHiddenWindows(true)
    exists := WinExist("ahk_id " hwnd)
    DetectHiddenWindows(false)
    return exists
}

; 操作所有主窗口
ManageMainWindows(action) {
    windowList := GetObsidianWindows(true)
    hasProcessedWindow := false
    
    for hwnd in windowList {
        if IsMainWindow(hwnd) && WindowExists(hwnd) {
            try {
                if (action = "hide") {
                    WinHide("ahk_id " hwnd)
                    hasProcessedWindow := true
                } else if (action = "show") {
                    WinShow("ahk_id " hwnd)
                    WinActivate("ahk_id " hwnd)
                    hasProcessedWindow := true
                }
            } catch as err {
                LogMessage("窗口操作失败: " err.Message)
            }
        }
    }
    
    return hasProcessedWindow
}

; ===== Obsidian状态管理 =====
; 检查Obsidian是否运行
CheckObsidian() {
    if ProcessExist(Config.ObsidianProcess) {
        State.IsRunning := true
        
        ; 检查是否有可见窗口
        windowList := GetObsidianWindows()
        hasVisibleWindow := false
        
        for hwnd in windowList {
            if IsWindowVisible(hwnd) && IsMainWindow(hwnd) {
                hasVisibleWindow := true
                break
            }
        }
        
        State.IsVisible := hasVisibleWindow
        TrayTip("Obsidian增强脚本", "Obsidian已在运行中", 1)
        
        ; 更新托盘菜单状态
        UpdateTrayMenu()
    }
}

; 切换Obsidian显示状态
ToggleObsidian(*) {
    if !State.IsRunning || !ProcessExist(Config.ObsidianProcess) {
        StartObsidian()
        return
    }
    
    if State.IsVisible {
        ; 隐藏所有主窗口
        ManageMainWindows("hide")
        State.IsVisible := false
    } else {
        ; 显示所有隐藏的主窗口
        hasShownWindow := ManageMainWindows("show")
        
        ; 如果没有找到隐藏的窗口，可能需要重新启动
        if !hasShownWindow {
            TrayTip("Obsidian增强脚本", "未找到隐藏的Obsidian窗口，尝试重新启动", 3)
            RestartObsidian()
            return
        }
        
        State.IsVisible := true
    }
}

; 启动Obsidian
StartObsidian(*) {
    if State.IsRunning && ProcessExist(Config.ObsidianProcess) {
        TrayTip("Obsidian增强脚本", "Obsidian已在运行中", 3)
        
        ; 尝试显示窗口
        ToggleObsidian()
        return
    }
    
    ; 启动Obsidian
    try {
        Run(Config.ObsidianPath)
    } catch {
        TrayTip("Obsidian增强脚本", "启动Obsidian失败", 3)
        return
    }
    
    ; 等待进程出现
    try {
        ProcessWait(Config.ObsidianProcess, 3)
    } catch {
        return  ; 如果等待超时，直接返回，让进程监控器处理后续工作
    }
    
    ; 立即设置状态
    State.IsRunning := true
    State.IsVisible := true
    
    ; 更新托盘菜单状态
    UpdateTrayMenu()
}

; 重启Obsidian
RestartObsidian() {
    if ProcessExist(Config.ObsidianProcess) {
        ProcessClose(Config.ObsidianProcess)
        State.IsRunning := false
        State.IsVisible := false
        Sleep(1000)
        
        ; 更新托盘菜单状态
        UpdateTrayMenu()
    }
    
    StartObsidian()
}

; 关闭Obsidian
CloseObsidian(*) {
    if !State.IsRunning || !ProcessExist(Config.ObsidianProcess) {
        TrayTip("Obsidian增强脚本", "Obsidian未运行", 3)
        return
    }
    
    result := MsgBox("确定要关闭Obsidian吗？", "确认", "YesNo")
    if result = "Yes" {
        ProcessClose(Config.ObsidianProcess)
        State.IsRunning := false
        State.IsVisible := false
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
        if ProcessExist(Config.ObsidianProcess) {
            ProcessClose(Config.ObsidianProcess)
        }
    } else {
        ; 如果选择No，显示所有隐藏的Obsidian窗口
        if ProcessExist(Config.ObsidianProcess) {
            ManageMainWindows("show")
        }
    }
    
    ExitApp()
}

; 显示关于信息
ShowAbout(*) {
    MsgBox("Obsidian增强脚本 v1.2`n`n作者：ZYaosheng`nGitHub: https://github.com/ZYaosheng/ObsidianEnhanced`n`n增强Obsidian的使用体验，提供智能窗口管理和托盘功能", "关于", "OK")
}

; 自动启动Obsidian
AutoStartObsidian() {
    ; 检查Obsidian是否已经在运行
    if ProcessExist(Config.ObsidianProcess) {
        State.IsRunning := true
        
        ; 无论是否已运行，都确保隐藏所有主窗口
        ManageMainWindows("hide")
        State.IsVisible := false
        UpdateTrayMenu()
    } else {
        ; Obsidian未运行，启动它
        try {
            Run(Config.ObsidianPath)
            WinWait("ahk_exe " Config.ObsidianProcess, , 5)
            Sleep(2000) ; 给Obsidian一些时间加载
            
            State.IsRunning := true
            
            ; 尝试隐藏窗口，最多尝试5次
            Loop 5 {
                if ManageMainWindows("hide") {
                    break
                }
                Sleep(500)
            }
            
            State.IsVisible := false
            UpdateTrayMenu()
        } catch {
            TrayTip("Obsidian增强脚本", "启动Obsidian超时", 3)
        }
    }
}

; ===== 鼠标位置监控 =====
; 检查鼠标位置并处理关闭按钮点击
CheckMousePosition() {
    static inCloseButton := false
    
    if !State.IsRunning || !ProcessExist(Config.ObsidianProcess) {
        return
    }
    
    ClearCloseButtonState() {
        if (inCloseButton) {
            ToolTip()
            try Hotkey("LButton", "Off")
            try Hotkey("RButton", "Off")
            inCloseButton := false
        }
    }
    
    CoordMode("Mouse", "Screen")
    
    try {
        MouseGetPos(&mx, &my, &_WinId)
    } catch {
        ClearCloseButtonState()
        return
    }
    
    if !_WinId {
        ClearCloseButtonState()
        return
    }
    
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " _WinId)
        program := WinGetProcessName("ahk_id " _WinId)
    } catch {
        ClearCloseButtonState()
        return
    }
    
    if (!w || !h || program != Config.ObsidianProcess) {
        ClearCloseButtonState()
        return
    }
    
    closeButtonArea := {
        left: x + w - SystemMetrics.CXSIZEFRAME - SystemMetrics.CXSIZE - 10,
        top: y - SystemMetrics.CYSIZEFRAME,
        right: x + w - SystemMetrics.CXSIZEFRAME,
        bottom: y + SystemMetrics.CYSIZE + SystemMetrics.CYSIZEFRAME
    }
    
    isInCloseButton := (mx >= closeButtonArea.left && mx <= closeButtonArea.right && 
                        my >= closeButtonArea.top && my <= closeButtonArea.bottom)
    
    if (isInCloseButton && !inCloseButton) {
        ToolTip("左键：最小化到托盘`n右键：关闭窗口")
        State.CurrentWindow := _WinId
        try Hotkey("LButton", HideObsidianWindow, "On")
        try Hotkey("RButton", CloseObsidianWindow, "On")
        inCloseButton := true
        LogMessage("鼠标进入关闭按钮区域")
    } 
    else if (!isInCloseButton && inCloseButton) {
        ClearCloseButtonState()
        LogMessage("鼠标离开关闭按钮区域")
    }
}

; 隐藏Obsidian窗口（点击关闭按钮时）
HideObsidianWindow(*) {
    HandleWindowAction("hide")
}

; 关闭Obsidian窗口（右键点击关闭按钮时）
CloseObsidianWindow(*) {
    HandleWindowAction("close")
}

; 处理窗口操作
HandleWindowAction(action) {
    if !WindowExists(State.CurrentWindow) {
        ToolTip()
        LogMessage("尝试" (action = "hide" ? "隐藏" : "关闭") "不存在的窗口")
        return
    }
    
    try {
        if (action = "hide") {
            WinHide("ahk_id " State.CurrentWindow)
            State.IsVisible := false
            LogMessage("隐藏Obsidian窗口")
        } else {
            WinClose("ahk_id " State.CurrentWindow)
            LogMessage("关闭Obsidian窗口")
            
            windowList := GetObsidianWindows()
            if windowList.Length = 0 {
                State.IsRunning := false
                State.IsVisible := false
                UpdateTrayMenu()
            }
        }
        
        ToolTip()
    } catch as err {
        ToolTip()
        LogMessage((action = "hide" ? "隐藏" : "关闭") "窗口失败: " err.Message)
    }
}

; ===== 进程监控 =====
; 添加进程监控函数
MonitorObsidianProcess() {
    isRunning := ProcessExist(Config.ObsidianProcess)
    
    if (isRunning && !State.IsRunning) {
        State.IsRunning := true
        UpdateTrayMenu()
    } 
    else if (!isRunning && State.IsRunning) {
        State.IsRunning := false
        State.IsVisible := false
        UpdateTrayMenu()
    }
}

; ===== 热键 =====
; 热键：Win+Z 切换Obsidian可见性
#z::ToggleObsidian()

; ===== 工具函数 =====
; 日志记录函数
LogMessage(message) {
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    logFile := "obsidian_enhance.log"
    FileAppend(timestamp . " - " . message . "`n", logFile, "UTF-8")
} 