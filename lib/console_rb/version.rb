# frozen_string_literal: true

module ConsoleRb
  VERSION = '0.1.0'

  # The application id and GSettings schema deliberately differ from upstream
  # GNOME Console so this port can be installed side by side without the two
  # fighting over the same dconf keys.
  APPLICATION_ID = 'org.gnome.Console.Rb'
  APPLICATION_PATH = '/org/gnome/Console/Rb/'
  HOMEPAGE_URL = 'https://github.com/ruby-gtk-project/console-rb'
end
