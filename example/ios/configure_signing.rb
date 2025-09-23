#!/usr/bin/env ruby

# This script configures iOS code signing for the Cactus Flutter example app.
# It sets up automatic signing with a unique bundle identifier to avoid conflicts.

require 'xcodeproj'

def configure_signing(project_path, bundle_id_suffix = nil)
  begin
    project = Xcodeproj::Project.open(project_path)
    
    if bundle_id_suffix.nil?
      bundle_id_suffix = Time.now.to_i.to_s[-6..-1]
    end
    
    bundle_id = "com.cactus.example.#{bundle_id_suffix}"
    
    project.targets.each do |target|
      next if target.name == 'RunnerTests'
            
      target.build_configurations.each do |config|
        config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
        config.build_settings.delete('DEVELOPMENT_TEAM')
        config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
        config.build_settings['CODE_SIGN_IDENTITY[sdk=iphoneos*]'] = 'iPhone Developer'
        config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ''
      end
    end
    
    project.save
    
  rescue StandardError => e
    exit 1
  end
end

begin
  require 'xcodeproj'
rescue LoadError
  exit 1
end

project_path = File.join(__dir__, 'Runner.xcodeproj')

unless File.exist?(project_path)
  exit 1
end

bundle_suffix = ARGV[0]

configure_signing(project_path, bundle_suffix)