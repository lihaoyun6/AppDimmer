//
//  AppDelegate.swift
//  DimQQ
//
//  Created by apple on 2021/11/22.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var window: NSWindow!
    
    var timer: Timer?
    var lastNormalBound : NSRect?
    var lastFloatingBound : NSRect?
    var menuSlider = NSSlider()
    var cold = true
    var text2 = "QQ"
    var level = UserDefaults.standard.integer(forKey: "level")
    var disable = UserDefaults.standard.bool(forKey: "disable")
    var darkOnly = UserDefaults.standard.bool(forKey: "darkOnly")
    var channel = UserDefaults.standard.bool(forKey: "channel")
    var statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
    
    let menu = NSMenu()
    let newWindow = NSWindow(contentRect: .init(origin: .zero, size: .init(width: NSScreen.main!.frame.midX, height: NSScreen.main!.frame.midY)),
                             styleMask: [.titled],
                             backing: .buffered,
                             defer: false)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
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
        newWindow.isOpaque = false
        newWindow.ignoresMouseEvents = true
        newWindow.titlebarAppearsTransparent = true
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
            newWindow.title = ""
            UserDefaults.standard.set(level, forKey: "level")
        case .leftMouseDragged, .rightMouseDragged:
            level = Int(100-slider.intValue)
            newWindow.title = "亮度: \(slider.intValue)%"
        default:
            break
        }
    }
    
    //设置"启用 DimQQ"
    @objc func setDisable(_ sender: NSMenuItem) {
        disable.toggle()
        menuSlider.isEnabled = !disable
        menu.item(withTitle: sender.title)?.state = state(!disable)
        UserDefaults.standard.set(disable, forKey: "disable")
        cleanBounds()
    }
    
    //设置"仅在深色模式生效"
    @objc func setDarkOnly(_ sender: NSMenuItem) {
        darkOnly.toggle()
        menu.item(withTitle: sender.title)?.state = state(darkOnly)
        UserDefaults.standard.set(darkOnly, forKey: "darkOnly")
        cleanBounds()
    }
    
    //设置"作用于频道(实验性)"
    @objc func setChannel(_ sender: NSMenuItem) {
        channel.toggle()
        menu.item(withTitle: sender.title)?.state = state(channel)
        if channel { text2 = "QQ频道" } else { text2 = "QQ" }
        UserDefaults.standard.set(channel, forKey: "channel")
        cleanBounds()
    }
    
    //主菜单生成函数
    func mainMenu(){
        //初始化菜单栏按钮
        if let button = statusItem.button {
            button.image = NSImage(named:NSImage.Name("MenuBarIcon"))
        }
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "启用 DimQQ", action: #selector(setDisable(_:)), keyEquivalent: "").state = state(!disable)
        menu.addItem(withTitle: "仅在深色模式生效", action: #selector(setDarkOnly(_:)), keyEquivalent: "").state = state(darkOnly)
        menu.addItem(withTitle: "作用于频道(实验性)", action: #selector(setChannel(_:)), keyEquivalent: "").state = state(channel)
        if channel { text2 = "QQ频道" }
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "关于 DimQQ", action: #selector(aboutDialog(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
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
    
    //清除绘制区域信息记录
    func cleanBounds(){
        if lastNormalBound != NSZeroRect || lastFloatingBound != NSZeroRect{
            lastNormalBound = NSZeroRect
            lastFloatingBound = NSZeroRect
        }
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
                        if bound.size.width >= 300.0 && bound.size.height >= 300.0 { QQBounds.append(CGtoNS(bound)) }
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
                newWindow.backgroundColor = NSColor(white: 0.0, alpha: CGFloat(level)/100)
                //获取最顶层可见窗口所属的App名称
                let frontApp = visibleWindows.first!
                let frontAppName = frontApp[kCGWindowOwnerName as String] as! String
                //如果是QQ(或频道)
                if frontAppName == "QQ" || frontAppName == text2{
                    //如果窗口数量不为0(防止窗口都关了, 但是App保持运行的情况)
                    if QQBounds.count != 0 {
                        //获取需要绘制的区域
                        let bound = getMaxBound(QQBounds)
                        //检测窗口移动或缩放过才修改叠层属性, 节省开销
                        if bound != lastFloatingBound{
                            newWindow.level = NSWindow.Level.floating
                            newWindow.setFrame(bound, display: true)
                            newWindow.makeKeyAndOrderFront(self)
                            //记录当前窗口区域信息, 以供下次对比
                            lastFloatingBound = bound
                            lastNormalBound = NSZeroRect
                        }
                        //修改冷启动标志
                        if cold {cold.toggle()}
                    }else{
                        //如果窗口数量为0, 则不显示叠层
                        newWindow.orderOut(self)
                        cleanBounds()
                    }
                }else{
                    //如果顶层窗口不是QQ(或频道), 且不是冷启动
                    if QQBounds.count != 0 && !cold {
                        //计算可视范围内的有效绘制区域信息
                        let bound = NSIntersectionRect(NSScreen.main!.visibleFrame,getMaxBound(QQBounds))
                            if bound != lastNormalBound!{
                                newWindow.setFrame(bound, display: true)
                                newWindow.level = NSWindow.Level.normal
                                newWindow.orderOut(self)
                                newWindow.makeKeyAndOrderFront(self)
                                lastNormalBound = bound
                                lastFloatingBound = NSZeroRect
                            }
                    }else{
                        //如果窗口数量为0, 则不显示叠层
                        newWindow.orderOut(self)
                        cleanBounds()
                    }
                }
            } else {
                print("Can't get window list")
            }
        }else{
            newWindow.orderOut(self)
            cleanBounds()
        }
    }
}

