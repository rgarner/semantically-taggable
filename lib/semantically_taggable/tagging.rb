module SemanticallyTaggable
  class Tagging < ::ActiveRecord::Base #:nodoc:
    attr_accessible :tag,
                    :tag_id,
                    :taggable,
                    :taggable_type,
                    :taggable_id

    belongs_to :tag, :class_name => 'SemanticallyTaggable::Tag'
    belongs_to :taggable, :polymorphic => true

    validates_presence_of :tag_id

    validates_uniqueness_of :tag_id, :scope => [ :taggable_type, :taggable_id ]
  end
end