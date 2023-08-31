require 'nokogiri'

Jekyll::Hooks.register [:posts], :post_convert do |post|
    doc = Nokogiri::HTML.fragment(post.content)
    doc = layout_images(doc)
    post.content = doc.to_html
end

MARKDOWN_DIRECTIVE_RE = /^:: (?<name>[^\s]+)(\s+\[(?<content>[^\]]*)\])?$/

class ImageLayouter
    def layout_images(doc)
        @width = 2

        @new_doc = Nokogiri::HTML.fragment nil

        @cur_images = []
        @caption_encountered = false
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
        elsif element.name == "p" and m = element.text.match(MARKDOWN_DIRECTIVE_RE)
            directive = m[:name].downcase
            case directive
            when "break"
                self.break
            when "width"
                content = m[:content].strip
                width = content.to_i
                self.break
                @width = width
            else
                add_non_image_element(element)
            end
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
                @caption_encountered = true unless element.text.strip.blank?
                @cur_images[-1][1].push element
            end
        end
    end

    def flush_images()
        return if @cur_images.empty?

        images_element = Nokogiri::HTML.fragment("<div class=\"images w#{@width}#{" captiony" if @caption_encountered}\"></div>").children[0]
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
        @caption_encountered = false
    end

    def add_non_image_element(element)
        self.flush_images
        @new_doc.add_child @trailing_whitespace if @trailing_whitespace
        @new_doc.add_child element if element
    end

    def break()
        self.add_non_image_element(nil)
    end
end

def layout_images(doc)
    return ImageLayouter.new().layout_images(doc)
end
