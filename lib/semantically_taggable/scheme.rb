require File.expand_path(File.dirname(__FILE__) + '/skos_importer.rb')

module SemanticallyTaggable
  ##
  # A tagging scheme in which many <code>SemanticallyTaggable::Tag</code> instances exist
  # Holds further information about the scheme - whether it's <code>polyhierarchical</code>,
  # what <code>meta</code> scheme to use when rendering tags to HTML, and what delimiter to
  # use when parsing
  class Scheme < ActiveRecord::Base
    has_many :tags

    # CLASS METHODS

    def self.by_name(name)
      Scheme.find_by_name!(name.to_s)
    end

    # INSTANCE METHODS

    def create_tag(attributes)
      Tag.create(attributes) do |tag|
        tag.scheme = self
        yield tag if block_given?
      end
    end

    def import_skos(skos_filename, &block)
      SkosImporter.new(skos_filename, self).import(&block)
    end
  end
end