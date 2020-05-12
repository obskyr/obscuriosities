# I would do this post-render directly on the HTML, but for now, Jekyll
# apparently doesn't let you edit the rendered HTML...
# https://github.com/jekyll/jekyll/issues/4714
Jekyll::Hooks.register [:posts], :pre_render do |post, payload|
    next unless post.data.key? 'audio'
    
    match = post.content.match /^(?:\-{3,}|_{3,}|\*{3,})\s*$/
    if match
        post.content = post.content[match.offset(0)[1] + 1..-1]
        show_notes = post.content[0...match.offset(0)[0]]
    else
        show_notes = post.content
    end
    
    # Apparently this is a way to render Liquid in a hook.
    # ...But, it also modifies some state, so the content to be displayed is
    # set to whatever .parse(...) is called on, so... this doesn't work. Egh.
    template = post.site.liquid_renderer.file(post.path).parse(show_notes)
    info = {
        :registers        => { :site => post.site, :page => payload['page'], :post => post },
        :strict_filters   => post.site.config["liquid"]["strict_filters"],
        :strict_variables => post.site.config["liquid"]["strict_variables"],
    }
    show_notes = template.render(payload, info)
    
    # And then we gotta convert it to HTML.
    show_notes = post.site.find_converter_instance(Jekyll::Converters::Markdown).convert(show_notes)
    
    post.data['show-notes'] = show_notes
end
