module Notification
  class ContainerComponent < ApplicationComponent
    def initialize(flash: nil, position: "top-right")
      @flash, @position = flash, position

      raise StandardError.new("Incorrect position: `#{position}`. Should be one of: #{positions.keys.to_sentence(last_word_connector: " or ")}") if positions.keys.map(&:to_s).exclude? position
    end

    def call
      tag.ul turbo_frame, data: {controller: "clone-marker", clone_marker_touch_class: "animate-zoom", turbo_temporary: nil}, class: class_names("flex fixed left-0 w-full gap-2 p-4 pointer-events-none z-50", positions[@position.to_sym])
    end

    private

    def turbo_frame
      tag.turbo_frame id: "notification" do
        @flash.each do |type, data|
          concat(render(NotificationComponent.new(position: @position, type: type, data: data)))
        end
      end
    end

    def positions
      {
        "top-left": "top-0 justify-start",
        "top-center": "top-0 justify-center",
        "top-right": "top-0 justify-end",
        "bottom-right": "bottom-0 justify-end",
        "bottom-center": "bottom-0 justify-center",
        "bottom-left": "bottom-0 justify-start"
      }
    end
  end
end
