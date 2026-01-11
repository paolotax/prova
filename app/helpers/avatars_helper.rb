module AvatarsHelper
  AVATAR_COLORS = %w[
    #EF4444 #F97316 #F59E0B #EAB308
    #84CC16 #22C55E #10B981 #14B8A6
    #06B6D4 #0EA5E9 #3B82F6 #6366F1
    #8B5CF6 #A855F7 #D946EF #EC4899
  ].freeze

  def avatar_background_color(user)
    seed = (user.display_name || user.name).sum
    AVATAR_COLORS[seed % AVATAR_COLORS.length]
  end
end
