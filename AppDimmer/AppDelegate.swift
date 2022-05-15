//
//  AppDelegate.swift
//  AppDimmer
//
//  Created by apple on 2021/11/22.
//

import Cocoa
import AXSwift
import ServiceManagement

//扩展本地化字符串功能
extension String {
    var local: String { return NSLocalizedString(self, comment: "") }
}

//重写constrainFrameRect以支持从可见区域外绘制窗口
class NNSWindow : NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { return frameRect }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var observer: Any!
    var timer: Timer?
    var level = UserDefaults.standard.integer(forKey: "level")
    var disable = UserDefaults.standard.bool(forKey: "disable")
    var darkOnly = UserDefaults.standard.bool(forKey: "darkOnly")
    var cleanMode = UserDefaults.standard.bool(forKey: "cleanMode")
    var appList = (UserDefaults.standard.array(forKey: "appList") ?? []) as! [String]
    var windowsCount = [String]()
    var unStandardWindows = [Array<Any>]()
    var fullScreenWindows = [NSRect]()
    var statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
    var fApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
    var foundHelper = false
    let menu = NSMenu()
    let options = NSMenu()
    let helperBundleName = "com.lihaoyun6.AppDimmerLoginHelper"
    let subRoleBlackList = ["AXSystemDialog"]
    let levelWhiteList = [0,1,3,8,20,1000]
    let levelBlackList = [24,25,500]
    /*
     kCGBackstopMenuLevel = -20
     kCGNormalWindowLevel = 0
     kCGFloatingWindowLevel = 3
     kCGTornOffMenuWindowLevel = 3
     kCGModalPanelWindowLevel = 8
     kCGUtilityWindowLevel = 19
     kCGDockWindowLevel = 20
     kCGMainMenuWindowLevel = 24
     kCGStatusWindowLevel = 25
     kCGPopUpMenuWindowLevel = 101
     kCGOverlayWindowLevel = 102
     kCGHelpWindowLevel = 200
     kCGDraggingWindowLevel = 500
     kCGScreenSaverWindowLevel = 1000
     kCGAssistiveTechHighWindowLevel = 1500
     */

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        //初始化设定
        if level == 0{
            level = 30
            darkOnly = true
            cleanMode = true
            UserDefaults.standard.set(level, forKey: "level")
            UserDefaults.standard.set(darkOnly, forKey: "darkOnly")
            UserDefaults.standard.set(cleanMode, forKey: "cleanMode")
        }
        //检查辅助功能权限
        if cleanMode {_ = UIElement.isProcessTrusted(withPrompt: true)}
        //获取自启代理状态
        foundHelper = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == helperBundleName }
        
        //生成主菜单
        menuIcon()
        menuWillOpen(menu)
        if !disable { startTimer() }
        
        //创建事件侦听
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleepListener(_:)), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleepListener(_:)), name: NSWorkspace.didWakeNotification, object: nil)
        observer = NSApp.observe(\.effectiveAppearance) { _, _ in self.isDarkMode() }
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
    
    func startTimer() {
        timer = Timer(timeInterval: 0.06, repeats: true, block: {timer in self.loopFireHandler(timer)})
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    func stopTimer() {
        timer?.invalidate()
        for w in windows() {w.orderOut(self)}
    }
    
    @objc func sleepListener(_ aNotification: Notification) {
        if aNotification.name == NSWorkspace.willSleepNotification {
            timer?.invalidate()
        } else if aNotification.name == NSWorkspace.didWakeNotification {
            startTimer()
        }
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
            menu.items[1].title = "\("亮度: ".local)\(slider.intValue)%"
        case .leftMouseUp, .rightMouseUp:
            menu.items[1].title = "\(fApp): \(getEnableText(fApp))"
            UserDefaults.standard.set(level, forKey: "level")
        case .leftMouseDragged, .rightMouseDragged:
            level = Int(100-slider.intValue)
            menu.items[1].title = "\("亮度: ".local)\(slider.intValue)%"
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
    
    //设置"仅在深色模式生效"
    @objc func setDarkOnly(_ sender: NSMenuItem) {
        darkOnly.toggle()
        sender.state = state(darkOnly)
        UserDefaults.standard.set(darkOnly, forKey: "darkOnly")
    }
    
    //添加到匹配名单
    @objc func editAppList(_ sender: NSMenuItem) {
        if fApp != "" && fApp != "AppDimmer"{
            if !appList.contains(fApp){
                sender.state = state(true)
                appList.append(fApp)
            } else {
                sender.state = state(false)
                appList = appList.filter{$0 != fApp}
            }
            UserDefaults.standard.set(appList, forKey: "appList")
        }
    }
    
    //设置"登录时启动"
    @objc func setRunAtLogin(_ sender: NSMenuItem) {
        foundHelper.toggle()
        SMLoginItemSetEnabled(helperBundleName as CFString, foundHelper)
        sender.state = state(foundHelper)
    }
    
    //设置窗口匹配模式
    @objc func setCleanMode(_ sender: NSMenuItem) {
        cleanMode.toggle()
        windowsCount.removeAll()
        if cleanMode {_ = UIElement.isProcessTrusted(withPrompt: true)}
        sender.state = state(cleanMode)
        UserDefaults.standard.set(cleanMode, forKey: "cleanMode")
    }
    
    //菜单栏按钮左右键响应
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == NSEvent.EventType.rightMouseUp {
            setDisable()
        } else {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
        }
    }
    
    //总开关
    func setDisable() {
        disable.toggle()
        if !disable { startTimer() } else { stopTimer() }
        statusItem.button?.image = NSImage(named:NSImage.Name("MenuBarIcon\(NSNumber(value: !disable).intValue)"))
        UserDefaults.standard.set(disable, forKey: "disable")
    }
    
    //初始化菜单栏按钮
    func menuIcon(){
        if let button = statusItem.button {
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.image = NSImage(named:NSImage.Name("MenuBarIcon\(NSNumber(value: !disable).intValue)"))
        }
    }
    
    //主菜单生成函数
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        options.removeAllItems()
        menu.delegate = self
        menu.autoenablesItems = false
        //menu.addItem(NSMenuItem.separator())
        let Switch = menu.addItem(withTitle: "\(fApp): \(getEnableText(fApp))", action: #selector(editAppList(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.setSubmenu(options, for: menu.addItem(withTitle: "偏好设置...".local, action: nil, keyEquivalent: ""))
        options.addItem(withTitle: "登录时启动".local, action: #selector(setRunAtLogin(_:)), keyEquivalent: "").state = state(foundHelper)
        options.addItem(NSMenuItem.separator())
        options.addItem(withTitle: "跟随系统主题".local, action: #selector(setDarkOnly(_:)), keyEquivalent: "").state = state(darkOnly)
        options.addItem(withTitle: "减少鬼影".local, action: #selector(setCleanMode(_:)), keyEquivalent: "").state = state(cleanMode)
        menu.addItem(withTitle: "关于 AppDimmer".local, action: #selector(aboutDialog(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "退出".local, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let menuSliderItem = NSMenuItem()
        let menuSlider = NSSlider.init(frame: NSRect(x: 10, y: 0, width: menu.size.width-20, height: 32))
        let view = NSView.init(frame: NSRect(x: 0, y: 0, width: menu.size.width, height: 32))
        view.addSubview(menuSlider)
        menuSlider.sliderType = NSSlider.SliderType.linear
        menuSlider.isEnabled = !disable
        menuSlider.isContinuous = true
        menuSlider.action = #selector(sliderValueChanged(_:))
        menuSlider.minValue = 10
        menuSlider.maxValue = 90
        menuSlider.intValue = Int32(100-level)
        menuSliderItem.view = view
        menu.insertItem(menuSliderItem, at: 0)
        menuSlider.isEnabled = !disable
        Switch.isEnabled = !disable && fApp != "AppDimmer"
        Switch.state = state(appList.contains(fApp))
    }
    
    //关闭菜单时清除
    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }
    
    //将Bool值转换为NSControl.StateValue
    func state(_ input: Bool) -> NSControl.StateValue {
        if input { return NSControl.StateValue.on }
        return NSControl.StateValue.off
    }
    
    //深色模式检测函数
    func isDarkMode() {
        if darkOnly {
            if NSApp.effectiveAppearance.name == NSAppearance.Name.darkAqua { startTimer() } else { stopTimer() }
        }
    }
    
    //获取提示字符串
    func getEnableText(_ name: String) -> String {
        if appList.contains(name) { return "已启用".local }
        return "未启用".local
    }
    
    //CGRect坐标系转为NSRect
    func CGtoNS(_ bound: CGRect) -> NSRect{
        let newY = NSScreen.screens[0].frame.height - bound.size.height - bound.origin.y
        let frame = NSRect(x: bound.origin.x, y: newY, width: bound.size.width, height: bound.size.height)
        return frame
    }
    
    //通过辅助功能权限获取窗口属性
    func getWindowAttribs() {
        if cleanMode && UIElement.isProcessTrusted() {
            unStandardWindows.removeAll()
            let apps = NSWorkspace.shared.runningApplications.filter{appList.contains($0.localizedName ?? "")}
            for app in apps {
                let uiApp = Application(app)!
                guard let windows = try? uiApp.windows() ?? [] else {return}
                for window in windows {
                    guard let attribs = try? window.getMultipleAttributes(.subrole, .children, .position, .size) else {return}
                    let children = (attribs[.children] ?? ()) as AnyObject
                    let subrole = (attribs[.subrole] ?? "") as AnyObject
                    let size = (attribs[.size] ?? (0.0, 0.0)) as! CGSize
                    unStandardWindows.append([app.localizedName ?? "", children.count ?? 0, subrole as! String, size])
                }
            }
        }
    }
    
    //通过辅助功能权限获取全屏窗口
    func getFullScreen() {
        Thread.detachNewThread {
            usleep(700000)
            self.fullScreenWindows.removeAll()
            let apps = NSWorkspace.shared.runningApplications.filter{self.appList.contains($0.localizedName ?? "")}
            for app in apps {
                let uiApp = Application(app)!
                guard let windows = try? uiApp.windows() ?? [] else {return}
                for window in windows {
                    guard let attribs = try? window.getMultipleAttributes(.position, .size, .fullScreen) else {return}
                    let fScreen = (attribs[.fullScreen] ?? 0) as! Int
                    if fScreen == 1 {
                        let posi = (attribs[.position] ?? (0.0, 0.0)) as! CGPoint
                        let size = (attribs[.size] ?? (0.0, 0.0)) as! CGSize
                        let rect = self.CGtoNS(CGRect(origin: posi, size: size))
                        self.fullScreenWindows.append(rect)
                    }
                }
            }
        }
    }
    
    //判断窗口是否处于全屏模式
    func isFullScreen(_ bound: NSRect) -> Bool {
        let fullscreen = NSScreen.screens.filter{ NSEqualRects($0.frame,bound) }
        if fullscreen.count > 0 || fullScreenWindows.contains(bound) { return true }
        return false
    }
    
    func getLayer(_ w: [String: AnyObject]) -> Int { return (w["kCGWindowLayer"] as! NSNumber).intValue }
    func getAlpha(_ w: [String: AnyObject]) -> Int { return (w["kCGWindowAlpha"] as! NSNumber).intValue }
    func getNumber(_ w: [String: AnyObject]) -> Int { return (w["kCGWindowNumber"] as! NSNumber).intValue }
    func getOwner(_ w: [String: AnyObject]) -> String { return w["kCGWindowOwnerName"] as! String }
    func getBound(_ w: [String: AnyObject]) -> CGRect { return CGtoNS(CGRect(dictionaryRepresentation: w["kCGWindowBounds"] as! CFDictionary)!) }
    
    //批量生成遮罩窗体
    func createMask(_ frontVisibleAppName: String, _ appWindows: [Dictionary<String, AnyObject>]){
        let maskList = windows()
        let mc = maskList.count
        let n = appWindows.count - mc
        if n<0 { for i in 1...abs(n) {maskList[mc-i].orderOut(self)} }
        for (i,w) in appWindows.enumerated(){
            let bound = getBound(w)
            let owner = getOwner(w)
            let number = getNumber(w)
            var layer = getLayer(w)
            if i == 0 && frontVisibleAppName == owner { layer += 1 }
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
            if isFullScreen(bound) { mask.styleMask = .borderless } else { mask.styleMask = .titled }
            mask.setFrame(bound, display: true)
            mask.order(.above, relativeTo: number)
            //mask.makeKeyAndOrderFront(self)
        }
    }
    
    //循环体
    @objc func loopFireHandler(_ timer: Timer?) -> Void {
        fApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        //声明窗口区域列表
        var appWindows = [[String: AnyObject]]()
        //检测当前屏幕上所有的可见窗口
        if let windowList = CGWindowListCopyWindowInfo([.excludeDesktopElements,.optionOnScreenOnly], kCGNullWindowID) as? [[String: AnyObject]] {
            var visibleWindows = windowList.filter{ levelWhiteList.contains(getLayer($0)) && getAlpha($0) > 0 && getBound($0).size.height > 50}
            if !cleanMode { visibleWindows = windowList.filter{ !levelBlackList.contains(getLayer($0))} }
            let windowInAppList = visibleWindows.filter{ appList.contains(getOwner($0)) }
            let wc: [String] = windowInAppList.map{ return "\(NSStringFromSize(getBound($0).size)),\(getLayer($0))" }
            if (wc.count != windowsCount.count) || (Set(wc) != Set(windowsCount)) { getWindowAttribs(); getFullScreen() }
            windowsCount = wc
            for w in windowInAppList {
                if !cleanMode { appWindows.append(w); continue }
                //获取窗口基本信息
                let owner = getOwner(w)
                //let boundCG = CGRect(dictionaryRepresentation: window[kCGWindowBounds as String] as! CFDictionary)!
                let bound = getBound(w)
                let layer = getLayer(w)
                let attribs = unStandardWindows.filter{ $0.first as! String == owner && $0.last as! CGSize == bound.size }
                if attribs.count != 0 {
                    if isFullScreen(bound) { appWindows.append(w); continue }
                    let childen = attribs.first?[1] as! Int
                    let subrole = attribs.first?[2] as! String
                    if (layer == 0 && subrole == "AXUnknown") {
                        let c = windowInAppList.filter{ let b = getBound($0); return getOwner($0) == owner && b != bound && NSContainsRect(b, bound) }
                        if c.count < 1 { appWindows.append(w) }
                    } else if !subRoleBlackList.contains(subrole) && childen > 0 {
                        appWindows.append(w)
                    }
                }else{
                    //appWindows.append(w)
                }
            }
            createMask(fApp, appWindows)
        } else {
            alert("出现错误".local, "无法获取窗口列表!".local, "退出".local)
            NSApplication.shared.terminate(self)
        }
    }
}


