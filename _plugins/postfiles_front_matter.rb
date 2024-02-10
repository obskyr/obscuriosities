# jekyll-postfiles is lovely, *but* it doesn't handle front matter – which is
# reasonable, I suppose, since asset path front matter properties
# don't have set keys. This little band-aid makes it possible for front matter
# asset paths to work the same way jekyll-postfiles does.

# Could be put in _config.yaml, but I don't see the need at the moment.
KEYS_TO_PROCESS = [
    "image",
    "cover-image"
]

Jekyll::Hooks.register [:posts], :pre_render do |post|
    KEYS_TO_PROCESS.each do |key|
      next unless post.data.key? key
      value = post.data[key]
      unless value.start_with? '/' || value.downcase.start_with? 'http://' || value.downcase.start_with? 'https://'
        post.data[key] = post.url + value
      end
    end
end
