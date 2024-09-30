class ConnectedBorderCallback
  def initialize(options)
    @radius, @document = options.values_at(:radius, :document)
  end
  def render_in_front(fragment)
    points = [fragment.top_left, fragment.top_right, fragment.bottom_right, fragment.bottom_left]
    @document.stroke_polygon(*points)
    points.each { |point| @document.fill_circle(point, @radius) }
  end
end