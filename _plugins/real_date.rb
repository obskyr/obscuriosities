# It's [current year], and Jekyll doesn't do time zones correctly. If you move
# to another country, or heck, even if you go on vacation, your posts' times
# (and often even dates!) change. What.
# I give all my thanks for this sorta-workaround to the user "t-brink" at the
# GitHub issue for this: https://github.com/jekyll/jekyll/issues/6033
# However, date_to_xmlschema, date_to_rfc822, date_to_string, and
# date_to_long_string still can't be used - which is why I monkeypatch them
# here. Mamma mia.

Jekyll::Hooks.register [:pages, :posts], :pre_render do |post|
    # Get date and timezone.
    next unless post.data.key? "date"
    date = post.data["date"]
    if post.data.key? "tz"
      # Normalize timezone.
      begin
        m_tz = /^([-+])(\d\d):?(\d\d)$/.match(post.data["tz"])
      rescue TypeError
        raise "The \"tz\" field in #{post.path} must be a string!"
      end
      raise "Wrong timezone format in field \"tz\" in file #{post.path}" \
        unless m_tz
      tz = m_tz[1] + m_tz[2] + ":" + m_tz[3]
    else
      # The tz field is missing.
      puts "WARNING: File #{post.path} has a date without " + \
           "a \"tz\" in the front matter, using UTC."
      tz = "+00:00"
    end
    # Store the actual date.
    # I don't know if modifying post.date like this causes any trouble
    # anywhere, but... I'm just gonna hope it doesn't for now! This makes
    # the dates for posts in sitemap.xml correct.
    post.data["date"] = Time.new(date.year, date.month, date.day,
                                      date.hour, date.min, date.sec,
                                      tz)
    post.data["real-date"] = Time.new(date.year, date.month, date.day,
                                      date.hour, date.min, date.sec,
                                      tz)
end

module Jekyll
    module RealDateFilters
        def date_to_xmlschema(time)
            time.strftime "%Y-%m-%dT%H:%M:%S%:z"
        end

        def date_to_rfc822(time)
            time.strftime "%a, %d %b %Y %H:%M:%S %z"
        end

        def date_to_string(time)
            time.strftime "%d %b %Y"
        end

        def date_to_long_string(time)
            time.strftime "%d %B %Y"
        end
    end
end

Liquid::Template.register_filter(Jekyll::RealDateFilters)
