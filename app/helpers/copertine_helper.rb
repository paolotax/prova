module CopertineHelper
  def copertina_tag(libro, **options)
    image_tag libro_copertina_path(libro, v: libro.updated_at.to_i),
      alt: libro.titolo,
      loading: "lazy",
      class: class_names("copertina", options.delete(:class)),
      **options
  end
end
