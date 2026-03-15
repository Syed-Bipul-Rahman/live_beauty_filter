Pod::Spec.new do |s|
  s.name             = 'live_beauty_filter'
  s.version          = '0.0.1'
  s.summary          = 'Real-time milky beauty filter for iOS live camera, GPU-only via CoreImage + Metal.'
  s.description      = <<-DESC
A Flutter plugin for iOS that applies a real-time milky/soft beauty filter to the live
camera feed, entirely on the GPU. Built on AVFoundation + CoreImage + Metal.
Zero CPU pixel processing — no frame drops, no battery drain.
Filter chain: Gaussian blur → Bloom/Glow → Color grade (brightness + contrast lift).
Adjustable intensity at runtime via a simple Dart API.
                       DESC
  s.homepage         = 'https://github.com/Syed-Bipul-Rahman/live_beauty_filter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Syed Bipul Rahman' => 'info@syedbipul.me' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency       'Flutter'
  s.platform         = :ios, '14.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE'                   => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.7'

  s.resource_bundles = {
    'live_beauty_filter_privacy' => ['Resources/PrivacyInfo.xcprivacy']
  }
end