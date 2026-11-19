module ApplicationHelper
  EMOJI_REGEX = /[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{FE00}-\u{FE0F}\u{1F000}-\u{1FFFF}]+/
  URL_REGEX   = %r{https?://[^\s<"']+}

  # Turns URLs into links. Escapes first: the result is marked html_safe, so
  # anything unescaped here would run as markup in the other person's browser.
  def linkify(text)
    return "" if text.to_s.empty?

    escaped = ERB::Util.html_escape(text.to_s)

    escaped.gsub(URL_REGEX) do |url|
      href = url.gsub('"', "%22")
      %(<a href="#{href}" class="message-link underline underline-offset-2" target="_blank" rel="noopener noreferrer">#{url}</a>)
    end.html_safe
  end

  # Big emoji only when the message is nothing but emoji, the way every chat
  # app behaves. Inline emoji stay at text size - blowing them up to 48px mid
  # sentence is what made messages look broken.
  def emojify(text)
    html = text.to_s
    return "".html_safe if html.empty?

    visible = html.gsub(/<[^>]*>/, "").gsub("&nbsp;", " ").strip
    return html.html_safe if visible.empty?

    emoji_only = visible.gsub(EMOJI_REGEX, "").strip.empty?
    glyphs     = visible.scan(EMOJI_REGEX).join.length

    if emoji_only && glyphs <= 6
      size = glyphs <= 2 ? "text-5xl" : "text-4xl"
      return %(<span class="#{size} leading-none">#{html}</span>).html_safe
    end

    html.html_safe
  end
end
