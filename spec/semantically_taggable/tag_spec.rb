require "spec_helper"

describe "Finding or creating with LIKE by name" do
  before :each do
    reset_database!
  end

  it "should require the last item to be the symbol of the scheme" do
    lambda {
      SemanticallyTaggable::Tag.find_or_create_all_with_like_by_name('1', '2')
    }.should raise_error(ArgumentError)
  end

  it "should fail where the scheme didn't already exist" do
    lambda {
      SemanticallyTaggable::Tag.find_or_create_all_with_like_by_name('1', '2', :somescheme)
    }.should raise_error(ActiveRecord::RecordNotFound)
  end

  it "should save schemes with the tag" do
    scheme = SemanticallyTaggable::Scheme.by_name(:dg_topics)
    keyword = SemanticallyTaggable::Tag.create(:name => '1', :scheme => scheme)
    keyword.scheme = scheme
    keyword.save!
    keyword = SemanticallyTaggable::Tag.find_by_name('1')
    keyword.scheme.should == scheme
  end

  it "should treat tags in different schemes as different tags" do
    keyword = SemanticallyTaggable::Tag.create(:name => '1', :scheme => SemanticallyTaggable::Scheme.by_name(:dg_topics))
    keyword.save!
    lambda {
      SemanticallyTaggable::Tag.find_or_create_all_with_like_by_name('1', '2', :keywords)
    }.should change(SemanticallyTaggable::Tag, :count).by(2)
  end
end