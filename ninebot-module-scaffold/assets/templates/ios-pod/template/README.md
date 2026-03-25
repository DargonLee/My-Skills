# NBModuleTemplate

通用设置搜索模块模版 - 为 Ninebot App 提供设置搜索功能的基础框架。

## 功能特性

- ✅ 基础搜索 UI 框架
- ✅ 搜索结果列表展示
- ✅ 路由跳转支持
- ✅ 可扩展的数据模型

## 安装

在你的 Podfile 中添加：

```ruby
pod 'NBModuleTemplate', :path => './Modules/NBModuleTemplate'
```

然后执行：

```bash
pod install
```

## 使用方法

### 基本使用

```swift
import NBModuleTemplate

// 创建搜索页面
let searchVC = NBModuleTemplateVC()
navigationController?.pushViewController(searchVC, animated: true)
```

### 注册服务

在 App 启动时注册搜索服务：

```swift
import NBModuleTemplate

// 在 AppDelegate 或合适的地方注册
NBModuleTemplateReg.register()
```

## 目录结构

```
NBModuleTemplate/
├── .gitignore
├── NBModuleTemplate.podspec     # Pod 配置文件
├── README.md                    # 使用文档
├── LICENSE                      # MIT 许可证
│
├── Classes/                     # 代码文件
│   ├── Common/                  # 公共数据（空文件夹，按需扩展）
│   ├── Controller/
│   │   └── NBModuleTemplateVC.swift   # 搜索主页面
│   ├── Model/
│   │   └── SearchDataModels.swift  # 数据模型
│   ├── Router/
│   │   └── NBModuleTemplateRouter.swift  # 路由处理器
│   ├── Utils/                   # 工具类（空文件夹，按需扩展）
│   ├── View/
│   │   └── NBModuleTemplateCells.swift   # 搜索结果 Cell
│   └── NBModuleTemplateService.swift     # 服务入口（外部调用接口）
│
└── Resources/                   # 资源文件（可选，按需添加）
    ├── Assets/
    │   ├── feature_search_list.json       # 搜索项配置
    │   └── vehicle_features_config.json   # 功能配置
    └── Images.xcassets/
        └── (图片资源)
```

**说明：**
- `Common/` - 公共数据文件夹，可添加公共配置、工具类等
- `Router/` - 路由文件夹，包含路由处理器模版
- `Utils/` - 工具类文件夹，可添加扩展方法、helper 等
- 空文件夹包含 `.iml` 文件以保持目录结构

## 核心类说明

### NBModuleTemplateService
模块入口服务，提供：
- 页面跳转入口
- 服务可用性检查

### NBModuleTemplateVC
搜索页面主控制器（基础模版）：
- 搜索框 UI
- 搜索结果列表
- 路由跳转

**需要实现：**
1. 加载配置数据 (feature_search_list.json / vehicle_features_config.json)
2. 实现搜索逻辑（支持中文、拼音匹配）
3. 实现路由跳转

### NBModuleTemplateRouterHandler
路由处理器：
- 处理模块相关的路由跳转
- 支持 DEBUG 模式下打开路由

### NBModuleTemplateCells
搜索结果 Cell：
- 一级/二级结果显示
- 图标、标题、副标题显示

### SearchDataModels
数据模型：
- `NBModuleTemplateFeatureSearchList` - 搜索列表配置
- `NBModuleTemplateVehicleFeaturesConfig` - 功能配置字典
- `NBModuleTemplateSearchResultCell` - 搜索结果 Cell 数据
- `NBModuleTemplateSearchResultGroup` - 搜索结果分组

## 依赖模块

- `Common` - 基础公共模块
- `NBBaseUIKit` - UI 基础组件
- `NBToolsKit` - 工具集
- `NBRouter` - 路由跳转
- `NBVAppProtocol` / `NBVAppManager` - 服务管理
- `SnapKit` - 自动布局

## 版本历史

### 1.0.0 (2026-02-10)
- 初始版本
- 基础搜索 UI 框架
- 数据模型定义
- 路由处理器模版

## License

MIT License