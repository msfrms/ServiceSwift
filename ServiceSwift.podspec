Pod::Spec.new do |s|
  s.name             = "ServiceSwift"
  s.version          = "0.1"
  s.summary          = "Simple work with Services"
  s.homepage         = "https://github.com/msfrms/ServiceSwift"
  s.license          = 'Apache License 2.0'
  s.author           = { "msfrms" => "msfrms@gmail.com" }

  s.platform         = :ios, '8.0'
  s.requires_arc     = true
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '4.0' }

  s.source           = { :git => 'https://github.com/msfrms/ServiceSwift.git', :tag => s.version }
  s.source_files	 = 'Source/*.swift'

  s.frameworks       = 'Foundation'
  s.module_name      = 'ServiceSwift'
  s.dependency 'ConcurrentSwift', '~> 0.1'	

end