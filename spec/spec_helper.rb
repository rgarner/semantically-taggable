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
require File.expand_path('../../lib/semantically-taggable', __FILE__)

unless [].respond_to?(:freq)
  class Array
    def freq
      k = Hash.new(0)
      each { |e| k[e]+=1 }
      k
    end
  end
end

require 'database_seeder'

reseed_database!