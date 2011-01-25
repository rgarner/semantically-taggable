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
      @@schemes ||= Scheme.all.inject({}) do |schemes, scheme|
        schemes[scheme.name.to_sym] = scheme
        schemes
      end
      @@schemes[name.to_sym] || raise(ActiveRecord::RecordNotFound)
    end

    # INSTANCE METHODS

    def create_tag(attributes)
      Tag.create(attributes) do |tag|
        tag.scheme = self
        yield tag if block_given?
      end
    end

    def root_tag
      raise ArgumentError, "No root tags in non-hierarchical schemes" unless polyhierarchical
      Tag.find_by_sql(%{
        SELECT DISTINCT t.* FROM tags t
        INNER JOIN tag_parentages tp on t.id = tp.parent_tag_id
        LEFT JOIN tag_parentages children ON tp.parent_tag_id = children.child_tag_id
        INNER JOIN schemes s on s.id = t.scheme_id
        WHERE children.child_tag_id IS NULL
        AND s.name = '#{name}'
      }).first
    end

    def import_skos(skos_filename, &block)
      SkosImporter.new(skos_filename, self).import(&block)
    end
  end
end