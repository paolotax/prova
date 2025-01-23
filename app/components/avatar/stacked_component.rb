# frozen_string_literal: true

module Avatar
  class StackedComponent < ApplicationComponent
    def initialize(users:, size: "md", overflow_count: nil)
      @users, @size, @overflow_count = users, size, overflow_count
    end

    def call
      tag.div class: class_names("flex") do
        tag.ul class: class_names(
          "flex items-center [&>li]:flex [&>li>span]:ring-white",
          ring_width[@size],
          spacing[@size]
        ) do
          @users.each {|user| concat(tag.li render(AvatarComponent.new(user: user, size: @size)))}
        end.concat(overflow_count_badge)
      end
    end

    private

    def overflow_count_badge
      return if @overflow_count.blank?

      tag.span "+#{@overflow_count}",
        class: class_names(
          "relative inline-flex justify-center items-center shrink-0 leading-none uppercase bg-white ring ring-1 ring-offset-0 ring-gray-300 rounded-full",
          overflow_badge_sizes[@size]
        )
    end

    def ring_width
      {
        xs: "[&>li>span]:ring-1",
        sm: "[&>li>span]:ring-2",
        md: "[&>li>span]:ring-2",
        lg: "[&>li>span]:ring-4",
        xl: "[&>li>span]:ring-4"
      }.with_indifferent_access
    end

    def spacing
      {
        xs: "-space-x-0.5",
        sm: "-space-x-0.5",
        md: "-space-x-1.5",
        lg: "-space-x-2",
        xl: "-space-x-3"
      }.with_indifferent_access
    end

      def overflow_badge_sizes
        {
          xs: "size-3 ml-0.5 text-[.5rem] font-normal text-gray-800",
          sm: "size-4 ml-0.5 text-[.65rem] font-normal text-gray-700",
          md: "size-6 ml-1 text-xs font-semibold text-gray-600",
          lg: "size-8 ml-1 text-sm font-semibold text-gray-600",
          xl: "size-10 ml-1.5 text-base font-medium text-gray-600"
        }.with_indifferent_access
      end
  end
end
