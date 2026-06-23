Pod::Spec.new do |s|
  s.name             = 'NBSystemDevice'
  s.version          = '1.0.0'
  s.summary          = 'NBSystemDevice module'
  s.description      = <<-DESC
  NBSystemDevice module provides system device VApp APIs.
                       DESC
  s.homepage         = 'https://git.ninebot.com/iOS/ninebot_6'
  s.license          = 'MIT'
  s.author           = 'MIT'
  s.source           = { :path => '.' }
  s.ios.deployment_target = '11.0'
  s.swift_versions = '5.0'
  s.source_files = 'Classes/**/*.{swift,h,m}'
  s.frameworks = 'UIKit'
  s.dependency 'NBVAppProtocol'
  s.dependency 'NBVAppManager'
end
