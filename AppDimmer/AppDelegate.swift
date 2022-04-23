//
//  AppDelegate.swift
//  AppDimmer
//
//  Created by apple on 2021/11/22.
//

import Cocoa
import ServiceManagement

extension String {
    //本地化字符串功能
    func local() -> String {
        return NSLocalizedString(self, comment: "")
    }
}

extension Bundle {
    var displayName: String? {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
    }
    var name: String? {
        return object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}

//为NSWindow新建子类
class NNSWindow : NSWindow {
    //重写constrainFrameRect以支持从可见区域外绘制窗口
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var timer: Timer?
    var menuSlider = NSSlider()
    var level = UserDefaults.standard.integer(forKey: "level")
    var disable = UserDefaults.standard.bool(forKey: "disable")
    var darkOnly = UserDefaults.standard.bool(forKey: "darkOnly")
    var appList = [String]()
    var MaskList = [NNSWindow]()
    var statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
    var foundHelper = false
    let menu = NSMenu()
    let options = NSMenu()
    let helperBundleName = "com.lihaoyun6.AppDimmerLoginHelper"

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        //获取自启代理状态
        foundHelper = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == helperBundleName }
        let listFromUserDefaults = UserDefaults.standard.array(forKey: "appList")
        if listFromUserDefaults == nil{
            addToAppList(nil)
        }else{
            appList = listFromUserDefaults as! [String]
            if appList == [] {addToAppList(nil)}
        }
        //如果亮度级别不存在, 则预设为50
        if level == 0{
            level = 50
            UserDefaults.standard.set(level, forKey: "level")
        }
        
        //生成主菜单
        mainMenu()
        
        //初始化定时器
        timer = Timer(timeInterval: 0.05, repeats: true, block: {timer in self.loopFireHandler(timer)})
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    //文件选择器
    func selectFile() -> URL {
        let dialog = NSOpenPanel()
        dialog.message = "请选择要添加到名单的程序:".local()
        dialog.canChooseDirectories = false
        dialog.allowsMultipleSelection = false
        dialog.allowedFileTypes = ["app"]
        
        let launcherLogPathWithTilde = "/Applications" as NSString
        let expandedLauncherLogPath = launcherLogPathWithTilde.expandingTildeInPath
        dialog.directoryURL = NSURL.fileURL(withPath: expandedLauncherLogPath, isDirectory: true)
      
        var fileChoice: URL?
        if dialog.runModal() == NSApplication.ModalResponse.OK {fileChoice = dialog.url}
        return fileChoice ?? URL(fileURLWithPath: "/Applications")
    }
    
    //列表操作窗口
    func dialogWithList(_ list: Array<String>, _ prompt: String) -> String{
        let arr = "{\"\(list.joined(separator: "\",\""))\"}"
        let ret = NSAppleScript(source: "choose from list \(arr) with prompt \"\(prompt)\"")!.executeAndReturnError(nil).stringValue!
        return ret
    }
    
    //显示关于窗口
    @objc func aboutDialog(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(self)
    }
    
    //响应滑块事件
    @objc func sliderValueChanged(_ sender: Any) {
        guard let slider = sender as? NSSlider,
              let event = NSApplication.shared.currentEvent else { return }
        switch event.type {
        case .leftMouseDown, .rightMouseDown:
            level = Int(100-slider.intValue)
            statusItem.button?.image = nil
            statusItem.button?.title = "\(slider.intValue)%"
        case .leftMouseUp, .rightMouseUp:
            statusItem.button?.title.removeAll()
            menuIcon()
            UserDefaults.standard.set(level, forKey: "level")
        case .leftMouseDragged, .rightMouseDragged:
            level = Int(100-slider.intValue)
            statusItem.button?.image = nil
            statusItem.button?.title = "\(slider.intValue)%"
        default:
            break
        }
    }
    
    //弹窗功能
    @discardableResult
    func alert(_ title: String, _ message: String, _ button: String = "OK") -> Bool {
        let myPopup: NSAlert = NSAlert()
        myPopup.messageText = title
        myPopup.informativeText = message
        myPopup.alertStyle = NSAlert.Style.warning
        myPopup.addButton(withTitle: button)
        return myPopup.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn
    }
    
    //设置"启用 AppDimmer"
    @objc func setDisable(_ sender: NSMenuItem) {
        disable.toggle()
        menuSlider.isEnabled = !disable
        menuIcon()
        menu.item(withTitle: sender.title)?.state = state(!disable)
        UserDefaults.standard.set(disable, forKey: "disable")
    }
    
    //设置"仅在深色模式生效"
    @objc func setDarkOnly(_ sender: NSMenuItem) {
        darkOnly.toggle()
        options.item(withTitle: sender.title)?.state = state(darkOnly)
        UserDefaults.standard.set(darkOnly, forKey: "darkOnly")
    }
    
    @objc func addToAppList(_ sender: Any?) {
        let bundle = Bundle.init(url: selectFile())
        var appName = ""
        if let name = bundle?.name {appName = name}
        if let displayName = bundle?.displayName {appName = displayName}
        if appName != "" && !appList.contains(appName){
            appList.append(appName)
            UserDefaults.standard.set(appList, forKey: "appList")
        }
    }
    
    @objc func editAppList(_ sender: Any?) {
        let appName = dialogWithList(appList, "请选择要移出名单的程序:".local())
        appList = appList.filter{$0 != appName}
        UserDefaults.standard.set(appList, forKey: "appList")
    }
    
    //设置"登录时启动"
    @objc func setRunAtLogin(_ sender: NSMenuItem) {
        foundHelper.toggle()
        SMLoginItemSetEnabled(helperBundleName as CFString, foundHelper)
        options.item(withTitle: sender.title)?.state = state(foundHelper)
    }
    
    //初始化菜单栏按钮
    func menuIcon(){
        //初始化菜单栏按钮
        if let button = statusItem.button {
            if !disable{
                button.image = NSImage(named:NSImage.Name("MenuBarIcon"))
            }else{
                button.image = NSImage(named:NSImage.Name("MenuBarIcon_Disable"))
            }
        }
    }
    
    //主菜单生成函数
    func mainMenu(){
        menuIcon()
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "启用 AppDimmer".local(), action: #selector(setDisable(_:)), keyEquivalent: "").state = state(!disable)
        menu.setSubmenu(options, for: menu.addItem(withTitle: "偏好设置...".local(), action: nil, keyEquivalent: ""))
        options.addItem(withTitle: "登录时启动".local(), action: #selector(setRunAtLogin(_:)), keyEquivalent: "").state = state(foundHelper)
        options.addItem(withTitle: "跟随系统深色模式".local(), action: #selector(setDarkOnly(_:)), keyEquivalent: "").state = state(darkOnly)
        options.addItem(NSMenuItem.separator())
        options.addItem(withTitle: "添加App...".local(), action: #selector(addToAppList(_:)), keyEquivalent: "")
        options.addItem(withTitle: "从名单移除...".local(), action: #selector(editAppList(_:)), keyEquivalent: "")
        
        menu.addItem(NSMenuItem.separator())
        //menu.addItem(withTitle: "赞助一瓶快乐水".local(), action: #selector(aboutDialog(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "关于 AppDimmer".local(), action: #selector(aboutDialog(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "退出".local(), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        statusItem.menu = menu
        
        let menuSliderItem = NSMenuItem()
        menuSlider = NSSlider.init(frame: NSRect(x: 10, y: 0, width: menu.size.width-20, height: 32))
        let view = NSView.init(frame: NSRect(x: 0, y: 0, width: menu.size.width, height: 32))
        view.addSubview(menuSlider)
        menuSlider.sliderType = NSSlider.SliderType.linear
        menuSlider.isEnabled = !disable
        menuSlider.isContinuous = true
        menuSlider.action = #selector(sliderValueChanged(_:))
        menuSlider.minValue = 1
        menuSlider.maxValue = 99
        menuSlider.intValue = Int32(100-level)
        menuSliderItem.view = view
        menu.insertItem(menuSliderItem, at: 0)
    }
    
    //将Bool值转换为NSControl.StateValue
    func state(_ input: Bool) -> NSControl.StateValue {
        if input { return NSControl.StateValue.on }
        return NSControl.StateValue.off
    }
    
    //深色模式检测函数
    func isDarkMode() -> Bool {
        if !darkOnly { return true }
        let dark = NSApplication.shared.effectiveAppearance.debugDescription.lowercased()
        if dark.contains("dark") { return true }
        return false
    }
    
    //CGRect坐标系转为NSRect
    func CGtoNS(_ bound: CGRect) ->NSRect{
        let newY = NSScreen.screens[0].frame.height - bound.size.height - bound.origin.y
        let frame = NSRect(x: bound.origin.x, y: newY, width: bound.size.width, height: bound.size.height)
        return frame
    }
    
    //批量生成遮罩窗体
    func createMask(_ frontVisibleAppName: String, _ appWindows: [Dictionary<String, AnyObject>]){
        let n = appWindows.count - MaskList.count
        if n>0 {
            for _ in 1...n { MaskList.append(NNSWindow(contentRect: .init(origin: .zero, size: .init(width: 0, height: 0)), styleMask: [.titled], backing: .buffered, defer: false)) }
        } else if n<0 {
            for i in 0..<max(abs(n), MaskList.count) { MaskList[i].orderOut(self) }
        }
        
        for (i,Window) in appWindows.enumerated(){
            let bound = CGtoNS(CGRect(dictionaryRepresentation: Window[kCGWindowBounds as String] as! CFDictionary)!)
            let number = Window[kCGWindowNumber as String] as! Int
            
            MaskList[i].isOpaque = false
            MaskList[i].ignoresMouseEvents = true
            MaskList[i].titlebarAppearsTransparent = true
            MaskList[i].hasShadow = false
            MaskList[i].backgroundColor = NSColor(white: 0.0, alpha: CGFloat(level)/100)
            MaskList[i].styleMask = .titled
            MaskList[i].level = .normal
            if i == 0 && appList.contains(frontVisibleAppName){MaskList[i].level = NSWindow.Level.floating}
            for screen in NSScreen.screens { if NSEqualRects(screen.frame,bound) { MaskList[i].styleMask = .borderless } }
            MaskList[i].setFrame(bound, display: true)
            MaskList[i].order(.above, relativeTo: number)
            //MaskList[i].makeKeyAndOrderFront(self)
        }
    }
    
    //循环体
    @objc func loopFireHandler(_ timer: Timer?) -> Void {
        //检测启动条件
        if isDarkMode() && !disable && level != 1 {
            //声明窗口区域列表
            var appWindows = [Dictionary<String, AnyObject>]()
            //检测当前屏幕上所有的可见窗口
            if let windowList = CGWindowListCopyWindowInfo([.excludeDesktopElements,.optionOnScreenOnly], kCGNullWindowID) as? [[String: AnyObject]] {
                let visibleWindows = windowList.filter{ $0["kCGWindowLayer"] as! Int == 0 }
                for window in visibleWindows {
                    //获取窗口所属App名称
                    let owner = window[kCGWindowOwnerName as String] as! String
                    let bound = CGtoNS(CGRect(dictionaryRepresentation: window[kCGWindowBounds as String] as! CFDictionary)!)
                    //获取所需的窗口区域信息
                    if appList.contains(owner) {
                        if owner == "QQ" {
                            if bound.size.width > 160.0 && bound.size.height > 160.0 { if bound.size.width != 420.0 && bound.size.height != 277.0 { appWindows.append(window) } }
                        }else{
                            appWindows.append(window)
                        }
                    }
                }
                
                //获取最顶层可见窗口所属的App名称
                if let frontVisibleApp = visibleWindows.first{
                    var frontVisibleAppName = frontVisibleApp[kCGWindowOwnerName as String] as! String
                    if frontVisibleAppName == "Window Server" {
                        let frontVisibleApp = visibleWindows[1]
                        frontVisibleAppName = frontVisibleApp[kCGWindowOwnerName as String] as! String
                    }
                    createMask(frontVisibleAppName, appWindows)
                }
            } else {
                alert("出现错误".local(), "无法获取窗口列表!".local(), "退出".local())
                NSApplication.shared.terminate(self)
            }
        }else{
            for w in MaskList {w.orderOut(self)}
        }
    }
}


