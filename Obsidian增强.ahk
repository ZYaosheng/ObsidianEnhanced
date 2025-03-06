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
global overlayGui := Map()  ; 将overlayGui设为全局变量
global processCheckTimer := 0  ; 用于存储进程检查定时器ID

; 初始化
InitTray()
CheckObsidian()
AutoStartObsidian()  ; 添加自动启动功能

; 启动进程监控
SetTimer(MonitorObsidianProcess, 1000)  ; 每秒检查一次进程状态

; 更新托盘菜单状态
UpdateTrayMenu() {
    global obsidianRunning
    
    ; 根据Obsidian运行状态更新菜单项
    if obsidianRunning {
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
    if FileExist(obsidianPath)
        TraySetIcon(obsidianPath, 1)
    
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
                if title != "" && title != "Obsidian" {
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
    global obsidianRunning, obsidianVisible, overlayGui
    
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
            if title != "" && title != "Obsidian" {
                WinHide("ahk_id " hwnd)
                ; 同时隐藏对应的覆盖窗口
                if overlayGui.Has(hwnd) {
                    overlayGui[hwnd].Hide()
                }
            }
        }
        obsidianVisible := false
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
            if title != "" && title != "Obsidian" && !isVisible {
                WinShow("ahk_id " hwnd)
                WinActivate("ahk_id " hwnd)
                hasShownWindow := true
                
                ; 确保覆盖窗口也显示出来
                if overlayGui.Has(hwnd) {
                    ; 更新覆盖窗口位置
                    WinGetPos(&x, &y, &width, &height, "ahk_id " hwnd)
                    buttonSize := 42
                    closeButtonX := x + width - buttonSize - 10
                    closeButtonY := y + 0
                    overlayGui[hwnd].Show("x" closeButtonX " y" closeButtonY " w" buttonSize " h" buttonSize " NoActivate")
                }
            }
        }
        
        ; 如果没有找到隐藏的窗口，可能需要重新启动
        if !hasShownWindow {
            TrayTip("Obsidian增强脚本", "未找到隐藏的Obsidian窗口，尝试重新启动", 3)
            RestartObsidian()
            return
        }
        
        obsidianVisible := true
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
    try {
        Run(obsidianPath)
    } catch {
        TrayTip("Obsidian增强脚本", "启动Obsidian失败", 3)
        return
    }
    
    ; 等待进程出现
    try {
        ProcessWait(obsidianProcess, 3)
    } catch {
        return  ; 如果等待超时，直接返回，让进程监控器处理后续工作
    }
    
    ; 立即设置状态
    obsidianRunning := true
    obsidianVisible := true
    
    ; 更新托盘菜单状态
    UpdateTrayMenu()
    
    ; 延迟初始化覆盖按钮
    SetTimer(InitCloseButtonOverride, -1000)
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

; 清理所有覆盖窗口
CleanupOverlayWindows() {
    global overlayGui
    ; 销毁所有覆盖窗口
    for hwnd, gui in overlayGui {
        gui.Destroy()
    }
    ; 清空Map
    overlayGui.Clear()
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
        ; 清理覆盖窗口
        CleanupOverlayWindows()
        
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
        if ProcessExist(obsidianProcess) {
            ; 清理覆盖窗口
            CleanupOverlayWindows()
            ProcessClose(obsidianProcess)
        }
    } else {
        ; 如果选择No，显示所有隐藏的Obsidian窗口
        if ProcessExist(obsidianProcess) {
            ; 获取所有窗口，包括隐藏的
            DetectHiddenWindows(true)
            windowList := WinGetList("ahk_exe " obsidianProcess)
            DetectHiddenWindows(false)
            
            ; 显示所有主窗口
            for hwnd in windowList {
                DetectHiddenWindows(true)
                title := WinGetTitle("ahk_id " hwnd)
                isVisible := DllCall("IsWindowVisible", "Ptr", hwnd)
                DetectHiddenWindows(false)
                
                ; 只处理主窗口
                if title != "" && title != "Obsidian" && !isVisible {
                    WinShow("ahk_id " hwnd)
                    WinActivate("ahk_id " hwnd)
                }
            }
        }
        
        ; 清理覆盖窗口
        CleanupOverlayWindows()
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
    
    ; 检查Obsidian是否已经在运行
    if ProcessExist(obsidianProcess) {
        obsidianRunning := true
        
        ; 无论是否已运行，都确保隐藏所有主窗口
        windowList := WinGetList("ahk_exe " obsidianProcess)
        hasHiddenWindow := false
        
        for hwnd in windowList {
            title := WinGetTitle("ahk_id " hwnd)
            ; 只隐藏主窗口，不隐藏仓库选择窗口
            if title != "" && title != "Obsidian" {
                WinHide("ahk_id " hwnd)
                hasHiddenWindow := true
            }
        }
        
        ; 更新可见性状态
        obsidianVisible := false
        
        ; 更新托盘菜单状态
        UpdateTrayMenu()
        
        ; 初始化关闭按钮覆盖
        InitCloseButtonOverride()
    } else {
        ; Obsidian未运行，启动它
        Run(obsidianPath)
        
        ; 等待Obsidian启动
        try {
            WinWait("ahk_exe " obsidianProcess, , 5)
            Sleep(2000) ; 给Obsidian一些时间加载
            
            obsidianRunning := true
            
            ; 等待并隐藏所有主窗口
            Loop 5 { ; 尝试最多5次
                windowList := WinGetList("ahk_exe " obsidianProcess)
                hasHiddenWindow := false
                
                for hwnd in windowList {
                    title := WinGetTitle("ahk_id " hwnd)
                    ; 只隐藏主窗口，不隐藏仓库选择窗口
                    if title != "" && title != "Obsidian" {
                        WinHide("ahk_id " hwnd)
                        hasHiddenWindow := true
                    }
                }
                
                if hasHiddenWindow {
                    break
                }
                Sleep(500) ; 等待500毫秒后重试
            }
            
            ; 更新可见性状态
            obsidianVisible := false
            
            ; 更新托盘菜单状态
            UpdateTrayMenu()
            
            ; 初始化关闭按钮覆盖
            InitCloseButtonOverride()
        } catch {
            TrayTip("Obsidian增强脚本", "启动Obsidian超时", 3)
        }
    }
}

; 检查Obsidian窗口并覆盖关闭按钮
CheckAndOverrideCloseButton() {
    global obsidianRunning, overlayGui
    
    if !obsidianRunning || !ProcessExist(obsidianProcess) {
        CleanupOverlayWindows()
        return
    }
    
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mouseX, &mouseY, &mouseWin)
    
    windowList := WinGetList("ahk_exe " obsidianProcess)
    currentWindows := Map()
    
    for hwnd in windowList {
        title := WinGetTitle("ahk_id " hwnd)
        if title != "" && title != "Obsidian" {
            currentWindows[hwnd] := true
            
            isVisible := DllCall("IsWindowVisible", "Ptr", hwnd)
            
            if !isVisible {
                if overlayGui.Has(hwnd) {
                    try overlayGui[hwnd].Hide()
                }
                continue
            }
            
            WinGetPos(&x, &y, &width, &height, "ahk_id " hwnd)
            
            buttonSize := 42
            padding := 5  ; 增加5像素的检测边距
            closeButtonX := x + width - buttonSize - 10
            closeButtonY := y + 0
            
            isMouseInCloseButton := (mouseX >= closeButtonX - padding && mouseX <= closeButtonX + buttonSize + padding && 
                                   mouseY >= closeButtonY - padding && mouseY <= closeButtonY + buttonSize + padding)
            
            if isMouseInCloseButton {
                if !overlayGui.Has(hwnd) {
                    try {
                        overlayGui[hwnd] := Gui("-Caption +AlwaysOnTop +ToolWindow +Owner" hwnd)
                        overlayGui[hwnd].BackColor := "FF0000"
                        overlayGui[hwnd].MarginX := 0
                        overlayGui[hwnd].MarginY := 0
                        
                        btn := overlayGui[hwnd].Add("Button", "x0 y0 w" buttonSize " h" buttonSize " -Border")
                        btn.Opt("+Background" overlayGui[hwnd].BackColor)
                        
                        currentHwnd := hwnd
                        btn.OnEvent("Click", HideObsidianCallback.Bind(currentHwnd))
                    }
                }
                
                try overlayGui[hwnd].Show("x" closeButtonX " y" closeButtonY " w" buttonSize " h" buttonSize " NoActivate")
            } else {
                if overlayGui.Has(hwnd) {
                    try overlayGui[hwnd].Hide()
                }
            }
        }
    }
    
    for hwnd in overlayGui {
        if !currentWindows.Has(hwnd) {
            try overlayGui[hwnd].Destroy()
            overlayGui.Delete(hwnd)
        }
    }
}

; 回调函数：隐藏Obsidian窗口
HideObsidianCallback(hwnd, ctrl, *) {
    global overlayGui  ; 使用全局的overlayGui
    
    ; 隐藏Obsidian窗口
    WinHide("ahk_id " hwnd)
    
    ; 隐藏对应的覆盖窗口
    if overlayGui.Has(hwnd) {
        overlayGui[hwnd].Hide()
    }
    
    ; 更新状态
    global obsidianVisible
    obsidianVisible := false
}

; 初始化关闭按钮拦截
InitCloseButtonOverride() {
    global processCheckTimer
    
    ; 停止现有的定时器（如果有）
    if processCheckTimer {
        SetTimer(CheckAndOverrideCloseButton, 0)
    }
    
    ; 启动新的定时器
    SetTimer(CheckAndOverrideCloseButton, 100)
    processCheckTimer := 1
}

; 热键：Win+Z 切换Obsidian可见性
#z::ToggleObsidian()

; 添加一个新的热键来真正关闭Obsidian窗口（用于测试）
#!z::
{
    ; 清理覆盖窗口
    CleanupOverlayWindows()
    
    windowList := WinGetList("ahk_exe " obsidianProcess)
    for hwnd in windowList {
        WinClose("ahk_id " hwnd)
    }
}

; 添加进程监控函数
MonitorObsidianProcess() {
    global obsidianRunning, processCheckTimer
    
    ; 检查Obsidian进程状态
    isRunning := ProcessExist(obsidianProcess)
    
    ; 如果状态发生变化
    if (isRunning && !obsidianRunning) {
        ; Obsidian刚刚启动
        obsidianRunning := true
        UpdateTrayMenu()
        InitCloseButtonOverride()
    } 
    else if (!isRunning && obsidianRunning) {
        ; Obsidian已经退出
        obsidianRunning := false
        obsidianVisible := false
        CleanupOverlayWindows()
        UpdateTrayMenu()
        
        ; 如果定时器还在运行，停止它
        if processCheckTimer {
            SetTimer(CheckAndOverrideCloseButton, 0)
        }
    }
} 