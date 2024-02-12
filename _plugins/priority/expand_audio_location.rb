require 'erb'

Jekyll::Hooks.register [:posts], :pre_render do |post|
  post.data['audio'].dup.each do |extension, location|
    if location.start_with?('/') || location.downcase.start_with?('http://') || location.downcase.start_with?('https://')
      location = File.join((post.site.config['download_url'] || 'episodes'), location)
    elsif location == "TODO"
      location = ""
    end

    post.data['audio'][extension] = location
  end
end