#!/bin/bash

PUBLISH=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --publish)
            PUBLISH=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--publish]"
            exit 1
            ;;
    esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Creating Flutter example platform folders..."
cd example
flutter create --platforms=ios,android .

echo "Setting iOS minimum version to 13.0..."
if [ -f "ios/Podfile" ]; then
    sed -i '' "s/# platform :ios, '12.0'/platform :ios, '13.0'/" ios/Podfile
    echo "Updated Podfile to use iOS 13.0"
else
    echo "Warning: ios/Podfile not found"
fi

if [ -f "ios/Runner.xcodeproj/project.pbxproj" ]; then
    sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*;/IPHONEOS_DEPLOYMENT_TARGET = 13.0;/g' ios/Runner.xcodeproj/project.pbxproj
    echo "Updated Xcode project iOS deployment target to 13.0"
else
    echo "Warning: Xcode project file not found"
fi

cd ..

JNI_LIBS_SOURCE_DIR="android/src/main/jniLibs"
JNI_LIBS_ZIP_TARGET="android/jniLibs.zip"
XCFRAMEWORK_SOURCE_DIR="ios/cactus.xcframework" 
XCFRAMEWORK_ZIP_TARGET="ios/cactus.xcframework.zip"

if [ ! -f "$JNI_LIBS_ZIP_TARGET" ] || [ ! -f "$XCFRAMEWORK_ZIP_TARGET" ]; then
    echo "Native library zips not found, building from source..."
    
    echo "Pulling from Cactus core repo..."
    rm -rf cactus_temp
    git clone --depth 1 -b legacy https://github.com/cactus-compute/cactus.git cactus_temp || {
        echo "Error: Failed to clone cactus repository (legacy branch)"
        exit 1
    }
    
    if [ ! -d "cactus_temp" ]; then
        echo "Error: Clone directory not created"
        exit 1
    fi
    
    cd cactus_temp
    
    echo "Building Android JNILibs..."
    if [ -f "scripts/build-android.sh" ]; then
        chmod +x scripts/build-android.sh
        if ./scripts/build-android.sh; then
            echo "Android build succeeded, copying JNILibs..."
            if [ -d "./android/src/main/jniLibs" ]; then
                cp -R ./android/src/main/jniLibs "$ROOT_DIR/android/src/main/"
            else
                echo "Warning: JNILibs directory not found after build"
            fi
        else
            echo "Error: Android build failed!"
            exit 1
        fi
    else
        echo "Error: build-android.sh script not found!"
        exit 1
    fi
    
    echo "Copying iOS frameworks..."
    if [ -d "./ios/cactus.xcframework" ]; then
        cp -R ./ios/cactus.xcframework "$ROOT_DIR/ios/"
    else
        echo "Warning: iOS xcframework not found"
    fi
    
    echo "Cleaning up temporary clone..."
    cd "$ROOT_DIR"
    rm -rf cactus_temp
else
    echo "Native library zips already exist, skipping build from source..."
fi

echo "Zipping JNILibs and XCFramework..."

if [ -d "$ROOT_DIR/$JNI_LIBS_SOURCE_DIR" ]; then
  echo "Zipping JNILibs from $ROOT_DIR/$JNI_LIBS_SOURCE_DIR..."
  (cd "$ROOT_DIR/$JNI_LIBS_SOURCE_DIR" && zip -r "$ROOT_DIR/$JNI_LIBS_ZIP_TARGET" . )
  if [ $? -eq 0 ]; then
    echo "JNILibs successfully zipped to $JNI_LIBS_ZIP_TARGET"
  else
    echo "Error: Failed to zip JNILibs."
  fi
elif [ -f "$JNI_LIBS_ZIP_TARGET" ]; then
  echo "Warning: JNILibs source directory $ROOT_DIR/$JNI_LIBS_SOURCE_DIR not found, but $JNI_LIBS_ZIP_TARGET already exists. Skipping zip."
else
  echo "Error: JNILibs source directory $ROOT_DIR/$JNI_LIBS_SOURCE_DIR not found. Cannot zip."
fi

if [ -d "$XCFRAMEWORK_SOURCE_DIR" ]; then
  echo "Zipping XCFramework from $XCFRAMEWORK_SOURCE_DIR..."
  (cd "ios" && zip -r "cactus.xcframework.zip" "cactus.xcframework")
  if [ $? -eq 0 ]; then
    echo "XCFramework successfully zipped to $XCFRAMEWORK_ZIP_TARGET"
  else
    echo "Error: Failed to zip XCFramework."
  fi
elif [ -f "$XCFRAMEWORK_ZIP_TARGET" ]; then
  echo "Warning: XCFramework source directory $XCFRAMEWORK_SOURCE_DIR not found, but $XCFRAMEWORK_ZIP_TARGET already exists. Skipping zip."
else
  echo "Error: XCFramework source directory $XCFRAMEWORK_SOURCE_DIR not found. Cannot zip."
fi

echo "Building Cactus Flutter Plugin..."
flutter clean
flutter pub get
dart analyze
echo "Build completed successfully."

if [ "$PUBLISH" = true ]; then
    echo "Publishing to pub.dev..."
    rm -rf "$ROOT_DIR/android/jniLibs.zip"
    rm -rf "$ROOT_DIR/android/src/main/jniLibs/x86_64" 
    flutter pub publish
else
    echo "Build complete. Use --publish flag to publish to pub.dev"
fi 