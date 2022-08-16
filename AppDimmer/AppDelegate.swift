//
//  AppDelegate.swift
//  AppDimmer
//
//  Created by apple on 2021/11/22.
//

import Cocoa
import AXSwift
import HotKey
import ServiceManagement

//扩展本地化字符串功能
extension String {
    var local: String { return NSLocalizedString(self, comment: "") }
}

//扩展Bundle类
extension Bundle {
    var name: String? {
        if let name = object(forInfoDictionaryKey: "CFBundleDisplayName") as? String { if name != "" { return name } }
        return object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}

//重写constrainFrameRect以支持从可见区域外绘制窗口
class NNSWindow : NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { return frameRect }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var observer: Any!
    var timer: Timer?
    var pids = [Int: String]()
    var fps = (UserDefaults.standard.object(forKey: "fps") ?? 15) as! Int
    var level = (UserDefaults.standard.object(forKey: "level") ?? 30) as! Int
    var disable = UserDefaults.standard.bool(forKey: "disable")
    var darkOnly = (UserDefaults.standard.object(forKey: "darkOnly") ?? true) as! Bool
    var allowShot = UserDefaults.standard.bool(forKey: "allowShot")
    var xRayMode = "down"//UserDefaults.standard.string(forKey: "xRayMode") ?? "down"
    var xRayOn = (UserDefaults.standard.object(forKey: "xRayOn") ?? true) as! Bool
    var appList = (UserDefaults.standard.array(forKey: "appList") ?? []) as! [String]
    var lazyList = (UserDefaults.standard.array(forKey: "lazyList") ?? []) as! [String]
    var invList = (UserDefaults.standard.array(forKey: "invList") ?? []) as! [String]
    var menuBarCount = [String]()
    var windowsCount = [String]()
    var unStandardWindows = [Array<Any>]()
    var fullScreenWindows = [NSRect]()
    var statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
    let xRayKey = HotKey(key: .tab, modifiers: [.shift])
    var fApp = ""
    var xRay = false
    var foundHelper = false
    let helperBundleName = "com.lihaoyun6.AppDimmerLoginHelper"
    let subRoleBlackList = ["AXSystemDialog"]
    let levelWhiteList = [0,1,3,8,20,1000]
    let levelBlackList = [24,25,500]
    let menu = NSMenu()
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
        //检查辅助功能权限
        _ = UIElement.isProcessTrusted(withPrompt: true)
        //获取自启代理状态
        foundHelper = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == helperBundleName }
        
        //生成主菜单
        menuIcon()
        menuWillOpen(menu)
        if !disable { isDarkMode() }
        xRayKey.isPaused = !xRayOn
        
        //创建事件侦听
        //NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleepListener(_:)), name: NSWorkspace.willSleepNotification, object: nil)
        //NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleepListener(_:)), name: NSWorkspace.didWakeNotification, object: nil)
        observer = NSApp.observe(\.effectiveAppearance) { _, _ in self.isDarkMode() }
        xRayKey.keyDownHandler = { self.xRay = true }
        xRayKey.keyUpHandler = { self.xRay = false }
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
        timer?.invalidate()
        timer = Timer(timeInterval: TimeInterval(1.0/Float(fps)), repeats: true, block: {timer in self.loopFireHandler(timer)})
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    func stopTimer() {
        timer?.invalidate()
        for w in windows() {w.close()}
    }
    
    //@objc func sleepListener(_ aNotification: Notification) {
    //    if aNotification.name == NSWorkspace.willSleepNotification {
    //        timer?.invalidate()
    //    } else if aNotification.name == NSWorkspace.didWakeNotification {
    //        if !disable { isDarkMode() }
    //    }
    //}
    
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
    
    //设置"透视模式"
    @objc func setxRayMode(_ sender: NSMenuItem) {
        xRayKey.isPaused = false
        switch sender.title {
        case "停用透视键".local:
            xRayMode = "off"
            xRayKey.isPaused = true
        case "直接隐藏遮罩".local:
            xRayMode = "close"
        default:
            xRayMode = "down"
        }
        UserDefaults.standard.set(xRayMode, forKey: "xRayMode")
    }
    
    //设置刷新率
    @objc func setFPS(_ sender: NSMenuItem) {
        fps = Int(sender.title.replacingOccurrences(of: "FPS", with: "")) ?? 15
        UserDefaults.standard.set(fps, forKey: "fps")
        startTimer()
    }
    
    //设置"仅在深色模式生效"
    @objc func setDarkOnly(_ sender: NSMenuItem) {
        darkOnly.toggle()
        isDarkMode()
        sender.state = state(darkOnly)
        UserDefaults.standard.set(darkOnly, forKey: "darkOnly")
    }
    
    //设置"截屏时显示"
    @objc func setallowShot(_ sender: NSMenuItem) {
        allowShot.toggle()
        sender.state = state(!allowShot)
        UserDefaults.standard.set(allowShot, forKey: "allowShot")
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
    
    //添加到懒惰名单
    @objc func editLayzList(_ sender: NSMenuItem) {
        if fApp != "" && fApp != "AppDimmer"{
            if !lazyList.contains(fApp){
                sender.state = state(false)
                lazyList.append(fApp)
            } else {
                sender.state = state(true)
                lazyList = lazyList.filter{$0 != fApp}
            }
            UserDefaults.standard.set(lazyList, forKey: "lazyList")
        }
    }
    
    //添加到反色名单
    @objc func editInvList(_ sender: NSMenuItem) {
        if fApp != "" && fApp != "AppDimmer"{
            if !invList.contains(fApp){
                sender.state = state(true)
                invList.append(fApp)
            } else {
                sender.state = state(false)
                invList = invList.filter{$0 != fApp}
                for w in windows() {w.close()}
            }
            UserDefaults.standard.set(invList, forKey: "invList")
        }
    }
    
    //设置"登录时启动"
    @objc func setRunAtLogin(_ sender: NSMenuItem) {
        foundHelper.toggle()
        SMLoginItemSetEnabled(helperBundleName as CFString, foundHelper)
        sender.state = state(foundHelper)
    }
    
    //设置启用透视快捷键
    @objc func setxRayOn(_ sender: NSMenuItem) {
        xRayOn.toggle()
        sender.state = state(xRayOn)
        UserDefaults.standard.set(xRayOn, forKey: "xRayOn")
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
        if !disable { isDarkMode() } else { stopTimer() }
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
        fApp = getAppName(NSWorkspace.shared.frontmostApplication?.bundleURL)
        let enable = appList.contains(fApp)
        menu.removeAllItems()
        let options = NSMenu()
        let chooseFps = NSMenu()
        let xRayMenu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        let Switch = menu.addItem(withTitle: "\(fApp): \(getEnableText(fApp))", action: #selector(editAppList(_:)), keyEquivalent: "")
        let lazyMode = NSMenuItem(title: "过滤复杂窗口".local, action: #selector(editLayzList(_:)), keyEquivalent: "")
        let invMode = NSMenuItem(title: "反转颜色".local, action: #selector(editInvList(_:)), keyEquivalent: "")
        lazyMode.isEnabled = enable && !invList.contains(fApp)
        invMode.isEnabled = enable
        lazyMode.state = state(enable && !lazyList.contains(fApp) && !invList.contains(fApp))
        invMode.state = state(enable && invList.contains(fApp))
        menu.addItem(lazyMode)
        menu.addItem(invMode)
        menu.addItem(NSMenuItem.separator())
        menu.setSubmenu(options, for: menu.addItem(withTitle: "偏好设置...".local, action: nil, keyEquivalent: ""))
        options.addItem(withTitle: "登录时启动".local, action: #selector(setRunAtLogin(_:)), keyEquivalent: "").state = state(foundHelper)
        options.addItem(NSMenuItem.separator())
        options.addItem(withTitle: "跟随系统外观".local, action: #selector(setDarkOnly(_:)), keyEquivalent: "").state = state(darkOnly)
        options.addItem(withTitle: "截图时隐藏".local, action: #selector(setallowShot(_:)), keyEquivalent: "").state = state(!allowShot)
        options.addItem(withTitle: "透视键 [⇧⇥]".local, action: #selector(setxRayOn(_:)), keyEquivalent: "").state = state(xRayOn)
        options.addItem(NSMenuItem.separator())
        //options.setSubmenu(xRayMenu, for: options.addItem(withTitle: "顶层透视...".local, action: nil, keyEquivalent: ""))
        //xRayMenu.addItem(withTitle: "停用透视键".local, action: #selector(setxRayMode(_:)), keyEquivalent: "").state = state(xRayMode == "off")
        //xRayMenu.addItem(NSMenuItem.separator())
        //xRayMenu.addItem(withTitle: "切换遮盖方式".local, action: #selector(setxRayMode(_:)), keyEquivalent: "").state = state(xRayMode == "down")
        //xRayMenu.addItem(withTitle: "直接隐藏遮罩".local, action: #selector(setxRayMode(_:)), keyEquivalent: "").state = state(xRayMode == "close")
        options.setSubmenu(chooseFps, for: options.addItem(withTitle: "遮罩刷新率...".local, action: nil, keyEquivalent: ""))
        chooseFps.addItem(withTitle: "60FPS", action: #selector(setFPS(_:)), keyEquivalent: "")
        chooseFps.addItem(withTitle: "30FPS", action: #selector(setFPS(_:)), keyEquivalent: "")
        chooseFps.addItem(withTitle: "15FPS", action: #selector(setFPS(_:)), keyEquivalent: "")
        //options.addItem(withTitle: "减少鬼影".local, action: #selector(setCleanMode(_:)), keyEquivalent: "").state = state(cleanMode)
        chooseFps.item(withTitle: "\(fps)FPS")?.state = state(true)
        menu.addItem(withTitle: "关于 AppDimmer".local, action: #selector(aboutDialog(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "退出".local, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let menuSliderItem = NSMenuItem()
        let menuSlider = NSSlider.init(frame: NSRect(x: 10, y: 0, width: menu.size.width-20, height: 32))
        let view = NSView.init(frame: NSRect(x: 0, y: 0, width: menu.size.width, height: 32))
        view.addSubview(menuSlider)
        menuSlider.sliderType = NSSlider.SliderType.linear
        menuSlider.isEnabled = enable && (!invList.contains(fApp) || (invList.contains(fApp) && xRay))
        menuSlider.isContinuous = true
        menuSlider.action = #selector(sliderValueChanged(_:))
        menuSlider.minValue = 10
        menuSlider.maxValue = 90
        menuSlider.intValue = Int32(100-level)
        menuSliderItem.view = view
        menu.insertItem(menuSliderItem, at: 0)
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
        }else{
            startTimer()
        }
    }
    
    //获取App名称
    func getAppName(_ appUrl: URL?) -> String {
        if appUrl?.absoluteString == nil { return "" }
        return Bundle(url: appUrl!)?.name ?? ""
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
        if UIElement.isProcessTrusted() {
            unStandardWindows.removeAll()
            let apps = NSWorkspace.shared.runningApplications.filter{appList.contains(getAppName($0.bundleURL))}
            for app in apps {
                let uiApp = Application(app)
                guard let windows = try? uiApp?.windows() ?? [] else {return}
                for window in windows {
                    guard let attribs = try? window.getMultipleAttributes(.subrole, .children, .position, .size, .title) else {return}
                    let children = (attribs[.children] ?? ()) as AnyObject
                    let subrole = (attribs[.subrole] ?? "") as AnyObject
                    let size = (attribs[.size] ?? (0.0, 0.0)) as! CGSize
                    unStandardWindows.append([getAppName(app.bundleURL), children.count ?? 0, subrole as! String, size])
                }
            }
        }
    }
    
    //通过辅助功能权限获取全屏窗口
    func getFullScreen() {
        Thread.detachNewThread {
            usleep(700000)
            self.fullScreenWindows.removeAll()
            let apps = NSWorkspace.shared.runningApplications.filter{self.appList.contains(self.getAppName($0.bundleURL))}
            for app in apps {
                let uiApp = Application(app)
                guard let windows = try? uiApp?.windows() ?? [] else {return}
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
    func getBound(_ w: [String: AnyObject]) -> CGRect { return CGtoNS(CGRect(dictionaryRepresentation: w["kCGWindowBounds"] as! CFDictionary)!) }
    func getOwner(_ w: [String: AnyObject]) -> String {
        let name = w["kCGWindowOwnerName"] as! String
        if name.contains("pid=") {
            let pid = w["kCGWindowOwnerPID"] as! Int
            if let name = pids[pid] { return name }
            for app in NSWorkspace.shared.runningApplications {
                if app.processIdentifier == pid {
                    let name = getAppName(app.bundleURL)
                    pids.updateValue(name, forKey: pid)
                    return name
                }
            }
            return ""
        }
        return name
    }
    
    //批量生成遮罩窗体
    func createMask(_ appWindows: [Dictionary<String, AnyObject>], _ validAppWindows: [NSRect]){
        let frontVisibleAppName = getAppName(NSWorkspace.shared.frontmostApplication?.bundleURL)
        let maskList = windows()
        let mc = maskList.count
        let n = appWindows.count - mc
        if n<0 {
            for i in 1...abs(n) {maskList[mc-i].close()}
            maskList[0].contentView = nil
            //if appWindows.filter({ getOwner($0) == frontVisibleAppName }).count < 2 { xRay = false }
        }
        var top: Int
        if appWindows.count>0 && getBound(appWindows[0]).size.height < 40 { top = 1 } else { top = 0 }
        for (i,w) in appWindows.enumerated(){
            let bound = getBound(w)
            let owner = getOwner(w)
            let number = getNumber(w)
            var layer = getLayer(w)
            if i == 0 && !xRay && frontVisibleAppName == owner { layer += 1 }
            var mask: NSWindow!
            if i+1 > mc {
                mask = NNSWindow(contentRect: .init(origin: .zero, size: .init(width: 0, height: 0)), styleMask: .titled, backing: .buffered, defer: false)
            }else{
                mask = maskList[i]
            }
            mask.level = NSWindow.Level.init(rawValue: layer)
            mask.collectionBehavior = [.transient, .ignoresCycle]
            mask.backgroundColor = NSColor(white: 0.0, alpha: CGFloat(level)/100)
            if !invList.contains(owner) && xRay && i == top { mask.styleMask = .borderless; mask.backgroundColor = NSColor(white: 0.0, alpha: 0.0);continue }
            mask.isOpaque = false
            mask.hasShadow = false
            mask.ignoresMouseEvents = true
            mask.isReleasedWhenClosed = false
            mask.titlebarAppearsTransparent = true
            if allowShot { mask.sharingType = .readOnly } else { mask.sharingType = .none }
            if invList.contains(owner) && !(xRay && i == top && validAppWindows.contains(bound)){
                let windowImage: CGImage? = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(number), [.boundsIgnoreFraming, .bestResolution])
                if let image = windowImage {
                    mask.styleMask = .fullSizeContentView
                    mask.contentView = NSImageView(image: NSImage(cgImage: image, size: .zero))
                    if validAppWindows.contains(bound) || !xRay || i != top{
                        mask.contentView?.contentFilters = [CIFilter(name: "CILinearToSRGBToneCurve")!, CIFilter(name: "CIHueAdjust",parameters: [kCIInputAngleKey: Float(Double.pi)])!]
                        mask.contentView?.compositingFilter = CIFilter(name: "CIColorInvert")
                    }
                }
            } else {
                if isFullScreen(bound) { mask.styleMask = .borderless } else { mask.styleMask = .titled }
                if mask.contentView?.compositingFilter != nil { mask.contentView = nil }
            }
            mask.setFrame(bound, display: true)
            mask.order(.above, relativeTo: number)
            //if xRay && i == 0 { mask.contentView = nil }
            //mask.makeKeyAndOrderFront(self)
        }
    }
    
    //循环体
    @objc func loopFireHandler(_ timer: Timer?) -> Void {
        //声明窗口区域列表
        var appWindows = [[String: AnyObject]]()
        var validAppWindows = [NSRect]()
        //检测当前屏幕上所有的可见窗口
        if let windowList = CGWindowListCopyWindowInfo([.excludeDesktopElements,.optionOnScreenOnly], kCGNullWindowID) as? [[String: AnyObject]] {
            let mc: [String] = windowList.filter{ getOwner($0) == "SystemUIServer" }.map{ NSStringFromRect(getBound($0)) }
            if mc != menuBarCount { menuBarCount = mc; return }
            let visibleWindows = windowList.filter{ levelWhiteList.contains(getLayer($0)) && getAlpha($0) > 0 }
            let windowInAppList = visibleWindows.filter{ appList.contains(getOwner($0)) }
            let wc: [String] = windowInAppList.map{ return "\(NSStringFromSize(getBound($0).size)),\(getLayer($0))" }
            if (wc.count != windowsCount.count) || (Set(wc) != Set(windowsCount)) { getWindowAttribs(); getFullScreen() }
            windowsCount = wc
            for w in windowInAppList {
                //获取窗口基本信息
                let owner = getOwner(w)
                let layer = getLayer(w)
                let bound = getBound(w)
                let flag = lazyList.contains(owner) || invList.contains(owner)
                if flag { appWindows.append(w) }
                if levelBlackList.contains(layer) || bound.size.height < 50 { continue }
                let attribs = unStandardWindows.filter{ $0.first as! String == owner && $0.last as! CGSize == bound.size }
                if attribs.count != 0 {
                    if isFullScreen(bound) { appWindows.append(w); continue }
                    let childen = attribs.first?[1] as! Int
                    let subrole = attribs.first?[2] as! String
                    if (layer == 0 && subrole == "AXUnknown") {
                        let c = windowInAppList.filter{ let b = getBound($0); return getOwner($0) == owner && b != bound && NSContainsRect(b, bound) }
                        if c.count < 1 { if !flag { appWindows.append(w) } else { validAppWindows.append(bound) } }
                    } else if !subRoleBlackList.contains(subrole) && childen > 0 {
                        if !flag { appWindows.append(w) } else { validAppWindows.append(bound) }
                    }
                }else{
                    //appWindows.append(w)
                }
            }
            if xRay && xRayMode == "close" && appWindows.count > 0 { appWindows.removeFirst() }
            createMask(appWindows, validAppWindows)
        } else {
            alert("出现错误".local, "无法获取窗口列表!".local, "退出".local)
            NSApplication.shared.terminate(self)
        }
    }
}


