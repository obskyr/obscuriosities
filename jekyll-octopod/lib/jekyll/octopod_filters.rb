require 'uri'
require 'digest/sha1'

module Jekyll
  module OctopodFilters
    extend self

    JSON_ENTITIES = { '&' => '\u0026', '>' => '\u003E', '<' => '\u003C', "'" => '\u0027' }

    # Escapes  some text for CDATA
    def cdata_escape(input)
      input.gsub(/<!\[CDATA\[/, '&lt;![CDATA[').gsub(/\]\]>/, ']]&gt;')
    end

    # Replaces relative urls with full urls
    #
    #   {{ "about.html" | expand_urls }}           => "/about.html"
    #   {{ "about.html" | expand_urls:site.url }}  => "http://example.com/about.html"
    def expand_urls(input, url='')
      url ||= '/'
      input.gsub /(\s+(href|src)\s*=\s*["|']{1})(\/[^\"'>]*)/ do
        $1+url+$3
      end
    end

    # Removes scripts tag and audio tags in multiline moderator
    def remove_script_and_audio(input)
      input.gsub(/<audio.*audio>/m, '').gsub(/<script.*script>/m, '')
    end
  
    # Apple Podcasts only accepts a small subset of HTML tags, and if any other
    # HTML tags are present, it'll simply *not show your description.*
    def format_for_apple_podcasts(s)
      s = s.gsub(/<\s*(?<tag>[A-Za-z]+)\b[^>]*>|<\s*\/\s*(?<tag>[A-Za-z]+)\s*>/) { |tag| ['p', 'ol', 'ul', 'li', 'a'].include?(Regexp.last_match['tag'].downcase) ? tag : "" }
      s = newlines_between_paragraphs(s, 1)
      s
    end

    # Both Apple Podcasts and Spotify strip HTML in the show notes in a way
    # that turns "</p>\n\n<p>" into the equivalent of *three* linebreaks,
    # as opposed to just two. This fixes that.
    def newlines_between_paragraphs(s, num_newlines)
      s.gsub(/<\s*\/p\s*>\s*/i, "</p>#{"\n" * num_newlines}")
    end

    # Formats a Time to be RSS compatible like "Wed, 15 Jun 2005 19:00:00 GMT"
    #
    #   {{ site.time | time_to_rssschema }}
    def time_to_rssschema(time)
      time.strftime("%a, %d %b %Y %H:%M:%S %z")
    end

    # Returns the first argument if it's not nil or empty otherwise it returns
    # the second one.
    #
    #   {{ post.author | otherwise:site.author }}
    def otherwise(first, second)
      first = first.to_s
      first.empty? ? second : first
    end

    # Returns the audio file name of a given hash. Is no key as second parameter given, it
    # trys first "mp3", than "m4a" and than it will return a more or less random
    # value.
    #
    #   {{ post.audio | audio:"m4a" }} => "my-episode.m4a"
    def audio(hsh, key = nil)
      if !hsh.nil? && hsh.length
        if key.nil?
          hsh['mp3'] ? hsh['mp3'] : hsh['m4a'] ? hsh['m4a'] : hsh['ogg'] ? hsh['ogg'] : hsh['opus'] ? hsh['opus'] : hsh.values.first
        else
          hsh[key]
        end
      end
    end

    # Returns the audio-type of a given hash. Is no key as second parameter given, it
    # trys first "mp3", than "m4a" and than it will return a more or less random
    # value.
    #
    #   {{ post.audio | audiotype }} => "my-episode.m4a"
    def audio_type(hsh)
      if !hsh.nil? && hsh.length
        hsh['mp3'] ? mime_type('mp3') : hsh['m4a'] ? mime_type('m4a') : hsh['ogg'] ? mime_type('ogg') : mime_type('opus')
      end
    end


    # Returns the MIME-Type of a given file format.
    #
    #   {{ "m4a" | mime_type }} => "audio/mp4a-latm"
    def mime_type(format)
      types = {
        'flac' => 'flac',
        'mp3'  => 'mpeg',
        'm4a'  => 'mp4a-latm',
        'ogg'  => 'ogg; codecs=vorbis',
        'opus' => 'ogg; codecs=opus'
      }

      "audio/#{types[format]}"
    end

    # Returns the size of a given file in bytes. If there is just a filename
    # without a path, this method assumes that the file is an episode audio file
    # which lives in /episodes.
    #
    #   {{ "example.m4a" | file_size }} => 4242
    def file_size(path, rel = nil)
      return 0 if path.nil?
      path = path =~ /\// ? path : File.join('episodes', path)
      path = rel + path if rel
      File.size(path)
    end

    # Returns the size of a given file in bytes by looking into the front matter
    # The sizes should be in 
    # filesize:
    #   mp3: 4242
    # ...
    #
    #   {{ "example.m4a" | size_by_format: "mp3" }} => 4242
    def size_by_format(page, format)
      page["filesize"][format]
    end

    # Converts a size in Bytes to Megabytes
    #
    #   {{ 123456 | in_megabytes }} => 0.1 MB
    def in_megabytes(size_in_bytes)
      (size_in_bytes / 1024.0 / 1024.0).round(2).to_s + " MB"
    end

    # Returns a slug based on the id of a given page.
    #
    #   {{ page | slug }} => '2012_10_02_octopod'
    def slug(page)
      page['id'][1..-1].gsub('/', '_')
    end

    # Returns the image of the post or the default logo.
    #
    #   {{ page | image_with_fallback }} => '/path/to/image.png'
    def image_with_fallback(page)
      if page["image"]
        "/assets/" + page["image"]
      else
        "/assets/images/logo/logo-itunes.png"
      end
    end

    # Returns the download url with fallback to the site's episode folder url
    def download_url_with_fallback(site)
      if site["download_url"] == "" or site["download_url"] == nil
        site["url"] + site["baseurl"] + "/episodes"
      else
        site["download_url"]
      end
    end


    # Splits a chapter, like it is written to the post YAML front matter into
    # the components 'start' which refers to a single point in time relative to
    # the beginning of the media file nad 'title' which defines the text to be
    # the title of the chapter.
    #
    #   {{ '00:00:00.000 Welcome to Octopod!' | split_chapter }}
    #     => { 'start' => '00:00:00.000', 'title' => 'Welcome to Octopod!' }
    #
    #   {{ '00:00:00.000 Welcome to Octopod!' | split_chapter:'title' }}
    #     => 'Welcome to Octopod!'
    #
    #   {{ '00:00:00.000 Welcome to Octopod!' | split_chapter:'start' }}
    #     => '00:00:00.000'
    #
    # Oh, and specifically for Obscuriosities, splitting on more than one space
    # is fixed, and it also supports timestamps without hours or minutes.
    TIMESTAMP_RE = /^(?:(?<hours>[0-9]+):)??(?:(?<minutes>[0-9]+):)??(?<seconds>[0-9]+(?:\.[0-9]+)?)$/
    def split_chapter(chapter_str, attribute = nil)
      attributes = chapter_str.split(' ', 2)
      m = attributes.first.match(TIMESTAMP_RE)
      return nil unless m

      seconds = (m['hours'] || '0').to_i * 3600 +
                (m['minutes'] || '0').to_i * 60 +
                (m['seconds'].to_f)

      start = string_of_start(seconds)

      if attribute.nil?
        { 'start' => start, 'title' => attributes.last }
      else
        attribute == 'start' ? start : attributes.last
      end
    end

    def string_of_start(seconds)
      hours, seconds = seconds.divmod(3600)
      minutes, seconds = seconds.divmod(60)
      "%d:%02d:%06.3f" % [hours, minutes, seconds]
    end

    # Gets a number of seconds and returns an human readable duration string of
    # it.
    #
    #   {{ 1252251 | string_of_duration }} => "00:03:13"
    def string_of_duration(duration)
      seconds = duration.to_i
      minutes = seconds / 60
      hours   = minutes / 60

      "#{"%02d" % hours}:#{"%02d" % (minutes % 60)}:#{"%02d" % (seconds % 60)}"
    end

    # Gets a number of bytes and returns an human readable string of it.
    #
    #   {{ 1252251 | string_of_size }} => "1.19M"
    def string_of_size(bytes)
      bytes = bytes.to_i.to_f
      out = '0'
      return out if bytes == 0.0

      jedec = %w[b K M G]
      [3, 2, 1, 0].each { |i|
        if bytes > 1024 ** i
          out = "%.1f#{jedec[i]}" % (bytes / 1024 ** i)
          break
        end
      }

      return out
    end

    # Returns the host a given url
    #
    #   {{ 'https://github.com/pattex/octopod' | host_from_url }} => "github.com"
    def host_from_url(url)
      URI.parse(url).host
    end

    # Returns the hex-encoded hash value of a given string. The optional
    # second argument defines the length of the returned string.
    #
    #   {{ "Octopod" | sha1 }} => "8b20a59c"
    #   {{ "Octopod" | sha1:23 }} => "8b20a59c8e2dcb5e1f845ba"
    def sha1(str, lenght = 8)
      sha1 = Digest::SHA1.hexdigest(str)
      sha1[0, lenght.to_i]
    end

    # Returns an array of all episode feeds named by the convetion
    # 'episodes.<episode_file_format>.rss' within the root directory. Also it
    # contains all additional feeds specified by 'additional_feeds' in the
    # '_config.yml'. If an 'episode_file_format' or key of 'additional_feeds'
    # equals the optional parameter 'except', it will be skipped.
    #
    #   episode_feeds(site, except = nil) =>
    #   [
    #     ["m4a Episode RSS-Feed", "/episodes.m4a.rss"],
    #     ["mp3 Episode RSS-Feed", "/episodes.mp3.rss"],
    #     ["Torrent Feed m4a", "http://bitlove.org/octopod/octopod_m4a/feed"],
    #     ["Torrent Feed mp3", "http://bitlove.org/octopod/octopod_mp3/feed"]
    #   ]
    def episode_feeds(site, except = nil)
      feeds = []

      if site['episode_feed_formats']
        site['episode_feed_formats'].map { |f|
         feeds << ["#{f} Episode RSS-Feed", "#{site['url']}#{site['baseurl']}/episodes.#{f}.rss"] unless f == except
        }
      end
      if site['additional_feeds']
        site['additional_feeds'].each { |k, v|
          feeds << [k.gsub('_', ' '), v] unless k == except
        }
      end

      feeds
    end

    # Returns HTML links to all episode feeds named by the convetion
    # 'episodes.<episode_file_format>.rss' within the root directory. Also it
    # returns all additional feeds specified by 'additional_feeds' in the
    # '_config.yml'. If an 'episode_file_format' or key of 'additional_feeds'
    # equals the optional parameter 'except', it will be skipped.
    #
    #   {{ site | episode_feeds_html:'m4a' }} =>
    #   <link rel="alternate" type="application/rss+xml" title="mp3 Episode RSS-Feed" href="/episodes.mp3.rss" />
    #   <link rel="alternate" type="application/rss+xml" title="Torrent Feed m4a" href="http://bitlove.org/octopod/octopod_m4a/feed" />
    #   <link rel="alternate" type="application/rss+xml" title="Torrent Feed mp3" href="http://bitlove.org/octopod/octopod_mp3/feed" />
    def episode_feeds_html(site, except = nil)
      episode_feeds(site, except).map { |f|
        %Q{<link rel="alternate" type="application/rss+xml" title="#{f.first || f.last}" href="#{f.last}" />}
      }.join("\n")
    end

    # Returns RSS-XML links to all episode feeds named by the convetion
    # 'episodes.<episode_file_format>.rss' within the root directory. Also it
    # returns all additional feeds specified by 'additional_feeds' in the
    # '_config.yml'. If an 'episode_file_format' or key of 'additional_feeds'
    # equals the optional parameter 'except', it will be skipped.
    #
    #   {{ site | episode_feeds_rss:'m4a' }} =>
    #   <atom:link rel="alternate" href="/episodes.mp3.rss" type="application/rss+xml" title="mp3 Episode RSS-Feed"/>
    #   <atom:link rel="alternate" href="http://bitlove.org/octopod/octopod_m4a/feed" type="application/rss+xml" title="Torrent Feed m4a"/>
    #   <atom:link rel="alternate" href="http://bitlove.org/octopod/octopod_mp3/feed" type="application/rss+xml" title="Torrent Feed mp3"/>
    def episode_feeds_rss(site, except = nil)
      episode_feeds(site, except).map { |f|
        %Q{<atom:link rel="alternate" href="#{f.last}" type="application/rss+xml" title="#{f.first || f.last}"/>}
      }.join("\n")
    end

    # Prints out current version
    def version_string(site)
      Jekyll::Octopod::VERSION::STRING
    end
  end
end

Liquid::Template.register_filter(Jekyll::OctopodFilters)
