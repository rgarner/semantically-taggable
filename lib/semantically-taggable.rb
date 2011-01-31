module SemanticallyTaggable
  require "railtie" if defined?(Rails)
  # Tag has a HABTM which causes all sorts of ructions
  # https://rails.lighthouseapp.com/projects/8994/tickets/6233-habtm-join-requires-an-active-connection
  # So we defer the availability of tag. Hopefully nothing references it during startup.
  # (this, if you hadn't guessed, is properly hacky)
  autoload :Tag, "semantically_taggable/tag"
end

require 'active_record'

$LOAD_PATH.unshift(File.dirname(__FILE__))

require "semantically_taggable/semantically_taggable"
require "semantically_taggable/semantically_taggable/core"
require "semantically_taggable/semantically_taggable/collection"
require "semantically_taggable/semantically_taggable/cache"

require "semantically_taggable/synonym"
require "semantically_taggable/tag_parentage"
require "semantically_taggable/scheme"
require "semantically_taggable/tagging"
require "semantically_taggable/tag_list"

require "semantically_taggable/tags_helper"

$LOAD_PATH.shift

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.extend SemanticallyTaggable::Taggable
end

if defined?(ActionView::Base)
  ActionView::Base.send :include, SemanticallyTaggable::TagsHelper
end