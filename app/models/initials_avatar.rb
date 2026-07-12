require "base64"

class InitialsAvatar
  HEX_COLOR = /\A[0-9A-F]{6}\z/i

  def self.data_uri(initials, color:, background:)
    color = normalize_color(color, fallback: "FFFFFF")
    background = normalize_color(background, fallback: "6B7280")
    label = ERB::Util.html_escape(initials.to_s.first(3).upcase)
    svg = <<~SVG.delete("\n")
      <svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
        <rect width="128" height="128" fill="##{background}"/>
        <text x="64" y="67" fill="##{color}" font-family="Arial,sans-serif" font-size="48" font-weight="600" text-anchor="middle" dominant-baseline="middle">#{label}</text>
      </svg>
    SVG

    "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
  end

  def self.normalize_color(value, fallback:)
    value.to_s.match?(HEX_COLOR) ? value.upcase : fallback
  end
  private_class_method :normalize_color
end
