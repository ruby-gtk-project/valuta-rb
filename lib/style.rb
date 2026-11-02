# frozen_string_literal: true

require 'gtk4'

# Style is the application's stylesheet.
#
# Ported from upstream's src/assets/style.css, which meson bakes into the
# gresource and the application loads at startup. The rules are the same ones,
# with the accent colour overrides and the fourteen classes the widgets apply:
# the big conversion typeface, the accent-coloured result panel, the circular
# switch button, the popover's search box and list spacing.
#
module Style
  # Upstream's two overrides point at @green_3 and @green_5 from libadwaita's
  # named palette. Recent libadwaita has moved that palette to CSS custom
  # properties, so the three shades upstream leans on are spelled out here at
  # their GNOME palette values and the overrides below stay as upstream wrote
  # them.
  CSS = <<~CSS
    @define-color green_1 #8ff0a4;
    @define-color green_3 #33d17a;
    @define-color green_5 #26a269;

    @define-color accent_color @green_3;
    @define-color accent_bg_color @green_5;

    selection {
      background-color: alpha(@green_1, 0.2);
    }

    .pd {
      padding: 0.5rem;
    }

    .rounded {
      border-radius: 6px;
    }

    .text-light {
      color: rgb(255, 255, 255);
    }

    .f-l {
      font-size: 2rem;
    }

    .bg-accent-color {
      background-color: @accent_bg_color;
    }

    .top-transform {
      transform: translateY(-20px);
    }

    .large-button {
      padding: 0.5rem;
    }

    .search-box {
      background: @popover_bg_color;
      border-bottom: 1px solid @borders;
      padding: 6px;
    }

    .currency-selector list {
      padding: 6px;
      padding-top: 4px;
    }

    .currency-selector row {
      margin-top: 2px;
    }

    .currency-selector separator {
      margin: 0 6px;
    }

    .link {
      padding: 0px;
    }
  CSS

  PRIORITY = Gtk::StyleProvider::PRIORITY_APPLICATION

  # Installs the stylesheet on the display, the way upstream's resource-loaded
  # provider is installed for the whole application.
  def self.load(display = Gdk::Display.default)
    display.then do |target|
      if target
        Gtk::StyleContext.add_provider_for_display(target, provider, PRIORITY)
      end
    end
  end

  def self.provider
    @provider ||= Gtk::CssProvider.new.tap do |css|
      css.load_from_data(CSS)
    end
  end
end
