//
//  AppDelegate.swift
//  AppDimmer
//
//  Created by apple on 2021/11/22.
//

import Cocoa
import AXSwift
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
    var cleanMode = UserDefaults.standard.bool(forKey: "cleanMode")
    var appList = [String]()
    var unStandardWindows = [CGSize]()
    var statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
    var foundHelper = false
    var count = 0
    let menu = NSMenu()
    let options = NSMenu()
    let helperBundleName = "com.lihaoyun6.AppDimmerLoginHelper"
    let levelWhiteList = [kCGNormalWindowLevel,kCGFloatingWindowLevel,kCGTornOffMenuWindowLevel,kCGTornOffMenuWindowLevel,kCGModalPanelWindowLevel,kCGScreenSaverWindowLevel,kCGDockWindowLevel,1]
    let levelBlackList = [kCGMainMenuWindowLevel,kCGStatusWindowLevel]

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        //检查辅助功能权限
        if cleanMode {_ = UIElement.isProcessTrusted(withPrompt: true)}
        //获取自启代理状态
        foundHelper = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == helperBundleName }
        let listFromUserDefaults = UserDefaults.standard.array(forKey: "appList")
        if listFromUserDefaults == nil{
            addToAppList(nil)
        }else{
            appList = listFromUserDefaults as! [String]
            if appList == [] {addToAppList(nil)}
        }
        
        //初始化设定
        if level == 0{
            level = 70
            UserDefaults.standard.set(level, forKey: "level")
            darkOnly = true
            UserDefaults.standard.set(darkOnly, forKey: "darkOnly")
        }
        
        //生成主菜单
        mainMenu()
        
        //初始化定时器
        timer = Timer(timeInterval: 0.06, repeats: true, block: {timer in self.loopFireHandler(timer)})
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func windows() -> Array<NSWindow>{
        return NSApplication.shared.windows.filter{$0.className == "AppDimmer.NNSWindow"}
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
            menu.items[2].title = "\("透明度".local()): \(slider.intValue)%"
        case .leftMouseUp, .rightMouseUp:
            menu.items[2].title = "启用 AppDimmer".local()
            menuIcon()
            UserDefaults.standard.set(level, forKey: "level")
        case .leftMouseDragged, .rightMouseDragged:
            level = Int(100-slider.intValue)
            menu.items[2].title = "\("透明度".local()): \(slider.intValue)%"
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
    
    //添加到匹配名单
    @objc func addToAppList(_ sender: Any?) {
        let bundle = Bundle.init(url: selectFile())
        var appName = ""
        if let name = bundle?.name {appName = name}
        if let displayName = bundle?.displayName {appName = displayName}
        if appName != "" && appName != "AppDimmer" && !appList.contains(appName){
            appList.append(appName)
            UserDefaults.standard.set(appList, forKey: "appList")
        }
    }
    
    //从名单中移除
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
    
    //设置窗口匹配模式
    @objc func setCleanMode(_ sender: NSMenuItem) {
        cleanMode.toggle()
        if cleanMode {_ = UIElement.isProcessTrusted(withPrompt: true)}
        options.item(withTitle: sender.title)?.state = state(cleanMode)
        UserDefaults.standard.set(cleanMode, forKey: "cleanMode")
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
        options.addItem(withTitle: "减少窗口匹配".local(), action: #selector(setCleanMode(_:)), keyEquivalent: "").state = state(cleanMode)
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
        let maskList = windows()
        let mc = maskList.count
        let n = appWindows.count - mc
        if n<0 { for i in 1...abs(n) {maskList[mc-i].orderOut(self)} }
        for (i,Window) in appWindows.enumerated(){
            let bound = CGtoNS(CGRect(dictionaryRepresentation: Window[kCGWindowBounds as String] as! CFDictionary)!)
            let owner = Window[kCGWindowOwnerName as String] as! String
            let number = Window[kCGWindowNumber as String] as! Int
            var layer = Window[kCGWindowLayer as String] as! Int
            if (i == 0 && frontVisibleAppName == owner) { layer += 1 }
            var mask: NSWindow!
            if i+1 > mc {
                mask = NNSWindow(contentRect: .init(origin: .zero, size: .init(width: 0, height: 0)), styleMask: [.titled], backing: .buffered, defer: false)
            }else{
                mask = maskList[i]
            }
            mask.level = NSWindow.Level.init(rawValue: layer)
            mask.sharingType = .none
            mask.collectionBehavior = [.transient, .ignoresCycle]
            mask.backgroundColor = NSColor(white: 0.0, alpha: CGFloat(level)/100)
            mask.isOpaque = false
            mask.hasShadow = false
            mask.ignoresMouseEvents = true
            mask.titlebarAppearsTransparent = true
            for screen in NSScreen.screens { if NSEqualRects(screen.frame,bound) { mask.styleMask = .borderless } }
            mask.setFrame(bound, display: true)
            mask.order(.above, relativeTo: number)
            //mask.makeKeyAndOrderFront(self)
        }
        //辅助功能检测延时, 防止CPU占用过高
        if count == 10 { count = 0 } else { count += 1 }
    }
    
    //循环体
    @objc func loopFireHandler(_ timer: Timer?) -> Void {
        let fApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        //检测启动条件
        if isDarkMode() && !disable && level != 1 {
            //通过辅助功能权限排除特定属性的窗口
            if cleanMode && UIElement.isProcessTrusted() && count == 0 && appList.contains(fApp){
                var unStandardWindowsT = [CGSize]()
                let applications = NSWorkspace.shared.runningApplications.filter{appList.contains($0.localizedName ?? "")}
                for application in applications {
                    let uiApp = Application(application)!
                    guard let t = try? uiApp.windows() ?? [] else {return}
                    let dialogs = t.filter{guard let a = try? $0.attribute(.subrole) == "AXSystemDialog" else {return false};return a}
                    for dialog in dialogs {
                        let attribs = try! dialog.getMultipleAttributes(.position, .size)
                        let size = (attribs[AXSwift.Attribute.size] ?? (0.0, 0.0)) as! CGSize
                        unStandardWindowsT.append(size)
                    }
                }
                unStandardWindows = unStandardWindowsT
            }
            //声明窗口区域列表
            var appWindows = [Dictionary<String, AnyObject>]()
            //检测当前屏幕上所有的可见窗口
            if let windowList = CGWindowListCopyWindowInfo([.excludeDesktopElements,.optionOnScreenOnly], kCGNullWindowID) as? [[String: AnyObject]] {
                var visibleWindows = windowList.filter{$0["kCGWindowAlpha"] as! Float != 0.0}
                if cleanMode {
                    visibleWindows = visibleWindows.filter{levelWhiteList.contains(CGWindowLevel($0["kCGWindowLayer"] as! Int))}
                }else{
                    visibleWindows = visibleWindows.filter{!levelBlackList.contains(CGWindowLevel($0["kCGWindowLayer"] as! Int))}
                }
                for window in visibleWindows {
                    //获取窗口所属App名称
                    let owner = window[kCGWindowOwnerName as String] as! String
                    let bound = CGtoNS(CGRect(dictionaryRepresentation: window[kCGWindowBounds as String] as! CFDictionary)!)
                    //获取所需的窗口区域信息
                    let w = bound.size.width
                    let h = bound.size.height
                    //获取所需的窗口区域信息
                    if appList.contains(owner) && (!unStandardWindows.contains(CGSize(width: w, height: h)) || !cleanMode){
                        if owner == "QQ" {
                            if (w != 112.0 && h != 112.0) && (w != 142.0 && h != 142.0) && (w != 420.0 && h != 277.0) && w != 260 && h != 35 && window[kCGWindowLayer as String] as! Int != 500 { appWindows.append(window) }
                        }else{
                            appWindows.append(window)
                        }
                    }
                }
                createMask(fApp, appWindows)
            } else {
                alert("出现错误".local(), "无法获取窗口列表!".local(), "退出".local())
                NSApplication.shared.terminate(self)
            }
        }else{
            for w in windows() {w.orderOut(self)}
        }
    }
}


