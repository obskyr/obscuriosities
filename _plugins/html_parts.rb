module Jekyll
    module HtmlPartsFilters
        HR_RE = /^\s*<\s*hr\s*\/?\s*>\s*$/
        
        def split_hr(html)
            match = html.match HR_RE
            if match
                [html[0...match.offset(0)[0]], html[match.offset(0)[1] + 1..-1]]
            else
                [html, html]
            end
        end

        def before_hr(html)
            split_hr(html)[0]
        end

        def after_hr(html)
            split_hr(html)[1]
        end

        P_END_RE = /\s*<\s*\/\s*p\s*\s*>\s*/

        def first_p(html)
            match = html.match P_END_RE
            if match
                html[0...match.offset(0)[1]]
            else
                html
            end
        end
    end
end

Liquid::Template.register_filter(Jekyll::HtmlPartsFilters)
