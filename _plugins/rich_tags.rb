Jekyll::Hooks.register [:site], :post_read do |site|
    site.data['rich_tags'] = autofill_rich_tags(site.data['rich_tags'])

    tag_to_canonical_key = {}
    site.tags.each do |cur_tag, pages|
        key = cur_tag.downcase
        rich_tag = site.data['rich_tags'][key]
        if not rich_tag.nil?
            tag_to_canonical_key[cur_tag] = rich_tag['canonical_key']
        else
            Jekyll.logger.warn "Warning: Tag not in _data/tags.yaml: " + key
            site.data['rich_tags'][key] = {
                'canonical_key' => key,
                'abbreviation' => key,
                'long_name' => key,
                'long_name_with_abbreviation' => key,
                'slug' => Jekyll::Utils.slugify(key)
            }
            tag_to_canonical_key[cur_tag] = key
        end
    end

    tags = {}
    
    site.tags.each do |cur_original_tag, pages|
        canonical_key = tag_to_canonical_key[cur_original_tag]
        tags[canonical_key] = [] if not tags.key? canonical_key
        tags[canonical_key] += pages
    end

    site.tags.keys.to_a.each do |cur_original_tag|
        site.tags.delete cur_original_tag
    end

    tags.each do |cur_canonical_tag, pages|
        site.tags[cur_canonical_tag] = pages
    end
    
    site.data['rich_tags_arr'] = []
    tags.each do |cur_canonical_tag, pages|
        site.data['rich_tags_arr'].push site.data['rich_tags'][cur_canonical_tag]
    end
    site.data['rich_tags_arr'].sort_by! { |rich_tag| rich_tag['long_name'] }

    site.posts.docs.each do |post|
        tags = []
        rich_tags = []

        post.data['tags'].each do |cur_original_tag|
            canonical_key = tag_to_canonical_key[cur_original_tag]
            tags.push canonical_key
            rich_tags.push site.data['rich_tags'][canonical_key]
        end

        tags.sort!
        rich_tags.sort_by! { |rich_tag| rich_tag['long_name'] }

        post.data['tags'] = tags
        post.data['rich_tags'] = rich_tags
    end
end

def autofill_rich_tags(manual_rich_tags)
    rich_tags = {}

    manual_rich_tags.each do |key, manual_rich_tag|
        cur_rich_tag = {}
        cur_rich_tag['long_name'] = manual_rich_tag['long_name']
        cur_rich_tag['abbreviation'] = manual_rich_tag['abbreviation']
        cur_rich_tag['abbreviation'] = manual_rich_tag['long_name'] if not manual_rich_tag.key? 'abbreviation'
        cur_rich_tag['long_name'] = manual_rich_tag['long_name'] if not manual_rich_tag.key? 'long_name'
        abbreviation_re = Regexp.new "\\b#{cur_rich_tag['abbreviation']}\\b"
        if not cur_rich_tag['long_name'] =~ abbreviation_re
            cur_rich_tag['long_name_with_abbreviation'] = "#{cur_rich_tag['long_name']} (#{cur_rich_tag['abbreviation']})"
        else
            cur_rich_tag['long_name_with_abbreviation'] = cur_rich_tag['long_name']
        end
        cur_rich_tag['canonical_key'] = key.downcase
        cur_rich_tag['slug'] = Jekyll::Utils.slugify(key)

        # Rich tags are available through several aliases. Those are registered
        # in site.tags here.
        register_rich_tag(rich_tags, cur_rich_tag['canonical_key'], cur_rich_tag)
        register_rich_tag(rich_tags, cur_rich_tag['long_name'], cur_rich_tag) if manual_rich_tag.key? 'long_name'
        register_rich_tag(rich_tags, cur_rich_tag['abbreviation'], cur_rich_tag) if manual_rich_tag.key? 'abbreviation'
        if manual_rich_tag['aliases']
            manual_rich_tag['aliases'].each do |synonym|
                register_rich_tag(rich_tags, synonym, cur_rich_tag)
            end
        end
    end

    return rich_tags
end

def register_rich_tag(rich_tags, name, cur_rich_tag)
    name = name.downcase
    raise ArgumentError.new "Duplicate rich tag name: \"#{name}\"" if rich_tags.key? name and rich_tags[name] != cur_rich_tag
    rich_tags[name] = cur_rich_tag
end
