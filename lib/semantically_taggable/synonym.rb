module SemanticallyTaggable
  class Synonym < ActiveRecord::Base
    belongs_to :tag
    validates_uniqueness_of :name
    validates_presence_of :tag
  end
end