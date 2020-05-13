module Jekyll
    module PodtracFilters
        extend self

        URL_RE = /^(?<scheme>https?:\/\/)?(?<rest>.+)(?<extension>\.[^\/.]+$)/i
        def with_podtrac(url)
            m = URL_RE.match(url)
            if m
                scheme = m['scheme'] || 'https://'
                "#{scheme}dts.podtrac.com/redirect#{m['extension']}/#{m['rest']}#{m['extension']}"
            else
                "URL could not be converted to a Podtrac URL."
            end
        end

        def possibly_with_podtrac(url)
            @context.registers[:site].config['use_podtrac'] && Jekyll.env != 'development' ? with_podtrac(url) : url
        end
    end
end

Liquid::Template.register_filter(Jekyll::PodtracFilters)
