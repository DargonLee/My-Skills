#
# NBModuleTemplate.podspec
# 通用设置搜索模块模版
#

Pod::Spec.new do |s|
  s.name             = 'NBModuleTemplate'
  s.version          = '1.0.0'
  s.summary          = 'NBModuleTemplate module - A reusable settings search module template'
  s.description      = <<-DESC
  通用设置搜索模块模版，提供设置搜索基础框架。
  可作为独立模块被其他项目集成使用，需要根据具体需求实现搜索逻辑。
                       DESC
  s.homepage         = 'https://git.ninebot.com/iOS/ninebot_6'
  s.license          = 'MIT'
  s.author           = 'Ninebot'
  s.source           = { :path => '.' }
  s.ios.deployment_target = '11.0'
  s.swift_versions = '5.0'

  s.pod_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
  }

  # 源文件
  s.default_subspec = 'Classes'
  s.subspec 'Classes' do |sp|
    sp.source_files = 'Classes/**/*.{swift,h,m}'
    sp.exclude_files = 'Classes/**/.DS_Store'
  end

  # 依赖项
  s.dependency 'Common'                 # 公共基础模块
  s.dependency 'NBBaseUIKit'           # 基础 UI 组件
  s.dependency 'NBToolsKit'            # 工具集
  s.dependency 'NBRouter'              # 路由模块
  s.dependency 'NBVAppProtocol'        # 服务协议
  s.dependency 'NBVAppManager'         # 服务管理
  s.dependency 'SnapKit'               # 布局库

end
