module SemanticallyTaggable
  class TagParentage < ActiveRecord::Base
    belongs_to :parent_tag, :class_name => 'SemanticallyTaggable::Tag'
    belongs_to :child_tag, :class_name => 'SemanticallyTaggable::Tag'
  end
end