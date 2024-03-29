require 'erb'
require 'addressable'

Jekyll::Hooks.register [:posts], :pre_render do |post|
  post.data['audio'].dup.each do |extension, location|
    if location == "TODO"
      location = ""
    elsif not location.start_with?('/') || location.downcase.start_with?('http://') || location.downcase.start_with?('https://')
      location = File.join((post.site.config['download_url'] || 'episodes'), location)
    end

    if location.downcase.start_with?('http://') || location.downcase.start_with?('https://')
      location = Addressable::URI.parse(location).normalize.to_s
    end

    post.data['audio'][extension] = location
  end
end
