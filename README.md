# 
<p align="center">
<img src="./img/AppDimmer.png" width="200" height="200" />
<h1 align="center">AppDimmer</h1>
<h3 align="center">一款用于 macOS 的软件窗口亮度控制工具</h3> 
</p>

## 运行截图
<p align="center">
<img src="./img/Screenshot.png" width="1136"/>  
</p>

## 安装与使用
### 安装:
可[点此下载](https://github.com/lihaoyun6/AppDimmer/releases/latest)最新版安装文件. 或使用homebrew安装:  
```bash
brew install lihaoyun6/tap/appdimmer
```
### 使用:
AppDimmer启动后会在菜单栏显示图标, 点击图标并拖动滑块可对遮罩强度进行调整.  
您可以通过右键单击AppDimmer的菜单栏图标来关闭或启用AppDimmer.  
也可以左键点击菜单栏图标再点击应用名来对某个App设置启用或停用亮度控制.  

## 常见问题
**1. 为什么AppDimmer启动后没有任何窗口?**  
> AppDimmer除了菜单栏图标外, 仅会在您指定的App运行时生成遮罩. 除此之外没有其他额外的窗口.  

**2. 感觉默认的遮罩强度太黑或不够黑怎么办?**
> 可以点击AppDimmer的菜单栏图标, 并拖动滑块以调节遮罩强度至您认为合适的比例.  

**3. 使用的过程中可以移动App窗口吗, 支持多个App同时运行吗?**  
> 可以. 使用过程中AppDimmer会动态检测所有指定App窗口位置和尺寸, 并为每个App的每个窗口实时生成遮罩.  

**4. 支持在多台显示器间移动窗口吗?**  
> 支持. 使用过程中可以任意移动程序窗口到任何一台显示器上. 遮罩会自动跟踪. 

## 致谢
[AXSwift](https://github.com/tmandry/AXSwift) @tmandry  

## 赞助
<img src="./img/donate.png" width="352"/>
