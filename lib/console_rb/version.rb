# frozen_string_literal: true

module ConsoleRb
  # Version namespace for this gem.
  module Version
    # Current gem version.
    VERSION = '0.1.0'
  end
  # Current gem version exposed at the traditional constant location.
  VERSION = Version::VERSION # Traditional Constant Location

  # The application id and GSettings schema deliberately differ from upstream
  # GNOME Console so this port can be installed side by side without the two
  # fighting over the same dconf keys.
  APPLICATION_ID = 'org.gnome.Console.Rb'
  APPLICATION_PATH = '/org/gnome/Console/Rb/'
  HOMEPAGE_URL = 'https://github.com/ruby-gtk-project/console-rb'
end
