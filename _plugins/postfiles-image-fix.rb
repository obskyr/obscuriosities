# jekyll-postfiles is lovely, *but* it has a bug that prevents images named
# like posts from being copied. (Or rather, perhaps this is a problem with Jekyll.)
# https://github.com/nhoizey/jekyll-postfiles/issues/1
# This plugin excludes such files from Jekyll's processing, and manually copies
# them over to the _site/ directory. (You are also no longer required to
# manually exclude images from _posts/ or _drafts/ in the config.)

require 'cgi'

EXTENSIONS_NOT_TO_PROCESS = Set[
    ".apng",
    ".avif",
    ".bmp",
    ".gif",
    ".jpeg",
    ".jpg",
    ".mng", # Why not. I miss you, MNG.
    ".png",
    ".webp"
].freeze

# As it appears in Jekyll's source code.
DATE_FILENAME_RE = %r!^(?>.+/)*?(\d{2,4}-\d{1,2}-\d{1,2})-([^/]*)(\.[^.]+)$!.freeze

Jekyll::Hooks.register [:site], :after_init do |site|
    dirs = ['_posts/']
    dirs << '_drafts/' if site.config['show_drafts']

    site.config['exclude'] = [] if not site.config['exclude']
    dirs.each do |dir|
        EXTENSIONS_NOT_TO_PROCESS.each do |extension|
            site.config['exclude'] << File.join('/' + dir, '**/*' + extension)
        end
    end
end

copied_files = Set[]

Jekyll::Hooks.register [:posts], :pre_render do |post|
    dirs = ['_posts/']
    dirs << '_drafts/' if post.site.config['show_drafts']

    EXTENSIONS_NOT_TO_PROCESS.each do |extension|
        Dir[File.join(File.dirname(post.relative_path), '**/*' + extension)]
        .filter { |path| File.basename(path) =~ DATE_FILENAME_RE }
        .each do |source|
            dest = File.join "_site", CGI.unescape(post.url), File.basename(source)
            if !File.exist?(dest) || File.mtime(source) > File.mtime(dest)
                FileUtils.cp source, dest
                copied_files << File.absolute_path(dest)
            end
        end
    end
end

Jekyll::Hooks.register [:clean], :on_obsolete do |to_be_cleaned|
    to_be_cleaned.reject! { |path| copied_files.include? path }
end
