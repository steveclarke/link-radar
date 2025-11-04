namespace :search do
  desc "Rebuild search_projection for all searchable models"
  task rebuild_all: :environment do
    # Find all rebuild tasks in the search namespace
    rebuild_tasks = Rake::Task.tasks.select do |task|
      task.name.start_with?("search:rebuild_") && task.name != "search:rebuild_all"
    end

    if rebuild_tasks.empty?
      puts "No rebuild tasks found in search namespace"
      return
    end

    puts "Found #{rebuild_tasks.length} rebuild task(s):"
    rebuild_tasks.each { |task| puts "  - #{task.name}" }
    puts

    rebuild_tasks.each do |task|
      puts "Running #{task.name}..."
      task.invoke
      puts "✓ Completed #{task.name}"
      puts
    end

    puts "All search projections rebuilt successfully!"
  end
end
