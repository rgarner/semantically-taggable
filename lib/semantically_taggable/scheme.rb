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
      @@schemes[name.to_sym] || raise(ActiveRecord::RecordNotFound,
                                      "SemanticallyTaggable::Scheme #{name.to_sym} not found (you will need to seed the schemes table)")
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
         INNER JOIN tag_parentages tp on t.id = tp.parent_tag_id AND tp.distance <> 0
         LEFT JOIN tag_parentages children ON tp.parent_tag_id = children.child_tag_id AND children.distance <> 0
         WHERE children.child_tag_id IS NULL
         AND t.scheme_id = #{self.id}
      }).first
    end

    def import_skos(skos_filename, &block)
      SkosImporter.new(skos_filename, self).import(&block)
    end

    ##
    # Given a list of tag strings, find how many resources
    # are tagged with it
    def model_counts_for(*tag_strings)
      return [] if tag_strings.empty?
      like_conditions = tag_strings.map { 'tags.name LIKE ?' }.join(' OR ')
      Tag.all(
          :select => 'tags.name, COUNT(DISTINCT taggings.taggable_type, taggings.taggable_id) as tagged_models',
          :joins => [
              'LEFT JOIN tag_parentages ON tags.id = tag_parentages.parent_tag_id',
              'INNER JOIN taggings on taggings.tag_id = tag_parentages.child_tag_id'
          ],
          :conditions => ["tags.scheme_id = ? AND (#{like_conditions})", self.id, *tag_strings],
          :group => 'tags.name'
      ).inject({}) do |summary_hash, tag|
        summary_hash[tag.name] = tag.tagged_models.to_i
        summary_hash
      end
    end

  end
end