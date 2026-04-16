require "zlib"

module AvatarsHelper
  AVATAR_COLORS = %w[
    #AF2E1B #CC6324 #3B4B59 #BFA07A #ED8008 #ED3F1C #BF1B1B #736B1E #D07B53
    #736356 #AD1D1D #BF7C2A #C09C6F #698F9C #7C956B #5D618F #3B3633 #67695E
  ]

  def avatar_background_color(user)
    AVATAR_COLORS[Zlib.crc32(user.to_param) % AVATAR_COLORS.size]
  end

  def avatar_tag(user, hidden_for_screen_reader: false, **options)
    link_to user_path(user), class: class_names("avatar btn btn--circle", options.delete(:class)), data: { turbo_frame: "_top" },
      aria: { hidden: hidden_for_screen_reader, label: user.name },
      tabindex: hidden_for_screen_reader ? -1 : nil,
      **options do
      avatar_image_tag(user)
    end
  end

  def avatar_tags(users, **options)
    users.collect { avatar_tag(it, **options) }.join.html_safe
  end

  def mail_avatar_tag(user, size: 48, **options)
    if user.avatar.attached?
      image_tag user_avatar_url(user), alt: user.name, class: "avatar", size: size, **options
    else
      tag.span class: "avatar", style: "background-color: #{avatar_background_color(user)};" do
        user.initials
      end
    end
  end

  def avatar_preview_tag(user, hidden_for_screen_reader: false, **options)
    tag.span class: class_names("avatar", options.delete(:class)),
      aria: { hidden: hidden_for_screen_reader, label: user.name },
      tabindex: hidden_for_screen_reader ? -1 : nil do
      avatar_image_tag(user, **options)
    end
  end

  def avatar_image_tag(user, **options)
    image_tag user_avatar_path(user, script_name: Current.account&.slug), aria: { hidden: "true" }, size: 48, title: user.name, **options
  end

  def persona_avatar_tag(persona, **options)
    size = options.delete(:size) || "3ch"
    if persona.avatar_attached?
      tag.span class: class_names("avatar", options.delete(:class)),
        style: "--avatar-size: #{size};",
        title: persona.nome_completo,
        **options do
        image_tag persona.avatar_thumbnail, aria: { hidden: "true" }
      end
    else
      tag.span class: class_names("avatar", options.delete(:class)),
        style: "background-color: #{persona.avatar_background_color}; color: white; font-size: 0.6em; font-weight: 700; --avatar-size: #{size};",
        title: persona.nome_completo,
        **options do
        persona.initials
      end
    end
  end

  def appuntabile_avatar_tag(appuntabile, **options)
    return unless appuntabile

    case appuntabile
    when Persona
      persona_avatar_tag(appuntabile, **options)
    when Scuola
      entity_icon_avatar_tag("building-library", appuntabile.denominazione, **options)
    when Cliente
      entity_icon_avatar_tag("briefcase", appuntabile.denominazione, **options)
    end
  end

  def entity_icon_avatar_tag(icon_name, title, **options)
    size = options.delete(:size) || "3ch"
    tag.span class: class_names("avatar", options.delete(:class)),
      style: "background-color: var(--color-bg-secondary); --avatar-size: #{size};",
      title: title,
      **options do
      icon_tag(icon_name)
    end
  end
end
