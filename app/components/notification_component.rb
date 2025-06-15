# frozen_string_literal: true

class NotificationComponent < ApplicationComponent
  def initialize(position: "top-right", theme: "light", action_style: "button", disable_transitions: false, type: nil, data: {})
    @position = position
    @theme = theme.inquiry
    @action_style = action_style.inquiry
    @disable_transitions = disable_transitions
    @type = type.to_s.inquiry
    @data = prepared(data)
  end

  def rendered_icon
    return if hide_icon? || @type&.notice? || @type.blank?

    send(:"#{@type}_icon")
  end

  def message = @data["message"]

  def description = @data["description"]

  def primary_action = @data["primary_action"]

  def secondary_action = @data["secondary_action"]

  def time_delay = @data["time_delay"]

  def progress_indicator
    return if %w[spinner progress_bar].exclude? @data["progress_indicator"]

    send("#{@data["progress_indicator"]}_indicator")
  end

  def notification_css
    class_names(
      "relative flex justify-between my-2 max-w-sm first:mt-0 last:mb-0 ring-1 ring-offset-0 shadow-xl transition overflow-hidden",
      "rounded-lg border",
      "pointer-events-auto",
      "z-10",
      {
        "divide-x": @action_style.link? && !stacked?,
        "opacity-0": !@disable_transitions,
        "flex-row items-center gap-3": !stacked?,
        "flex-col gap-2": stacked?,
        "bg-white ring-gray-200 divide-gray-100 border-gray-50": @theme.light?,
        "bg-gray-800 ring-gray-900 divide-gray-700 border-gray-600/70": @theme.dark?
      }
    )
  end

  def content_css
    class_names(
      "flex flex-col gap-0.5 py-2",
      {
        "pl-1 pr-3": rendered_icon.present? && !actions_present?,
        "px-3": rendered_icon.blank?
      }
    )
  end

  def message_css
    class_names(
      "text-sm font-medium",
      {
        "text-gray-900": @theme.light?,
        "text-gray-50": @theme.dark?
      }
    )
  end

  def description_css
    class_names(
      "text-sm font-normal",
      {
        "text-gray-500": @theme.light?,
        "text-gray-300": @theme.dark?
      }
    )
  end

  def actions_css
    class_names(
      "flex shrink-0 gap-2 pb-2",
      {
        "flex-col justify-center pt-2": !stacked?,
        "mr-3": @action_style.button?,
        "flex-row ml-3": stacked?
      }
    )
  end

  def action_css
    class_names(
      "block px-2 py-1 text-xs font-semibold transition",
      {
        rounded: @action_style.button?,
        "w-full": !stacked?
      }
    )
  end

  def primary_action_css
    class_names(
      {
        "bg-sky-500 text-white hover:bg-sky-600": @action_style.button? && @theme.light?,
        "bg-sky-600 text-white hover:bg-sky-500": @action_style.button? && @theme.dark?,
        "text-sky-500 hover:text-sky-600": @action_style.link? && @theme.light?,
        "text-sky-400 hover:text-sky-300": @action_style.link? && @theme.dark?
      }
    )
  end

  def secondary_action_css
    class_names(
      "bg-gray-100 text-gray-700 hover:bg-gray-200": @action_style.button? && @theme.light?,
      "bg-gray-700 text-gray-50 hover:bg-gray-600": @action_style.button? && @theme.dark?,
      "pt-3 border-t": @action_style.link? && !stacked?,
      "text-gray-600 border-gray-100 hover:text-gray-800": @action_style.link? && @theme.light?,
      "text-gray-50 border-gray-700 hover:text-gray-300": @action_style.link? && @theme.dark?
    )
  end

  def notification_attributes
    {
      turbo_temporary: "",
      controller: token_list({"appear delayed-remove": !@disable_transitions}),
      clone_marker_target: "item",
      delayed_remove_time_value: time_delay,
      transition_enter: "transition ease-out duration-500",
      transition_enter_start: transition_enter_start,
      transition_enter_end: transition_enter_end,
      transition_leave: "transition ease-in duration-300",
      transition_leave_start: transition_leave_start,
      transition_leave_end: transition_leave_end
    }
  end

  def actions_present?
    primary_action.present? || secondary_action.present?
  end

  private

  def icon_css
    class_names(
      "w-4 h-4 shrink-0 mt-[0.165rem] translate-y-2 ml-3",
      {
        "text-orange-400": @type.alert? && @theme.light?,
        "text-orange-300": @type.alert? && @theme.dark?,
        "text-red-600": @type.error? && @theme.light?,
        "text-red-400": @type.error? && @theme.dark?,
        "text-emerald-500": @type.success? && @theme.light?,
        "text-emerald-400": @type.success? && @theme.dark?
      }
    )
  end

  def prepared(data)
    case data
    when Hash
      data.with_indifferent_access
    else
      {message: data}.with_indifferent_access
    end
  end

  def hide_icon? = @data["hide_icon"] == true

  def stacked? = @data["stacked"] == true

  def top_left_position? = @position == "top-left"

  def top_center_position? = @position == "top-center"

  def top_right_position? = @position == "top-right"

  def bottom_right_position? = @position == "bottom-right"

  def bottom_center_position? = @position == "bottom-center"

  def bottom_left_position? = @position == "bottom-left"

  def transition_enter_start
    class_names(
      "opacity-0",
      {
        "-translate-x-1/4": top_left_position? || bottom_left_position?,
        "-translate-y-1/4": top_center_position?,
        "translate-x-1/4": top_right_position? || bottom_right_position?,
        "translate-y-1/4": bottom_center_position?
      }
    )
  end

  def transition_enter_end
    class_names(
      "opacity-100",
      {
        "translate-x-0": top_left_position? || top_right_position? || bottom_right_position? || bottom_left_position?,
        "translate-y-0": top_center_position? || bottom_center_position?
      }
    )
  end

  def transition_leave_start
    class_names(
      "opacity-100",
      {
        "translate-x-0": top_left_position? || top_right_position? || bottom_right_position? || bottom_left_position?,
        "translate-y-0": top_center_position? || bottom_center_position?
      }
    )
  end

  def transition_leave_end
    class_names(
      "opacity-0",
      {
        "-translate-x-1/4": top_left_position? || bottom_left_position?,
        "-translate-y-1/4": top_center_position?,
        "translate-x-1/4": top_right_position? || bottom_right_position?,
        "translate-y-1/4": bottom_center_position?
      }
    )
  end

  def spinner_indicator
    <<-SVG.html_safe
      <svg stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" class="mx-4 text-gray-600 size-4"><style>.spinner{transform-origin:center; animation:spinner_outside 2s linear infinite}.spinner circle{stroke-linecap:round;animation:spinner_inside 1.5s ease-in-out infinite}@keyframes spinner_outside{100%{transform:rotate(360deg)}}@keyframes spinner_inside{0%{stroke-dasharray:0 150;stroke-dashoffset:0}47.5%{stroke-dasharray:42 150;stroke-dashoffset:-16}95%,100%{stroke-dasharray:42 150;stroke-dashoffset:-59}}</style><g class="spinner"><circle cx="12" cy="12" r="9.5" fill="none" stroke-width="2"></circle></g></svg>
    SVG
  end

  def progress_bar_indicator
    tag.span data: {controller: "progress", progress_time_value: time_delay}, class: "absolute left-0 bottom-0 w-0 h-0.5 bg-sky-500"
  end

  def alert_icon = icon("exclamation-circle", inline_component: true, class: icon_css)

  def error_icon = icon("exclamation-triangle", inline_component: true, class: icon_css)

  def success_icon = icon("check-circle", inline_component: true, class: icon_css)
end
