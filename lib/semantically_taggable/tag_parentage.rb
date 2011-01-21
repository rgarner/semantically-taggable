module SemanticallyTaggable
  class TagParentage < ActiveRecord::Base
    belongs_to :parent_tag, :class_name => 'SemanticallyTaggable::Tag'
    belongs_to :child_tag, :class_name => 'SemanticallyTaggable::Tag'

    # Refreshes the closure table across schemes
    def self.refresh_closure!
      ActiveRecord::Base.connection.execute %{DELETE FROM tag_parentages WHERE distance <> 1}

      rows_affected = 1
      total_inserts = 0
      while rows_affected > 0 do
        rows_affected = ActiveRecord::Base.connection.update %{
          INSERT IGNORE INTO tag_parentages
          SELECT DISTINCT
              p1.parent_tag_id,
              p2.child_tag_id,
              p1.distance + p2.distance
          FROM
            tag_parentages AS p1
          INNER JOIN tag_parentages AS p2 ON p1.child_tag_id = p2.parent_tag_id
        }
        total_inserts += rows_affected
      end
      total_inserts
    end

  end
end