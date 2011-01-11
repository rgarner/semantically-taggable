ENV['DB'] ||= 'mysql'

database_yml = File.expand_path('../database.yml', __FILE__)
if File.exists?(database_yml)
  active_record_configuration = YAML.load_file(database_yml)[ENV['DB']]

  ActiveRecord::Base.establish_connection(active_record_configuration)
  ActiveRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), "debug.log"))

  ActiveRecord::Base.silence do
    ActiveRecord::Migration.verbose = false

    load(File.dirname(__FILE__) + '/schema.rb')
    load(File.dirname(__FILE__) + '/models.rb')
  end

else
  raise "Please create #{database_yml} first to configure your database. Take a look at: #{database_yml}.sample"
end

def reseed_database!
  models = [
      SemanticallyTaggable::Tag, SemanticallyTaggable::Tagging, Article, OtherTaggableModel, UntaggableModel,
      SemanticallyTaggable::Scheme
  ]
  models.each do |model|
    ActiveRecord::Base.connection.execute "DELETE FROM #{model.table_name}"
  end

  SemanticallyTaggable::Scheme.create([
    {
        :name => 'dg_topics', :meta_name => 'DC.subject', :meta_scheme => 'Directgov.Topic',
        :description => 'Directgov taxonomy concept ID taggings', :delimiter => ';', :polyhierarchical => true
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
  ])

end