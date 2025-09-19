require 'xcodeproj'

# === Configuration ===
project_path = 'Student/Student.xcodeproj'   

# === Load Project ===
project = Xcodeproj::Project.open(project_path)

# === Target names to update ===
target_names = ['Student','SubmitAssignment', 'Widgets']

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




# targets_to_delete = ['SubmitAssignment', 'Widgets']

# project = Xcodeproj::Project.open(project_path)

# targets_to_delete.each do |target_name|
#   target = project.targets.find { |t| t.name == target_name }
#   if target
#     puts "Deleting target: #{target.name}"
#     project.targets.delete(target)
#   else
#     puts "Target not found: #{target_name}"
#   end
# end

# project.save



targets_to_delete = ['SubmitAssignment', 'Widgets']

project = Xcodeproj::Project.open(project_path)

# Remove target dependencies pointing to the targets to be deleted
project.targets.each do |other_target|
  next if targets_to_delete.include?(other_target.name)

  other_target.dependencies.delete_if do |dependency|
    dependency.target && targets_to_delete.include?(dependency.target.name)
  end
end

# Delete the targets
targets_to_delete.each do |target_name|
  target = project.targets.find { |t| t.name == target_name }
  if target
    puts "Deleting target: #{target.name}"
    project.targets.delete(target)
  else
    puts "Target not found: #{target_name}"
  end
end

project.save



# Target to modify
target = project.targets.find { |t| t.name == 'Student' }
raise "Target 'Student' not found" unless target

# Items to remove
items_to_remove = ['SubmitAssignment.appex', 'Widgets.appex']

# Find the Embed App Extensions build phase
embed_phase = target.copy_files_build_phases.find do |phase|
  phase.symbol_dst_subfolder_spec == :plug_ins
end

if embed_phase
  embed_phase.files.each do |build_file|
    file_name = build_file.file_ref&.path
    if file_name && items_to_remove.include?(File.basename(file_name))
      puts "Removing #{file_name} from embedded content..."
      embed_phase.remove_build_file(build_file)
    end
  end
else
  puts "No Embed App Extensions phase found in target 'Student'"
end

# Save the project
project.save
puts "Project saved successfully."



# Target to modify
target = project.targets.find { |t| t.name == 'Student' }
raise "Target 'Student' not found" unless target

# Items to remove
items_to_remove = ['Widgets.appex']

# Find the Embed App Extensions build phase
embed_phase = target.copy_files_build_phases.find do |phase|
  phase.symbol_dst_subfolder_spec == :plug_ins
end

if embed_phase
  embed_phase.files.each do |build_file|
    file_name = build_file.file_ref&.path
    if file_name && items_to_remove.include?(File.basename(file_name))
      puts "Removing #{file_name} from embedded content..."
      embed_phase.remove_build_file(build_file)
    end
  end
else
  puts "No Embed App Extensions phase found in target 'Student'"
end

# Save the project
project.save
puts "Project saved successfully."




# === Configuration ===
project_path = 'Core/Core.xcodeproj'   

# === Load Project ===
project = Xcodeproj::Project.open(project_path)

# === Target names to update ===
target_names = ['Core']  # Adjust these names as needed

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

