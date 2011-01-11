module SemanticallyTaggable
  class Tag < ::ActiveRecord::Base
    attr_accessible :name

    ### ASSOCIATIONS:

    belongs_to :scheme
    has_many :taggings, :dependent => :destroy, :class_name => 'SemanticallyTaggable::Tagging'

    ### VALIDATIONS:

    validates_presence_of :name, :message => 'Tag must have a name'
    validates_uniqueness_of :name, :scope => 'scheme_id'

    ### SCOPES:
    
    def self.using_postgresql?
      connection.adapter_name == 'PostgreSQL'
    end

    def self.named(name)
      where(["name #{like_operator} ?", name])
    end

    # TODO: make scheme-aware
    def self.named_any(list, scheme_name)
      joins(:scheme).
      where(list.map { |tag_name| sanitize_sql(["tags.name #{like_operator} ?", tag_name.to_s]) }.join(" OR ")).
      where(:schemes => { :name => scheme_name.to_s})
    end
  
    def self.named_like(name)
      where(["name #{like_operator} ?", "%#{name}%"])
    end

    def self.named_like_any(list)
      where(list.map { |tag| sanitize_sql(["name #{like_operator} ?", "%#{tag.to_s}%"]) }.join(" OR "))
    end

    ### CLASS METHODS:

    def self.find_or_create_with_like_by_name(name)
      named_like(name).first || create(:name => name)
    end

    # If the last param is a symbol, it's taken to be the scheme_name
    def self.find_or_create_all_with_like_by_name(*list)
      scheme_name = list.pop
      raise ArgumentError, "Last item must be the symbol of the scheme name" unless scheme_name.is_a? Symbol

      scheme = SemanticallyTaggable::Scheme.by_name(scheme_name)
      list = [list].flatten

      return [] if list.empty?

      existing_tags = Tag.named_any(list, scheme_name).all
      new_tag_names = list.reject do |name| 
                        name = comparable_name(name)
                        existing_tags.any? { |tag| comparable_name(tag.name) == name }
                      end
      created_tags  = new_tag_names.map { |name| Tag.create(:name => name) { |tag| tag.scheme = scheme } }

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