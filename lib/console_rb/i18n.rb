# frozen_string_literal: true

require 'gettext'

module ConsoleRb
  # Translation lookup, sharing GNOME Console's message catalogue so its 61
  # existing translations apply unchanged. Every user-visible string in this
  # port uses the same msgid — and the same msgctxt — as the C original.
  module I18n
    TEXT_DOMAIN = 'console-rb'

    # Installed builds keep the catalogues beside lib/; a checkout compiles them
    # into data/locale with `rake locale`.
    def self.locale_path
      ENV.fetch('CONSOLE_RB_LOCALE_DIR') { File.expand_path('../../data/locale', __dir__) }
    end

    # GetText binds a text domain per including class, so one bound class does
    # the lookups for the whole app rather than every widget class binding its
    # own copy.
    class Catalogue
      include GetText

      bindtextdomain TEXT_DOMAIN, path: ConsoleRb::I18n.locale_path

      def translate(message) = _(message)

      def translate_in_context(context, message) = p_(context, message)

      def translate_plural(singular, plural, count) = n_(singular, plural, count)
    end

    def self.catalogue = @catalogue ||= Catalogue.new

    # Re-binds after a locale change. The app resolves its locale once at
    # startup; only the tests switch languages mid-process, and doing so needs
    # the `locale` gem's own cache cleared as well as GetText's.
    def self.reset
      Locale.clear
      Locale.clear_all
      GetText::TextDomainManager.clear_caches
      @catalogue = nil
    end

    def _(message) = I18n.catalogue.translate(message)

    # Context-qualified lookup, matching the C `C_()` macro.
    def p_(context, message) = I18n.catalogue.translate_in_context(context, message)

    # Plural lookup, matching `g_dngettext`.
    def n_(singular, plural, count) = I18n.catalogue.translate_plural(singular, plural, count)
  end
end
