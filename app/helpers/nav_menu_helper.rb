module NavMenuHelper
  # Campo di ricerca per filtrare il menu
  def jump_field_tag
    text_field_tag :search, nil,
      type: "search",
      role: "combobox",
      placeholder: "Cerca...",
      class: "w-full px-4 py-2 text-sm border-0 bg-gray-100 rounded-lg focus:ring-2 focus:ring-blue-500 focus:bg-white",
      autofocus: true,
      autocorrect: "off",
      autocomplete: "off",
      aria: { activedescendant: "" },
      data: {
        filter_target: "input",
        nav_section_expander_target: "input",
        navigable_list_target: "input",
        action: "input->filter#filter"
      }
  end

  # Pulsanti hotkey orizzontali (1, 2, 3)
  def filter_hotkey_link(title, path, key, icon_name)
    link_to path,
      class: "popup-item flex-1 flex items-center justify-center gap-2 px-3 py-2 rounded-lg bg-gray-50 hover:bg-gray-100 border border-gray-200 transition-colors text-sm text-gray-700",
      id: "filter-hotkey-#{key}",
      role: "listitem",
      data: {
        filter_target: "item",
        navigable_list_target: "item",
        controller: "hotkey",
        action: "keydown.#{key}@document->hotkey#click"
      } do
        concat nav_icon(icon_name)
        concat tag.span(title)
        concat tag.kbd(key, class: "ml-1 px-1.5 py-0.5 text-xs bg-white text-gray-500 rounded border border-gray-300")
      end
  end

  # Sezione collassabile con caret
  def collapsible_nav_section(title, &block)
    tag.details class: "nav-section group",
                data: {
                  action: "toggle->nav-section-expander#toggle",
                  nav_section_expander_target: "section",
                  nav_section_expander_key_value: title.parameterize
                },
                open: true do
      concat(tag.summary(class: "flex items-center gap-2 px-4 py-2 text-xs font-semibold text-gray-500 uppercase tracking-wider cursor-pointer hover:text-gray-700 list-none") do
        concat tag.svg(class: "w-3 h-3 transition-transform group-open:rotate-90") {
          tag.path(d: "M9 5l7 7-7 7", stroke: "currentColor", stroke_width: "2", fill: "none")
        }
        concat title
      end)
      concat(tag.ul(class: "popup-list space-y-1 px-2") do
        capture(&block)
      end)
    end
  end

  # Voce singola del menu
  def nav_menu_item(title, path, icon_name, options = {})
    method = options.delete(:method)

    link_options = {
      class: "flex items-center gap-3 px-4 py-2 rounded-lg hover:bg-gray-100 transition-colors text-gray-700"
    }
    link_options[:data] = { turbo_method: method } if method

    tag.li(class: "popup-item",
           data: { filter_target: "item", navigable_list_target: "item" }) do
      link_to path, link_options do
        concat nav_icon(icon_name)
        concat tag.span(title, class: "overflow-hidden text-ellipsis")
      end
    end
  end

  def nav_icon(name)
    icons = {
      "home" => "M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6",
      "calendar" => "M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z",
      "note" => "M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z",
      "school" => "M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4",
      "book" => "M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253",
      "truck" => "M9 17a2 2 0 11-4 0 2 2 0 014 0zM19 17a2 2 0 11-4 0 2 2 0 014 0z M13 16V6a1 1 0 00-1-1H4a1 1 0 00-1 1v10a1 1 0 001 1h1m8-1a1 1 0 01-1 1H9m4-1V8a1 1 0 011-1h2.586a1 1 0 01.707.293l3.414 3.414a1 1 0 01.293.707V16a1 1 0 01-1 1h-1m-6-1a1 1 0 001 1h1M5 17a2 2 0 104 0m-4 0a2 2 0 114 0m6 0a2 2 0 104 0m-4 0a2 2 0 114 0",
      "document" => "M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z",
      "people" => "M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z",
      "cash" => "M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z",
      "chart" => "M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z",
      "person" => "M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z",
      "building" => "M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4",
      "logout" => "M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1",
      "shield" => "M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z",
      "server" => "M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01",
      "speedometer" => "M13 10V3L4 14h7v7l9-11h-7z"
    }

    path_data = icons[name] || icons["home"]

    tag.svg(class: "w-5 h-5 text-gray-500 shrink-0", fill: "none", viewBox: "0 0 24 24", stroke: "currentColor", stroke_width: "1.5") do
      tag.path(stroke_linecap: "round", stroke_linejoin: "round", d: path_data)
    end
  end
end
