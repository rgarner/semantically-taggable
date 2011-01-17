require 'rails'
require 'semantically-taggable'

module SemanticallyTaggable
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.join(File.dirname(__FILE__), 'tasks/import.rake')
    end
  end
end
