module SemanticallyTaggable
  module Taggable
    def taggable?
      false
    end

    ##
    # Make a model taggable in a specified scheme.
    #
    # @param [Array] scheme_names An array of taggable scheme names (must exist in Scheme model)
    #
    # Example:
    #   class User < ActiveRecord::Base
    #     semantically_taggable :languages, :skills
    #   end
    def semantically_taggable(*scheme_names)
      scheme_names = scheme_names.to_a.flatten.compact.map(&:to_sym)

      if taggable?
        write_inheritable_attribute(:scheme_names, (self.scheme_names + scheme_names).uniq)
      else
        write_inheritable_attribute(:scheme_names, scheme_names)
        class_inheritable_reader(:scheme_names)

        class_eval do
          has_many :taggings, :as => :taggable, :dependent => :destroy, :include => :tag, :class_name => "SemanticallyTaggable::Tagging"
          has_many :base_tags, :through => :taggings, :source => :tag, :class_name => "SemanticallyTaggable::Tag"

          def self.taggable?
            true
          end

          include SemanticallyTaggable::Taggable::Core
          include SemanticallyTaggable::Taggable::Collection
# TODO: reintroduce caching support
#          include SemanticallyTaggable::Taggable::Cache
        end
      end
    end
  end
end
