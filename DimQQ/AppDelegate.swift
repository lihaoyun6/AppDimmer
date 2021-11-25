//
//  AppDelegate.swift
//  DimQQ
//
//  Created by apple on 2021/11/22.
//

import Cocoa
import ServiceManagement

//为NSWindow新建子类
class NNSWindow : NSWindow {
    //重写constrainFrameRect以支持从可见区域外绘制窗口
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var window: NSWindow!
    
    var timer: Timer?
    var lastNormalBound : NSRect?
    var menuSlider = NSSlider()
    var cold = true
    var text2 = "QQ"
    var level = UserDefaults.standard.integer(forKey: "level")
    var disable = UserDefaults.standard.bool(forKey: "disable")
    var darkOnly = UserDefaults.standard.bool(forKey: "darkOnly")
    var channel = UserDefaults.standard.bool(forKey: "channel")
    var statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
    
    let menu = NSMenu()
    var foundHelper = false
    let helperBundleName = "com.lihaoyun6.DimQQLoginHelper"
    let maskWindow = NNSWindow(contentRect: .init(origin: .zero, size: .init(width: NSScreen.main!.frame.midX, height: NSScreen.main!.frame.midY)),
                             styleMask: [.titled],
                             backing: .buffered,
                             defer: false)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        //获取自启代理状态
        foundHelper = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == helperBundleName }
        
        //如果亮度级别不存在, 则预设为50
        if level == 0{
            level = 50
            UserDefaults.standard.set(level, forKey: "level")
        }
        
        //初始化定时器
        timer = Timer(timeInterval: 0.05, repeats: true, block: {timer in self.loopFireHandler(timer)})
        RunLoop.main.add(timer!, forMode: .common)
        
        //生成主菜单
        mainMenu()
        
        //初始化叠层属性(部分)
        maskWindow.isOpaque = false
        maskWindow.ignoresMouseEvents = true
        maskWindow.titlebarAppearsTransparent = true
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
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
            break
        case .leftMouseUp, .rightMouseUp:
            maskWindow.title = ""
            UserDefaults.standard.set(level, forKey: "level")
        case .leftMouseDragged, .rightMouseDragged:
            level = Int(100-slider.intValue)
            maskWindow.title = "\(slider.intValue)%"
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
    
    //设置"启用 DimQQ"
    @objc func setDisable(_ sender: NSMenuItem) {
        disable.toggle()
        menuSlider.isEnabled = !disable
        menu.item(withTitle: sender.title)?.state = state(!disable)
        UserDefaults.standard.set(disable, forKey: "disable")
        lastNormalBound = NSZeroRect
    }
    
    //设置"仅在深色模式生效"
    @objc func setDarkOnly(_ sender: NSMenuItem) {
        darkOnly.toggle()
        menu.item(withTitle: sender.title)?.state = state(darkOnly)
        UserDefaults.standard.set(darkOnly, forKey: "darkOnly")
        lastNormalBound = NSZeroRect
    }
    
    //设置"作用于频道(实验性)"
    @objc func setChannel(_ sender: NSMenuItem) {
        channel.toggle()
        menu.item(withTitle: sender.title)?.state = state(channel)
        if channel { text2 = local("QQ频道") } else { text2 = "QQ" }
        UserDefaults.standard.set(channel, forKey: "channel")
        lastNormalBound = NSZeroRect
    }
    
    //设置"登录时启动"
    @objc func setRunAtLogin(_ sender: NSMenuItem) {
        foundHelper.toggle()
        SMLoginItemSetEnabled(helperBundleName as CFString, foundHelper)
        menu.item(withTitle: sender.title)?.state = state(foundHelper)
    }
    
    //主菜单生成函数
    func mainMenu(){
        //初始化菜单栏按钮
        if let button = statusItem.button {
            button.image = NSImage(named:NSImage.Name("MenuBarIcon"))
        }
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: local("启用 DimQQ"), action: #selector(setDisable(_:)), keyEquivalent: "").state = state(!disable)
        menu.addItem(withTitle: local("登录时启动"), action: #selector(setRunAtLogin(_:)), keyEquivalent: "").state = state(foundHelper)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: local("仅在深色模式生效"), action: #selector(setDarkOnly(_:)), keyEquivalent: "").state = state(darkOnly)
        menu.addItem(withTitle: local("包含QQ频道(实验性)"), action: #selector(setChannel(_:)), keyEquivalent: "").state = state(channel)
        if channel { text2 = local("QQ频道") }
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: local("赞助一瓶快乐水"), action: #selector(aboutDialog(_:)), keyEquivalent: "")
        menu.addItem(withTitle: local("关于 DimQQ"), action: #selector(aboutDialog(_:)), keyEquivalent: "")
        menu.addItem(withTitle: local("退出"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
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
    
    //覆盖区域计算函数, 用于计算能够覆盖所有QQ窗口的最小区域范围
    func getMaxBound(_ bounds: [NSRect]) -> NSRect{
        let x = bounds.map{ $0.origin.x }.min()!
        let y = bounds.map{ $0.origin.y }.min()!
        let w = bounds.map{ $0.size.width + $0.origin.x }.max()! - x
        let h = bounds.map{ $0.size.height + $0.origin.y }.max()! - y
        return NSRect(x: x, y: y, width: w, height: h)
    }
    
    //CGRect坐标系转为NSRect
    func CGtoNS(_ bound: CGRect) ->NSRect{
        let newY = NSScreen.screens[0].frame.height - bound.size.height - bound.origin.y
        let frame = NSRect(x: bound.origin.x, y: newY, width: bound.size.width, height: bound.size.height)
        return frame
    }
    
    //隐藏窗口
    func hideMask(){
        maskWindow.orderOut(self)
        lastNormalBound = NSZeroRect
    }
    
    //本地化字符串
    func local(_ string: String) -> String{
        NSLocalizedString(string, comment: "")
    }
    
    //窗口生成及动态跟踪函数
    @objc func loopFireHandler(_ timer: Timer?) -> Void {
        //检测启动条件
        if isDarkMode() && !disable && level != 1 {
            //声明QQ窗口区域列表
            var QQBounds = [NSRect]()
            //检测当前屏幕上所有的可见窗口
            if let windowList = CGWindowListCopyWindowInfo([.excludeDesktopElements,.optionOnScreenOnly], kCGNullWindowID) as? [[String: AnyObject]] {
                let visibleWindows = windowList.filter{ $0["kCGWindowLayer"] as! Int == 0 }
                for window in visibleWindows {
                    //获取窗口所属App名称
                    let owner = window[kCGWindowOwnerName as String] as! String
                    //获取所需的窗口区域信息
                    if owner == "QQ"||owner == text2 {
                        let bound = CGRect(dictionaryRepresentation: window[kCGWindowBounds as String] as! CFDictionary)!
                        if bound.size.width >= 240.0 && bound.size.height >= 300.0 { QQBounds.append(CGtoNS(bound)) }
                    }
                }
                
                //获取QQ窗口之上的所有窗口
                /*var frontBounds = [NSRect]()
                for window in visibleWindows {
                    let owner = window[kCGWindowOwnerName as String] as! String
                    let bound = CGRect(dictionaryRepresentation: window[kCGWindowBounds as String] as! CFDictionary)!
                    if owner == "QQ"||owner == "QQ频道"{
                        break
                    }
                    frontBounds.append(CGtoNS(bound))
                }*/
                
                //设置叠层透明度
                maskWindow.backgroundColor = NSColor(white: 0.0, alpha: CGFloat(level)/100)
                //获取最顶层可见窗口所属的App名称
                if let frontVisibleApp = visibleWindows.first{
                    let frontVisibleAppName = frontVisibleApp[kCGWindowOwnerName as String] as! String
                    //let frontAppID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                    //如果是QQ(或频道)
                    if frontVisibleAppName == "QQ" || frontVisibleAppName == text2{
                        //如果窗口数量不为0(防止窗口都关了, 但是App保持运行的情况)
                        if QQBounds.count != 0 {
                            //获取需要绘制的区域
                            let bound = getMaxBound(QQBounds)
                            //设置窗口属性
                            maskWindow.styleMask = .titled
                            maskWindow.level = NSWindow.Level.floating
                            for screen in NSScreen.screens {
                                if NSEqualRects(screen.frame,bound) { maskWindow.styleMask = .borderless }
                            }
                            maskWindow.setFrame(bound, display: true)
                            maskWindow.makeKeyAndOrderFront(self)
                            //记录当前窗口区域信息, 以供下次对比
                            lastNormalBound = NSZeroRect
                            //修改冷启动标志
                            if cold {cold.toggle()}
                        }else{
                            //如果窗口数量为0, 则不显示叠层
                            hideMask()
                        }
                    }else{
                        //如果顶层窗口不是QQ(或频道), 且不是冷启动
                        if QQBounds.count != 0 && !cold {
                            //计算可视范围内的有效绘制区域信息
                            //let bound = NSIntersectionRect(NSScreen.main!.visibleFrame,getMaxBound(QQBounds))
                            let bound = getMaxBound(QQBounds)
                            //检测窗口移动或缩放过才修改叠层属性, 防止闪烁
                            if bound != lastNormalBound!{
                                maskWindow.setFrame(bound, display: true)
                                maskWindow.level = NSWindow.Level.normal
                                maskWindow.orderOut(self)
                                maskWindow.makeKeyAndOrderFront(self)
                                lastNormalBound = bound
                            }
                        }else{
                            //如果窗口数量为0, 则不显示叠层
                            hideMask()
                        }
                    }
                }else{
                    hideMask()
                }
            } else {
                alert(local("出现错误"), local("无法获取窗口列表!"), local("退出"))
                NSApplication.shared.terminate(self)
            }
        }else{
            hideMask()
        }
    }
}

