# frozen_string_literal: true

desc 'Run the test suite (needs a display; uses Xvfb when one is not available)'
task :test do
  %w[test/integration_test.rb test/actions_test.rb].each do |script|
    puts "\n== #{script}"
    sh({ 'GSETTINGS_SCHEMA_DIR' => File.expand_path('data/schemas', __dir__) },
       'ruby', script)
  end
end

desc 'Compile the GSettings schema'
task :schema do
  sh 'glib-compile-schemas', 'data/schemas'
end

desc 'Lint'
task :lint do
  sh 'rubocop'
end

task default: %i[schema test lint]
