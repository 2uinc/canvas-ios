#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Canvas.xcworkspace/../Student/Student.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Set signing settings only for the main app target
project.targets.each do |target|
  if target.name == 'Student'
    # Main app target - manual signing
    target.build_configurations.each do |config|
      config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
      config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ENV['PROFILE_UUID']
      config.build_settings['DEVELOPMENT_TEAM'] = '58GH9WB284'
      config.build_settings['CODE_SIGN_IDENTITY'] = 'Apple Distribution: 2U, Inc. (58GH9WB284)'
    end
  else
    # All other targets (SPM packages, frameworks) - automatic signing
    target.build_configurations.each do |config|
      config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
      config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ''
      config.build_settings['DEVELOPMENT_TEAM'] = ''
      config.build_settings['CODE_SIGN_IDENTITY'] = ''
    end
  end
end

project.save