require 'rails'
require 'semantically-taggable'

module SemanticallyTaggable
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.join(File.dirname(__FILE__), 'tasks/import.rake')
    end

    unless defined? SEMANTICALLYTAGGABLE_SPECRUNNING
      # No idea why this loads too late if it's a railtie initializer
      ActiveSupport.on_load :active_record do
        # Workaround for semantically-taggable's habtm
        database_yml = File.expand_path('config/database.yml')
        if File.exists?(database_yml)
          active_record_configuration = YAML.load_file(database_yml)[Rails.env]
          ActiveRecord::Base.establish_connection(active_record_configuration)
        else
          raise "Please create #{database_yml} first to configure your database."
        end
      end
    end
  end
end
