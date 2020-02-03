require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "react-native-video-transcoder"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.description  = "react-native-video-transcoder - a video transcoder for react-native"
  s.homepage     = "https://github.com/julianodossantos/react-native-video-transcoder"
  s.license      = "MIT"
  s.authors      = { "Juliano Soares dos Santos" => "julianodossantos@gmail.com" }
  s.platforms    = { :ios => "9.0" }
  s.source       = { :git => "https://github.com/julianodossantos/react-native-video-transcoder.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,swift}"
  s.requires_arc = true

  s.dependency "React"
  # ...
  # s.dependency "..."
end

