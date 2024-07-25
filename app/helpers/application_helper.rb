module ApplicationHelper
  def linkify(text)
    URI.extract(text, ['http', 'https']).uniq.each do |url|
      sub_text = "<a href='#{url}' class='message-link' target='_blank'>#{url}</a>"
      text.gsub!(url, sub_text)
    end
    text.html_safe
  end
end
