#Requires AutoHotkey v2.0
#SingleInstance Force

; Obsidian增强脚本
; 作者：由Cursor AI辅助开发
; 版本：1.0
; 描述：增强Obsidian的使用体验，提供智能窗口管理和托盘功能

; 全局变量
global obsidianPath := "C:\Program Files\Obsidian\Obsidian.exe"  ; 默认路径，将被配置文件覆盖
global obsidianProcess := "Obsidian.exe"
global obsidianVisible := false  ; 控制Obsidian是否可见
global obsidianRunning := false  ; 控制Obsidian是否运行
global processCheckTimer := 0  ; 用于存储进程检查定时器ID

; 加载配置文件
if FileExist("config.local.ini") {
    try {
        ; 从INI文件读取Obsidian路径
        iniPath := IniRead("config.local.ini", "Paths", "ObsidianPath", obsidianPath)
        if (iniPath && iniPath != "ERROR") {
            obsidianPath := iniPath
            LogMessage("已从配置文件加载Obsidian路径: " . obsidianPath)
        }
        
        ; 读取其他设置（如果有）
        ; otherSetting := IniRead("config.local.ini", "Settings", "OtherSetting", "默认值")
    } catch as err {
        LogMessage("加载配置文件失败: " . err.Message)
    }
} else {
    LogMessage("未找到配置文件，使用默认设置")
}

; 初始化
InitTray()
CheckObsidian()
AutoStartObsidian()  ; 添加自动启动功能

; 启动进程监控
SetTimer(MonitorObsidianProcess, 1000)  ; 每秒检查一次进程状态

; 启动鼠标位置监控
SetTimer(CheckMousePosition, 100)  ; 每100毫秒检查一次鼠标位置

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
            if title != "" && title != "Obsidian" {
                WinHide("ahk_id " hwnd)
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
        if ProcessExist(obsidianProcess) {
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
        } catch {
            TrayTip("Obsidian增强脚本", "启动Obsidian超时", 3)
        }
    }
}

; 检查鼠标位置并处理关闭按钮点击
CheckMousePosition() {
    global obsidianRunning, obsidianProcess
    static inCloseButton := false  ; 静态变量，记录鼠标是否在关闭按钮区域
    
    if !obsidianRunning || !ProcessExist(obsidianProcess) {
        return
    }
    
    ; 设置坐标模式为屏幕
    CoordMode("Mouse", "Screen")
    
    ; 获取鼠标位置和当前窗口
    MouseGetPos(&mx, &my, &_WinId)
    
    ; 获取窗口信息
    WinGetPos(&x, &y, &w, &h, "ahk_id " _WinId)
    
    ; 获取窗口程序名
    program := WinGetProcessName("ahk_id " _WinId)
    
    ; 如果不是Obsidian窗口，直接返回
    if (program != obsidianProcess) {
        if (inCloseButton) {
            ; 如果之前在关闭按钮区域，现在不是Obsidian窗口，清除状态
            ToolTip()
            Hotkey("LButton", "Off")
            Hotkey("RButton", "Off")
            inCloseButton := false
        }
        return
    }
    
    ; 获取系统边框和标题栏尺寸
    SM_CXSIZEFRAME := DllCall("GetSystemMetrics", "Int", 32)
    SM_CYSIZEFRAME := DllCall("GetSystemMetrics", "Int", 33)
    SM_CXSIZE := DllCall("GetSystemMetrics", "Int", 30)
    SM_CYSIZE := DllCall("GetSystemMetrics", "Int", 31)
    
    ; 计算关闭按钮区域
    l := x + w - SM_CXSIZEFRAME - SM_CXSIZE - 10
    t := y - SM_CYSIZEFRAME
    r := x + w - SM_CXSIZEFRAME
    b := y + SM_CYSIZE + SM_CYSIZEFRAME
    
    ; 判断鼠标是否在关闭按钮区域内
    if (mx >= l && mx <= r && my >= t && my <= b) {
        ; 如果之前不在关闭按钮区域，现在进入了
        if (!inCloseButton) {
            ; 显示提示
            ToolTip("左键：最小化到托盘`n右键：关闭窗口")
            
            ; 保存当前窗口ID，用于回调函数
            global currentObsidianWindow := _WinId
            
            ; 设置左键点击事件
            Hotkey("LButton", HideObsidianWindow, "On")
            
            ; 设置右键点击事件
            Hotkey("RButton", CloseObsidianWindow, "On")
            
            inCloseButton := true
            LogMessage("鼠标进入关闭按钮区域，已启用左右键事件")
        }
    } else {
        ; 如果之前在关闭按钮区域，现在离开了
        if (inCloseButton) {
            ; 清除提示
            ToolTip()
            
            ; 关闭左键点击事件
            Hotkey("LButton", "Off")
            
            ; 关闭右键点击事件
            Hotkey("RButton", "Off")
            
            inCloseButton := false
            LogMessage("鼠标离开关闭按钮区域，已禁用左右键事件")
        }
    }
}

; 隐藏Obsidian窗口（点击关闭按钮时）
HideObsidianWindow(*) {
    global currentObsidianWindow
    
    ; 检查窗口是否存在
    if !WinExist("ahk_id " currentObsidianWindow) {
        ToolTip()
        return
    }
    
    ; 隐藏窗口
    WinHide("ahk_id " currentObsidianWindow)
    
    ; 更新状态
    global obsidianVisible := false
    
    ; 清除提示
    ToolTip()
    
    LogMessage("用户点击关闭按钮，隐藏了Obsidian窗口")
}

; 关闭Obsidian窗口（右键点击关闭按钮时）
CloseObsidianWindow(*) {
    global currentObsidianWindow
    
    ; 检查窗口是否存在
    if !WinExist("ahk_id " currentObsidianWindow) {
        ToolTip()
        return
    }
    
    ; 关闭窗口
    WinClose("ahk_id " currentObsidianWindow)
    
    ; 清除提示
    ToolTip()
    
    LogMessage("用户右键点击关闭按钮，关闭了Obsidian窗口")
    
    ; 检查是否还有其他Obsidian窗口
    windowList := WinGetList("ahk_exe " obsidianProcess)
    if windowList.Length = 0 {
        ; 如果没有其他窗口，更新状态
        global obsidianRunning := false
        global obsidianVisible := false
        
        ; 更新托盘菜单状态
        UpdateTrayMenu()
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
    } 
    else if (!isRunning && obsidianRunning) {
        ; Obsidian已经退出
        obsidianRunning := false
        obsidianVisible := false
        UpdateTrayMenu()
    }
}

; 热键：Win+Z 切换Obsidian可见性
#z::ToggleObsidian()

; 添加一个新的热键来真正关闭Obsidian窗口（用于测试）
#!z::
{
    windowList := WinGetList("ahk_exe " obsidianProcess)
    for hwnd in windowList {
        WinClose("ahk_id " hwnd)
    }
}

; 日志记录函数
LogMessage(message) {
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    logFile := "obsidian_enhance.log"
    FileAppend(timestamp . " - " . message . "`n", logFile, "UTF-8")
} 