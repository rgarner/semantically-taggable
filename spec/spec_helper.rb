require 'rubygems'
require 'spork'

spec_dir = File.dirname(__FILE__)
Spork.prefork do
  # Loading more in this block will cause your tests to run faster. However, 
  # if you change any configuration or code from libraries loaded here, you'll
  # need to restart spork for it take effect.
  $LOAD_PATH << spec_dir unless $LOAD_PATH.include?(spec_dir)
  lib_path = File.expand_path(File.join(spec_dir, '../lib'))
  $LOAD_PATH << lib_path unless $LOAD_PATH.include?(lib_path)

  begin
    require "rubygems"
    require "bundler"

    if Gem::Version.new(Bundler::VERSION) <= Gem::Version.new("0.9.5")
      raise RuntimeError, "Your bundler version is too old." +
          "Run `gem install bundler` to upgrade."
    end

    # Set up load paths for all bundled gems
    Bundler.setup(:development)
  rescue Bundler::GemNotFound
    raise RuntimeError, "Bundler couldn't find some gems." +
        "Did you run `bundle install`?"
  end

  Bundler.require

  require 'rspec'
  require 'active_record'
  require File.expand_path('../../lib/semantically-taggable', __FILE__)
  require 'database_seeder'
  require 'semantically_taggable/shared_spec_helpers'


  ENV['DB'] ||= 'mysql'

  database_yml = File.expand_path('../database.yml', __FILE__)
  if File.exists?(database_yml)
    active_record_configuration = YAML.load_file(database_yml)[ENV['DB']]

    ActiveRecord::Base.establish_connection(active_record_configuration)
    ActiveRecord::Base.logger = Logger.new(File.join(spec_dir, "debug.log"))
  else
    raise "Please create #{database_yml} first to configure your database. Take a look at: #{database_yml}.sample"
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

  RSpec::Matchers.define :parent do |expected|
    match do |actual|
      sql = "SELECT * FROM tag_parentages WHERE parent_tag_id = #{actual.id} AND child_tag_id = #{expected.id} AND distance = #{@distance}"
      rows = SemanticallyTaggable::TagParentage.find_by_sql(sql)
      rows.length == 1
    end

    failure_message_for_should do
      "Expected #{actual.name} to parent #{expected.name} at a distance of #{@distance}"
    end

    chain :at_distance do |distance|
      @distance = distance
    end
  end

  unless [].respond_to?(:freq)
    class Array
      def freq
        k = Hash.new(0)
        each { |e| k[e]+=1 }
        k
      end
    end
  end
end

Spork.each_run do
  # This code will be run each time you run your specs.
  ActiveRecord::Base.silence do
    ActiveRecord::Migration.verbose = false

    load(spec_dir + '/schema.rb')
    load_schemes!
    load(spec_dir + '/models.rb')
  end

  reset_database!
end
