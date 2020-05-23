# Without adding `markdown="1"` to HTML tags, Kramdown won't parse markdown
# within those tags. But adding that manually is a pain, so let's automate!

SPOILER_RE = /(<\s*[a-z]+\s*class=["']spoilers["'][^>]*?)(\s*>)/i
Jekyll::Hooks.register [:posts], :pre_render do |post|
    post.content = post.content.gsub(SPOILER_RE, '\1 markdown="1"\2')
end
