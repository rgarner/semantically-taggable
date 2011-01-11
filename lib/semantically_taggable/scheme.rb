module SemanticallyTaggable
  ##
  # A tagging scheme in which many <code>SemanticallyTaggable::Tag</code> instances exist
  # Holds further information about the scheme - whether it's <code>polyhierarchical</code>,
  # what <code>meta</code> scheme to use when rendering tags to HTML, and what delimiter to
  # use when parsing
  class Scheme < ActiveRecord::Base
    has_many :tags

    def self.by_name(name)
      Scheme.find_by_name!(name.to_s) # || \
        #raise(ActiveRecord::RecordNotFound, "SemanticallyTaggable::Scheme with name '#{name}' not found")
    end
  end
end