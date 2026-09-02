# frozen_string_literal: true

desc 'Run the test suite (needs a display; uses Xvfb when one is not available)'
task :test do
  %w[test/integration_test.rb test/actions_test.rb].each do |script|
    puts "\n== #{script}"
    sh({ 'GSETTINGS_SCHEMA_DIR' => File.expand_path('data/schemas', __dir__),
         'CONSOLE_RB_LOCALE_DIR' => File.expand_path('data/locale', __dir__) },
       'ruby', script)
  end
end

desc 'Compile po/*.po into data/locale for gettext'
task :locale do
  require 'fileutils'
  require 'gettext/tools'

  # rmsgfmt rather than GNU msgfmt: for ar and fa, msgfmt emits MO format
  # revision 1.1, which the gettext gem's reader rejects outright. The gem's
  # own compiler always writes revision 0.
  languages.each do |lang|
    "data/locale/#{lang}/LC_MESSAGES".tap do |dir|
      FileUtils.mkdir_p(dir)
      GetText::Tools::MsgFmt.run("po/#{lang}.po", '-o', "#{dir}/console-rb.mo")
    end
  end
end

def languages
  File.readlines('po/LINGUAS')
      .map(&:strip)
      .reject { |line| line.empty? || line.start_with?('#') }
      .select { |lang| File.exist?("po/#{lang}.po") }
end

desc 'Compile the GSettings schema'
task :schema do
  sh 'glib-compile-schemas', 'data/schemas'
end

desc 'Lint'
task :lint do
  sh 'rubocop'
end

task default: %i[schema locale test lint]
