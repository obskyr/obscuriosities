NO_BLURB_RE = /<\s*([a-z]+)\s*class=["']no-blurb["'][^>]*?\s*>(.*?)<\s*\/\s*\1\s*>/i

module Jekyll
    module BlurbFilters
        def blurb(html)
            html.gsub NO_BLURB_RE, ""
        end

        def no_blurb(html)
            html.gsub NO_BLURB_RE, '\2'
        end
    end
end

Liquid::Template.register_filter(Jekyll::BlurbFilters)
