require 'nokogiri'

Jekyll::Hooks.register [:posts], :post_convert do |post|
    doc = Nokogiri::HTML.fragment(post.content)
    doc = layout_images(doc)
    post.content = doc.to_html
end

MARKDOWN_DIRECTIVE_RE = /^:: (?<name>[^\s]+)(\s+\[(?<content>[^\]]*)\])?$/
MARKDOWN_DIRECTIVES_RE = /\A#{MARKDOWN_DIRECTIVE_RE}(\n#{MARKDOWN_DIRECTIVE_RE})*\Z/

class ImageLayouter
    def layout_images(doc)
        @width = 2

        @new_doc = Nokogiri::HTML.fragment nil

        @cur_images = []
        @align_class = "align-middle"
        @trailing_whitespace = nil

        doc.children.each do |element|
            self.update(element)
        end
        self.flush_images()

        return @new_doc
    end
    
    def update(element)
        if element.name == "text"
            @trailing_whitespace = element
            return
        end

        if element.name == "p" and element.children[0].name == "img"
            update_from_p(element)
        elsif element.name == "p" and element.text.match(MARKDOWN_DIRECTIVES_RE)
            enact_directives(element.text)
        else
            add_non_image_element(element)
        end

        @trailing_whitespace = nil
    end

    def update_from_p(p_element)
        p_element.children.each do |element|
            if element.name == "img"
                @cur_images.push [element, []]
            else
                @cur_images[-1][1].push element
            end
        end
    end

    def flush_images()
        return if @cur_images.empty?

        images_element = Nokogiri::HTML.fragment("<div class=\"images w#{@width} #{@align_class}\"></div>").children[0]
        @cur_images.each do |img, caption_elements|
            image_container = Nokogiri::HTML.fragment("<div class=\"image-container\"></div>").children[0]
            image_container.add_child img
            images_element.add_child image_container

            if not caption_elements.reject{ |element| element.text.strip.blank? }.empty?
                caption_element = Nokogiri::HTML.fragment("<div class=\"caption\"></div>").children[0]
                caption_elements.each do |element|
                    caption_element.add_child element
                end
                image_container.add_child caption_element
            end
        end
        @new_doc.add_child images_element

        @cur_images = []
    end

    def add_non_image_element(element)
        self.flush_images
        @new_doc.add_child @trailing_whitespace if @trailing_whitespace
        @new_doc.add_child element if element
    end

    def enact_directives(newline_separated_directives)
        matches = []
        newline_separated_directives.scan(MARKDOWN_DIRECTIVE_RE) { matches << $~ }
        matches.each do |m|
            directive = m[:name].downcase
            content = m[:content].strip
            case directive
            when "width"
                width = content.to_i
                self.break
                @width = width
            when "vertical-align"
                case content.downcase
                when "top"
                    @align_class = "align-top"
                when "middle"
                    @align_class = "align-middle"
                when "baseline"
                    @align_class = "align-baseline"
                when "bottom"
                    @align_class = "align-bottom"
                else
                    Jekyll.logger.warn "Warning: Invalid value for vertical-align directive: \"#{content.downcase}\" (valid values are \"top\", \"middle\", \"baseline\", and \"bottom\")"
                end
            when "break"
                self.break
            else
                add_non_image_element(element)
            end
        end
    end

    def break()
        self.add_non_image_element(nil)
    end
end

def layout_images(doc)
    return ImageLayouter.new().layout_images(doc)
end
