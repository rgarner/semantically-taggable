require File.expand_path('../../spec_helper', __FILE__)

describe SemanticallyTaggable::TagsHelper do
  before(:all) do
    reset_database!

    @bob = Article.create(:name => "Inheritance tax", :keyword_list => "tax, children")
    @tom = Article.create(:name => "Income Tax", :keyword_list => "tax, income")
    @eve = Article.create(:name => "Road Tax", :keyword_list => "tax, road")
  end

  before(:each) do
    @helper = class Helper
      include SemanticallyTaggable::TagsHelper
    end.new

    @classes = {}

    @helper.tag_cloud(Article.tag_counts_on(:keywords), ["less", "prominent"]) do |tag, css_class|
      @classes[tag.name] = css_class
    end
  end

  specify { @classes["tax"].should == "prominent" }
  specify { @classes["benefits"].should be_nil }
  specify { @classes["road"].should == "less" }
  specify { @classes["children"].should == "less" }
end
