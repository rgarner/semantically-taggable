require "spec_helper"

describe "Importing from SKOS" do

  it "should import a small abridged SKOS scheme" do
    pending "Awaiting other implementations"
    SemanticallyTaggable::Scheme.by_name(:dg_topics).import('../dg_topics.rdf')
  end
end

describe "Tag creation" do
  before :all do
    reset_database!
  end

  set(:scheme) { SemanticallyTaggable::Scheme.by_name(:dg_topics) }
  set(:tag) do
    tag = scheme.create_tag(:name => 'Tax')
    tag.save
    tag.reload
  end

  it "should have created the tag in the scheme" do
    tag.scheme.should == scheme
  end

  it "should have the right name" do
    tag.name.should == 'Tax'
  end
end