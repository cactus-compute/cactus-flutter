Pod::Spec.new do |s|
  s.name             = 'cactus'
  s.version          = '0.0.3'
  s.summary          = 'AI Framework to run AI on-device'
  s.description      = <<-DESC
A Flutter plugin for Cactus Utilities, providing access to native Cactus functionalities.
                       DESC
  s.homepage         = 'http://cactuscompute.com' 
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Cactus Compute' => 'founders@cactuscompute.com' } 

  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.resource_bundles = {
    'CactusBinaries' => ['cactus.xcframework.zip']
  }

  s.prepare_command = <<-CMD
    set -e
    FRAMEWORK_DIR="cactus.xcframework"
    ZIP_FILE="cactus.xcframework.zip"

    if [ ! -d "$FRAMEWORK_DIR" ]; then
      echo "$FRAMEWORK_DIR not found. Attempting to unzip $ZIP_FILE..."
      if [ -f "$ZIP_FILE" ]; then
        unzip -o "$ZIP_FILE" -d . && \
        echo "Successfully unzipped $ZIP_FILE to current directory."
      else
        echo "Error: $ZIP_FILE not found. Cannot unzip."
        exit 1
      fi
    else
      echo "$FRAMEWORK_DIR already exists. Skipping unzip."
    fi
  CMD

  s.dependency 'Flutter'
  s.platform = :ios, '11.0'
  s.swift_version = '5.0'
  s.vendored_frameworks = 'cactus.xcframework'
  s.ios.framework = 'cactus'
  s.frameworks = 'Accelerate', 'Foundation', 'Metal', 'MetalKit'

  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_ENABLE_MODULES' => 'YES', 
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }

  s.user_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'CLANG_CXX_LIBRARY' => 'libc++' 
  }

end
