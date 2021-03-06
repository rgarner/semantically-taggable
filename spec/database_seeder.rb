def load_schemes!
  ActiveRecord::Base.connection.execute "DELETE FROM #{SemanticallyTaggable::Scheme.table_name}"
  SemanticallyTaggable::Scheme.create(
      [
          {
              :name => 'dg_topics', :meta_name => 'DC.subject', :meta_scheme => 'Directgov.Topic',
              :description => 'Directgov taxonomy concept ID taggings', :delimiter => ';', :polyhierarchical => true,
              :restrict_to_known_tags => true
          },
          {
              :name => 'keywords', :meta_name => 'keywords',
              :description => 'Folksonomic keyword taggings'
          },
          {
              :name => 'ipsv_subjects', :meta_name => 'DC.subject', :meta_scheme => 'eGMS.IPSV',
              :description => 'IPSV tags', :delimiter => ';'
          },
          {
              :name=> 'life_events', :meta_name => 'DC.subject', :meta_scheme => 'Directgov.LifeEvent',
              :description => "Life events"
          },
      ]
  )
end

def reset_database!
  models = [
      SemanticallyTaggable::Tag, SemanticallyTaggable::Tagging, SemanticallyTaggable::Synonym, Article, OtherTaggableModel, UntaggableModel
  ]
  models.each do |model|
    ActiveRecord::Base.connection.execute "DELETE FROM #{model.table_name}"
  end

  %w{tag_parentages}.each do |table_name|
    ActiveRecord::Base.connection.execute "DELETE FROM #{table_name}"
  end
end