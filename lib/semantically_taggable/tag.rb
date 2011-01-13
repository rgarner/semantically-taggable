require File.join(File.dirname(__FILE__), 'tag_parentage')

module SemanticallyTaggable
  class Tag < ::ActiveRecord::Base
    attr_accessible :name

    ### ASSOCIATIONS:

    belongs_to :scheme

    has_many :broader_tag_relations, :class_name => 'SemanticallyTaggable::TagParentage', :foreign_key => 'child_tag_id'
    has_many :narrower_tag_relations, :class_name => 'SemanticallyTaggable::TagParentage', :foreign_key => 'parent_tag_id', :dependent => :destroy

    has_many :broader_tags,
             :through => :broader_tag_relations,
             :class_name => 'SemanticallyTaggable::Tag', :source => :parent_tag

    has_many :narrower_tags,
             :through => :narrower_tag_relations,
             :class_name => 'SemanticallyTaggable::Tag', :source => :child_tag

    # Bidirectional HABTM using two rows to represent both directions of self-reference
    has_and_belongs_to_many :related_tags, :class_name => 'SemanticallyTaggable::Tag',
                            :association_foreign_key => 'related_tag_id', :join_table => 'related_tags',
                            :insert_sql => 'INSERT INTO related_tags (`tag_id`, `related_tag_id`) VALUES (#{id}, #{record.id}), (#{record.id}, #{id})',
                            :delete_sql => 'DELETE FROM related_tags WHERE (tag_id = #{id} AND related_tag_id = #{record.id}) OR (tag_id = #{record.id} AND related_tag_id = #{id})'

    has_many :taggings, :dependent => :destroy, :class_name => 'SemanticallyTaggable::Tagging'

    ### VALIDATIONS:

    validates_presence_of :name, :message => 'Tag must have a name'
    validates_uniqueness_of :name, :scope => 'scheme_id'

    # TODO: put back :broader_terms when it works
    validates_each :narrower_tags, :related_tags do |tag, attr, related_tags|
      related_tags.each do |related|
        tag.errors.add(attr, "must be in same scheme as related tag") unless related.scheme == tag.scheme
      end
    end

    ### SCOPES:

    def self.using_postgresql?
      connection.adapter_name == 'PostgreSQL'
    end

    def self.named(name)
      where(["name #{like_operator} ?", name])
    end

    def self.named_any(list)
      where(list.map { |tag_name| sanitize_sql(["tags.name #{like_operator} ?", tag_name.to_s]) }.join(" OR "))
    end

    def self.named_like(name)
      where(["name #{like_operator} ?", "%#{name}%"])
    end

    def self.named_like_any(list)
      where(list.map { |tag| sanitize_sql(["name #{like_operator} ?", "%#{tag.to_s}%"]) }.join(" OR "))
    end

    ### CLASS METHODS:

    # If the last param is a symbol, it's taken to be the scheme_name
    def self.find_or_create_all_with_like_by_name(*list)
      scheme_name = list.pop
      raise ArgumentError, "Last item must be the symbol of the scheme name" unless scheme_name.is_a? Symbol

      scheme = SemanticallyTaggable::Scheme.by_name(scheme_name)
      list = [list].flatten

      return [] if list.empty?

      existing_tags = scheme.tags.named_any(list).all
      new_tag_names = list.reject do |name|
        name = comparable_name(name)
        existing_tags.any? { |tag| comparable_name(tag.name) == name }
      end
      created_tags = new_tag_names.map { |name| Tag.create(:name => name) { |tag| tag.scheme = scheme } }

      existing_tags + created_tags
    end

    ### INSTANCE METHODS:

    def ==(object)
      super || (object.is_a?(Tag) && name == object.name)
    end

    def to_s
      name
    end

    def count
      read_attribute(:count).to_i
    end

    class << self
      private
      def like_operator
        using_postgresql? ? 'ILIKE' : 'LIKE'
      end

      def comparable_name(str)
        RUBY_VERSION >= "1.9" ? str.downcase : str.mb_chars.downcase
      end
    end
  end
end