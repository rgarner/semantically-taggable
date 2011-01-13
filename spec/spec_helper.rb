$LOAD_PATH << "." unless $LOAD_PATH.include?(".")

begin
  require "rubygems"
  require "bundler"

  if Gem::Version.new(Bundler::VERSION) <= Gem::Version.new("0.9.5")
    raise RuntimeError, "Your bundler version is too old." +
        "Run `gem install bundler` to upgrade."
  end

  # Set up load paths for all bundled gems
  Bundler.setup
rescue Bundler::GemNotFound
  raise RuntimeError, "Bundler couldn't find some gems." +
      "Did you run `bundle install`?"
end

Bundler.require

require 'active_record'

ENV['DB'] ||= 'mysql'

database_yml = File.expand_path('../database.yml', __FILE__)
if File.exists?(database_yml)
  active_record_configuration = YAML.load_file(database_yml)[ENV['DB']]

  ActiveRecord::Base.establish_connection(active_record_configuration)
  ActiveRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), "debug.log"))
else
  raise "Please create #{database_yml} first to configure your database. Take a look at: #{database_yml}.sample"
end

require File.expand_path('../../lib/semantically-taggable', __FILE__)
require 'database_seeder'

unless [].respond_to?(:freq)
  class Array
    def freq
      k = Hash.new(0)
      each { |e| k[e]+=1 }
      k
    end
  end
end

# Set @@variable_name in a before(:all) block and give access to it
# via let(:variable_name)
#
# Example:
# describe Transaction do
# set(:transaction) { Factory(:transaction) }
#
# it "should be in progress" do
# transaction.state.should == 'in_progress'
# end
# end
def set(variable_name, &block)
  before(:all) do
    self.class.send(:class_variable_set, "@@#{variable_name}".to_sym, instance_eval(&block))
  end

  let(variable_name) do
    self.class.send(:class_variable_get, "@@#{variable_name}".to_sym).tap do |i|
      if i.respond_to?(:new_record?)
        i.reload unless i.new_record?
      end
    end
  end
end

ActiveRecord::Base.silence do
  ActiveRecord::Migration.verbose = false

  load(File.dirname(__FILE__) + '/schema.rb')
  load_schemes!
  load(File.dirname(__FILE__) + '/models.rb')
end

reset_database!