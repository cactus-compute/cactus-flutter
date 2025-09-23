#!/bin/bash

# Setup script for iOS code signing in Cactus Flutter example
# This script helps developers configure signing to avoid common build errors

set -e

if [ ! -f "Runner.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Please run this script from the ios/ directory"
    echo "Usage: cd example/ios && ./setup_signing.sh [your-bundle-suffix]"
    exit 1
fi

if [ -z "$1" ]; then
    BUNDLE_SUFFIX=$(date +%s | tail -c 7)
else
    BUNDLE_SUFFIX="$1"
fi

BUNDLE_ID="com.cactus.example.${BUNDLE_SUFFIX}"

update_xcode_project() {
    local pbxproj_file="Runner.xcodeproj/project.pbxproj"
    local temp_file="${pbxproj_file}.tmp"
        
    sed -e 's/DEVELOPMENT_TEAM = [^;]*/CODE_SIGN_STYLE = Automatic/' \
        -e "s/com\.cactus\.example/${BUNDLE_ID}/g" \
        "${pbxproj_file}" > "${temp_file}"
    
    mv "${temp_file}" "${pbxproj_file}"
    
    echo "✅ Updated Xcode project configuration"
}

if command -v ruby >/dev/null 2>&1; then
    if ruby configure_signing.rb "${BUNDLE_SUFFIX}" 2>/dev/null; then
        exit 0
    fi
fi

update_xcode_project

echo ""
echo "✅ Basic configuration completed!"
echo "📱 Bundle ID: ${BUNDLE_ID}"
echo ""