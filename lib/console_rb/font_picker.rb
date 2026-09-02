# frozen_string_literal: true

module ConsoleRb
  # Upstream's KgxFontPicker: a searchable list of the monospace families only,
  # each row drawn in its own face, with a live preview and a size spinner.
  # Gtk::FontDialog would list every family on the system, which is not what a
  # terminal wants.
  class FontPicker
    include I18n

    PREVIEW_TEXT = 'AaBbCcDd 0123 {}[]()<>'

    def initialize(initial_font:, on_select:)
      @initial_font = initial_font
      @on_select = on_select
    end

    def build
      page.tap do
        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = column

          header_bar.tap do |bar|
            bar.pack_start(cancel_button)
            bar.pack_end(select_button)
          end

          column.tap do |box|
            box.append(search_entry)
            box.append(list_frame)
            box.append(preview_entry)
            box.append(size_row)

            size_row.tap do |row|
              row.append(size_label)
              row.append(size_spin)
            end
          end
        end

        search_entry.signal_connect('search-changed') { name_filter.search = search_entry.text }
        size_spin.signal_connect('value-changed') { refresh_preview }
        selection.signal_connect('notify::selected') { refresh_preview }
        list_view.signal_connect('activate') { select }
        select_button.signal_connect('clicked') { select }
        cancel_button.signal_connect('clicked') { @on_select.call(nil) }

        select_initial
        refresh_preview
      end
    end

    def select = @on_select.call(current_font)

    def current_font
      Pango::FontDescription.new.tap do |font|
        font.family = selected_family&.name || @initial_font.family
        font.size = size_spin.value.to_i * Pango::SCALE
      end
    end

    def selected_family = selection.selected_item

    # Pre-select whatever the user is already using, so the list opens on it
    # rather than on the first monospace family alphabetically.
    def select_initial
      @initial_font.family.to_s.downcase.then do |wanted|
        filtered_model.n_items.times do |index|
          filtered_model.get_item(index).then do |family|
            selection.selected = index if family.name.to_s.downcase == wanted
          end
        end
      end
    end

    def refresh_preview
      preview_entry.attributes = Pango::AttrList.new.tap do |attributes|
        attributes.insert(Pango::AttrFontDesc.new(current_font))
      end
    end

    # --- Widgets -------------------------------------------------------------

    def page
      @page ||= Adwaita::NavigationPage.new(toolbar_view, _('Terminal Font')).tap do |p|
        p.tag = 'font-picker'
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.show_start_title_buttons = false
        bar.show_end_title_buttons = false
        bar.show_back_button = false
      end
    end

    def cancel_button
      @cancel_button ||= Gtk::Button.new.tap do |button|
        button.label = _('_Cancel')
        button.use_underline = true
      end
    end

    def select_button
      @select_button ||= Gtk::Button.new.tap do |button|
        button.label = _('_Select')
        button.use_underline = true
        button.add_css_class('suggested-action')
      end
    end

    def column
      @column ||= Gtk::Box.new(:vertical, 5).tap do |box|
        box.add_css_class('font-picker')
      end
    end

    def search_entry
      @search_entry ||= Gtk::SearchEntry.new.tap do |entry|
        entry.placeholder_text = _('Font Name')
        entry.activates_default = true
      end
    end

    def list_frame
      @list_frame ||= Gtk::ScrolledWindow.new.tap do |scroller|
        scroller.hscrollbar_policy = :never
        scroller.max_content_height = 400
        scroller.vexpand = true
        scroller.add_css_class('frame')
        scroller.add_css_class('view')
        scroller.child = list_view
      end
    end

    def list_view
      @list_view ||= Gtk::ListView.new(selection, factory).tap do |view|
        view.show_separators = true
      end
    end

    def selection
      @selection ||= Gtk::SingleSelection.new(filtered_model).tap do |model|
        model.autoselect = false
        model.can_unselect = false
      end
    end

    # Two filters: the monospace test, which is what makes this a terminal font
    # picker, and the search box.
    def filtered_model
      @filtered_model ||= Gtk::FilterListModel.new(font_map, every_filter).tap do |model|
        model.incremental = true
      end
    end

    def every_filter
      @every_filter ||= Gtk::EveryFilter.new.tap do |filter|
        filter.append(monospace_filter)
        filter.append(name_filter)
      end
    end

    def monospace_filter
      @monospace_filter ||= Gtk::CustomFilter.new(&:monospace?)
    end

    def name_filter
      @name_filter ||= Gtk::StringFilter.new(
        Gtk::PropertyExpression.new(Pango::FontFamily.gtype, nil, 'name')
      ).tap do |filter|
        filter.match_mode = :substring
        filter.ignore_case = true
      end
    end

    def font_map = @font_map ||= PangoCairo::FontMap.default

    # Each row renders in its own family, which is the whole point of not using
    # a plain string list.
    def factory
      @factory ||= Gtk::SignalListItemFactory.new.tap do |f|
        f.signal_connect('setup') { |_factory, item| item.child = row_label }
        f.signal_connect('bind') { |_factory, item| bind_row(item) }
      end
    end

    def row_label
      Gtk::Label.new.tap do |label|
        label.xalign = 0.0
        label.ellipsize = :end
        label.add_css_class('font-item')
      end
    end

    def bind_row(item)
      item.item.then do |family|
        item.child.label = family.name
        item.child.attributes = Pango::AttrList.new.tap do |attributes|
          attributes.insert(Pango::AttrFamily.new(family.name))
        end
      end
    end

    def preview_entry
      @preview_entry ||= Gtk::Entry.new.tap do |entry|
        entry.text = PREVIEW_TEXT
      end
    end

    def size_row
      @size_row ||= Gtk::Box.new(:horizontal, 6).tap do |box|
        box.margin_top = 6
      end
    end

    def size_label
      @size_label ||= Gtk::Label.new(_('Font Size')).tap do |label|
        label.hexpand = true
        label.xalign = 0.0
      end
    end

    def size_spin
      @size_spin ||= Gtk::SpinButton.new(size_adjustment, 1.0, 0).tap do |spin|
        spin.numeric = true
      end
    end

    def size_adjustment
      @size_adjustment ||= Gtk::Adjustment.new(initial_size, 1.0, 1000.0, 1.0, 10.0, 0.0)
    end

    def initial_size
      (@initial_font.size.to_f / Pango::SCALE).then { |size| size.positive? ? size : 11.0 }
    end
  end
end
