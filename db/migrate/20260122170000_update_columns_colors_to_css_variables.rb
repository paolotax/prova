# frozen_string_literal: true

class UpdateColumnsColorsToCssVariables < ActiveRecord::Migration[8.1]
  # Map hex colors to CSS variables
  COLOR_MAP = {
    "#6366f1" => "var(--color-card-default)",  # Blue (default)
    "#22c55e" => "var(--color-card-4)",         # Green -> Lime
    "#f97316" => "var(--color-card-2)",         # Orange -> Tan
    "#3b82f6" => "var(--color-card-default)",   # Blue
    "#8b5cf6" => "var(--color-card-7)"          # Violet -> Purple
  }.freeze

  def up
    # Update existing columns with hex colors to CSS variables
    COLOR_MAP.each do |hex, css_var|
      execute <<-SQL.squish
        UPDATE columns SET color = '#{css_var}' WHERE color = '#{hex}'
      SQL
    end

    # Update default value for new columns
    change_column_default :columns, :color, "var(--color-card-default)"
  end

  def down
    # Revert to hex colors
    COLOR_MAP.each do |hex, css_var|
      execute <<-SQL.squish
        UPDATE columns SET color = '#{hex}' WHERE color = '#{css_var}'
      SQL
    end

    change_column_default :columns, :color, "#6366f1"
  end
end
