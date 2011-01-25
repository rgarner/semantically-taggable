module SemanticallyTaggable
  class Synonym < ActiveRecord::Base
    belongs_to :tag
    validates_uniqueness_of :name, :scope => :tag_id
    validates_presence_of :tag
  end
end