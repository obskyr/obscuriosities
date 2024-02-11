# Calculate necessary data for podcast episodes (duration, file size, and
# chapters) and fill out the front matter in their associated Markdown files
# automatically. Eventually, I'd like this to support remote files as well
# as local ones – should be possible by fetching just the first bits of
# audio files, where the metadata is, shouldn't it?

require 'down'
require 'wahwah'

LOGGER_TOPIC = File.basename(__FILE__) + ":"

def empty?(x)
    return !(x && x != "" && (!(x.respond_to? :upcase) || x.upcase != "TODO"))
end

def url?(s)
    return s.downcase.start_with?('http://') || s.downcase.start_with?('https://')
end

EXTENSIONS_THAT_REQUIRE_LOADING_FOR_DURATION = ["ogg", "oga", "ogv", "flac", "opus"]

def extensions_to_populate(post)
    return [] if !post.data['audio'].is_a? Hash || post.data['audio'].empty?
    
    to_populate = {}
    post.data['audio'].each do |extension, path|
        to_populate[extension] = false if !empty?(path)
    end
    return [] if to_populate.empty?

    h = post.data['filesize']
    if h && !h.empty?
        to_populate.keys.each do |extension|
            to_populate[extension] = true if empty?(h&.[](extension)) || h&.[](extension) == 0
        end
    else
        # Gotta populate all of 'em if there is no "filesize".
        return to_populate.keys.to_a
    end

    if !to_populate.values.include? true && (!post.data['duration'] || empty?(post.data['duration']))
        # If only the duration needs to be filled in, any of the audio files
        # may be used for that… but it's preferred not to use an Ogg,
        # because you can't determine the duration of an Ogg without reading
        # to the end(! What in the world!!!), meaning that the whole file will
        # need to be downloaded if it's remote (or you can do a byte range
        # request, but that's a heck dang of added complexity, and not all
        # servers support it either way).
        non_oggs = to_populate.keys.reject { |key| EXTENSIONS_THAT_REQUIRE_LOADING_FOR_DURATION.include? key.downcase }
        return [!non_oggs.empty? ? non_oggs[0] : to_populate.keys[0]]
    end

    # TODO: Handle chapters.

    return to_populate.keys.filter { |key| to_populate[key] }
end

def get_duration(file)
    audio = WahWah.open file
    seconds = audio.duration
    return seconds_to_timestamp seconds
end

def seconds_to_timestamp(seconds)
    hours, seconds   = seconds.divmod 3600
    minutes, seconds = seconds.divmod 60
    seconds = seconds.round
    "%d:%02d:%02d" % [hours, minutes, seconds]
end

# This regex could be updated to handle some multiline properties…
# but I don't think it's worth it. Not when I'm the only one using this.
PROPERTY_LINE_RE_TEMPLATE = "(^%{cur_spaces}%{key}:[[:blank:]]*)(.*?)([[:blank:]]*(?:#.*)?$\n)"
NEXT_INDENT_RE = /(?:^ *(?:#.*)?$\n)*^( *)[^#\n].*$/

# Edit in a value into the front matter in the source of a Jekyll post,
# creating any nesting required along the way.
def edit_in(front_matter, chain, cur_spaces = "")
    raise ArgumentError.new "Invalid \"chain\" argument. Must be at least two items long." if chain.length < 2

    property_line_re = Regexp.new(PROPERTY_LINE_RE_TEMPLATE % {cur_spaces: cur_spaces, key: chain[0]})
    m = front_matter.match property_line_re
    line_start, cur_value, line_end = m.captures
    next_indent_m = front_matter.match NEXT_INDENT_RE, m.end(0)
    next_indent = next_indent_m[1]

    if chain.length > 2
        if !cur_value.empty?
            # Could theoretically still be an object – those can be on one line, too – but it probably won't be.
            # And we're not about those edge cases today.
            Jekyll.logger.error LOGGER_TOPIC, "Failed to edit in the chain \"#{chain}\". The key #{chain} had a value on the same line."
            return
        end

        last_direct_child_m = next_indent_m
        last_indent = next_indent
        # Eating through to get to the end of the object.
        while last_indent.length > cur_spaces.length
            # + 1 because this regex doesn't include the trailing newline.
            last_direct_child_m = front_matter.match NEXT_INDENT_RE, last_direct_child_m.end(0) + 1
            last_indent = last_direct_child_m[1]
        end

        new_spaces = next_indent.length > cur_spaces.length ? next_indent : cur_spaces + (2 * " ")
        
        return front_matter[...next_indent_m.begin(0)] + edit_in(front_matter[next_indent_m.begin(0)...last_direct_child_m.end(0)], chain[1...], new_spaces) + front_matter[last_direct_child_m.end(0)...]
    elsif chain.length == 2
        if next_indent.length > cur_spaces.length
            # We're not currently handling when the value is placed on another line, because…
            # bleugh. Added complexity for a case that almost certainly won't pop up for me personally.
            Jekyll.logger.error LOGGER_TOPIC, "Failed to edit in the key-value pair \"#{chain[0]}: #{chain[1]}\". Should be possible to implement!"
            return
        end

        if line_start
            new_line = line_start + chain[1].to_s + line_end
            return front_matter[0...m.begin(0)] + new_line + front_matter[m.end(0)...]
        else
            return front_matter + "#{cur_spaces}#{chain[0]}: #{chain[1]}" + "\n"
        end
    end
end

Jekyll::Hooks.register [:posts], :pre_render do |post|
    to_populate = extensions_to_populate(post)
    next if to_populate.empty?

    post_source = File.read post.path
    post_source = post_source.encode post_source.encoding, universal_newline: true
    start_fence, front_matter, end_fence = post_source.match(/^(---[[:blank:]]*?(?:#.*)?$\n)((?:^.*$\n)*?)^(---[[:blank:]]*$\n?)$/).captures
    if not front_matter
        Jekyll.logger.warn LOGGER_TOPIC, "Front matter not successfully recognized in \"#{post.basename}\"."
        next
    end
    rest_of_post = post_source[start_fence.length + front_matter.length + end_fence.length..]

    actually_populated_anything = false
    to_populate.each_with_index do |extension, i|
        begin
            audio_path = post.data['audio'][extension]
            file = !url?(audio_path) ? File.open(audio_path, 'rb') : Down.open(audio_path)

            post.data['filesize'] = {} if !post.data['filesize']
            if empty? post.data['filesize'][extension]
                post.data['filesize'][extension] = file.size
                front_matter = edit_in front_matter, ['filesize', extension, file.size.to_s]
                actually_populated_anything = true
            end

            if empty? post.data['duration'] && (!EXTENSIONS_THAT_REQUIRE_LOADING_FOR_DURATION.include? extension || i == to_populate.length - 1)
                duration = get_duration file
                post.data['duration'] = duration
                front_matter = edit_in front_matter, ['duration', duration]
                actually_populated_anything = true
            end
        rescue Errno::ENOENT
            Jekyll.logger.warn LOGGER_TOPIC, "Failed to open the file \"#{audio_path}\" for \"#{post.basename}\"."
        ensure
            file.close if file
        end
    end

    if actually_populated_anything
        File.write post.path, start_fence + front_matter + end_fence + rest_of_post
        Jekyll.logger.info LOGGER_TOPIC, "Filled in podcast audio information in #{post.basename}!"
    end
end
