require 'xcodeproj'

# === Configuration ===
project_path = 'Student/Student.xcodeproj'   

# === Load Project ===
project = Xcodeproj::Project.open(project_path)

# === Target names to update ===
target_names = ['SubmitAssignment', 'Widgets']

# === Process each target ===
target_names.each do |target_name|
  target = project.targets.find { |t| t.name == target_name }

  if target.nil?
    puts "❌ Target '#{target_name}' not found in project."
    next
  end

  # Disable automatic signing
  target.build_configurations.each do |config|
    config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
  end

  puts "✅ 'Automatically manage signing' disabled for target '#{target_name}'"
end

# Save the project once after all changes
project.save
