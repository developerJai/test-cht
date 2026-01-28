module ApplicationHelper
  EMOJI_REGEX = /[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{FE00}-\u{FE0F}\u{1F000}-\u{1FFFF}]+/

  def linkify(text)
    return text unless text.to_s.present?

    URI.extract(text, ['http', 'https']).uniq.each do |url|
      sub_text = "<a href='#{url}' class='message-link' target='_blank'>#{url}</a>"
      text.gsub!(url, sub_text)
    end
    text.html_safe
  end

  def emojify(text)
    return text unless text.to_s.present?
    
    text.gsub(EMOJI_REGEX) { |emoji| "<span class='text-5xl align-middle'>#{emoji}</span>" }.html_safe
  end
end
