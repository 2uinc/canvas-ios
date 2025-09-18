# require 'xcodeproj'

# # === Configuration ===
# project_path = 'Student/Student.xcodeproj'   

# # === Load Project ===
# project = Xcodeproj::Project.open(project_path)

# # === Target names to update ===
# target_names = ['SubmitAssignment', 'Widgets']

# # === Process each target ===
# target_names.each do |target_name|
#   target = project.targets.find { |t| t.name == target_name }

#   if target.nil?
#     puts "❌ Target '#{target_name}' not found in project."
#     next
#   end

#   # Disable automatic signing
#   target.build_configurations.each do |config|
#     config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
#   end

#   puts "✅ 'Automatically manage signing' disabled for target '#{target_name}'"
# end

# # Save the project once after all changes
# project.save



require 'xcodeproj'
require 'pathname'

# === CONFIGURATION ===
project_path = 'Student/Student.xcodeproj'
main_target_name = 'Student'  # Change if your main target has a different name
extensions_to_remove = ['SubmitAssignment', 'Widgets']  # No file extensions here

# === OPEN PROJECT ===
project = Xcodeproj::Project.open(project_path)

# === FIND MAIN TARGET ===
main_target = project.targets.find { |t| t.name == main_target_name }

unless main_target
  puts "❌ Main target '#{main_target_name}' not found."
  exit 1
end

puts "📦 Found main target: #{main_target.name}"
puts "🎯 Extensions to remove: #{extensions_to_remove.join(', ')}"

# === HELPER METHOD ===
def matches_extension?(file_name, targets_to_remove)
  base = File.basename(file_name, File.extname(file_name))
  targets_to_remove.include?(base)
end

# === DEBUG: LIST FILES BEFORE REMOVAL ===
puts "\n📁 Files in 'Frameworks' phase:"
main_target.frameworks_build_phases.files.each do |file|
  puts " - #{file.display_name}"
end

puts "\n📁 Files in 'Embed Frameworks' (Copy Files) phases:"
main_target.copy_files_build_phases.each_with_index do |phase, i|
  phase.files.each do |file|
    puts " - #{file.display_name}"
  end
end

# === REMOVE FROM FRAMEWORKS PHASE ===
main_target.frameworks_build_phases.files.each do |file|
  if matches_extension?(file.display_name, extensions_to_remove)
    puts "🗑️ Removing #{file.display_name} from Frameworks"
    file.remove_from_project
  end
end

# === REMOVE FROM EMBED FRAMEWORKS (COPY FILES) PHASES ===
main_target.copy_files_build_phases.each do |phase|
  phase.files.each do |file|
    if matches_extension?(file.display_name, extensions_to_remove)
      puts "🗑️ Removing #{file.display_name} from Embedded Content"
      file.remove_from_project
    end
  end
end

# === SAVE PROJECT ===
project.save
puts "\n✅ Done. Removed specified extensions from linking and embedding."


