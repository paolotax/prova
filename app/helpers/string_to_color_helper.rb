module StringToColorHelper
  TAILWIND_COLORS = %w[
    slate gray zinc neutral stone
    red orange amber yellow lime green emerald teal cyan sky blue indigo violet purple fuchsia pink rose
  ].freeze

  def string_to_color(string)
    hash_value = string.downcase.each_char.sum(&:ord)
    index = hash_value % TAILWIND_COLORS.length

    TAILWIND_COLORS[index]
  end
  
  def string_to_color_hex(string)
    color = string_to_color(string)
    color_to_hex(color)
  end

  def color_to_hex(color)
    case color
    when "slate"
      "708090"
    when "gray"
      "808080"
    when "zinc"
      "7B8794"
    when "neutral"
      "CBD5E0"
    when "stone"
      "E2E8F0"
    when "red"
      "EF4444"
    when "orange"
      "F97316"
    when "amber"
      "F59E0B"
    when "yellow"
      "FCD34D"
    when "lime"
      "84CC16"
    when "green"
      "22C55E"
    when "emerald"
      "10B981"
    when "teal"
      "14B8A6"
    when "cyan"
      "06B6D4"
    when "sky"
      "0EA5E9"
    when "blue"
      "3B82F6"
    when "indigo"
      "6366F1"
    when "violet"
      "8B5CF6"
    when "purple"
      "A855F7"
    when "fuchsia"
      "D946EF"
    when "pink"
      "EC4899"
    when "rose"
      "F43F5E"
    else
      "000000"
    end
  end



end
