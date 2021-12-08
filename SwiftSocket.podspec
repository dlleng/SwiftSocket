#
# Be sure to run `pod lib lint SwiftSocket.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SwiftSocket'
  s.version          = '1.1.0'
  s.summary          = 'A simple and powerful tcp socket library.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/dlleng/SwiftSocket'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'dlleng' => '2190931560@qq.com' }
  s.source           = { :git => 'https://github.com/dlleng/SwiftSocket.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '9.0'
  s.requires_arc = true
  s.swift_versions = ['4.0', '4.2', '5.0']
  s.default_subspec = 'core'

  #s.source_files = 'SwiftSocket/Classes/core/*.swift'
  
  # s.resource_bundles = {
  #   'SwiftSocket' => ['SwiftSocket/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'

  s.subspec 'core' do |ss|
    ss.source_files = 'SwiftSocket/Classes/core/**/*'
  end
  
  s.subspec 'extension' do |ss|
    ss.source_files = 'SwiftSocket/Classes/extension/**/*'
  end

end
