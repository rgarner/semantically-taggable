module SemanticallyTaggable
  require "railtie" if defined?(Rails)
end

require 'active_record'

$LOAD_PATH.unshift(File.dirname(__FILE__))

require "semantically_taggable/semantically_taggable"
require "semantically_taggable/semantically_taggable/core"
require "semantically_taggable/semantically_taggable/collection"
require "semantically_taggable/semantically_taggable/cache"

require "semantically_taggable/tag"
require "semantically_taggable/synonym"
require "semantically_taggable/tag_parentage"
require "semantically_taggable/scheme"
require "semantically_taggable/tagging"
require "semantically_taggable/tag_list"

$LOAD_PATH.shift

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.extend SemanticallyTaggable::Taggable
end

if defined?(ActionView::Base)
  # ActionView::Base.send :include, SemanticallyTaggable::TagsHelper
end