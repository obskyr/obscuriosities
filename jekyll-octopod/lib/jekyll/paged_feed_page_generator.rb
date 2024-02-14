module Jekyll
  class PagedFeedPageGenerator < Generator
    safe true

    def generate(site)
      pages_total = (site.posts.docs.count.to_f / site.config["episodes_per_feed_page"]).ceil

      # TODO: Remove the ['ogg'] special case from here once the Ogg feed has been removed.
      (site.config["episode_feed_formats"] + ['ogg']).each do |page_format|
        name = "episodes." + page_format + ".rss"
        page = PagedFeedPage.new(site, site.source, ".", name, 1, pages_total, page_format)
        site.pages.reject! { |existing_page| existing_page.relative_path == page.relative_path }
        site.pages << page
        (1..pages_total).each do |page_number|
          name = "episodes" + page_number.to_s + "." + page_format + ".rss"
          page = PagedFeedPage.new(site, site.source, ".", name, page_number, pages_total, page_format)
          site.pages << page
        end
      end
    end
  end
end