require File.expand_path('../../spec_helper', __FILE__)

describe "Semantically Taggable" do
  before(:each) do
    reseed_database!
  end

  it "should provide a class method 'taggable?' that is false for untaggable models" do
    UntaggableModel.should_not be_taggable
  end

  describe "Taggable Method Generation" do
    before(:each) do
      reseed_database!
      Article.write_inheritable_attribute :scheme_names, []

      Article.semantically_taggable :keywords, :dg_topics, :ipsv_subjects

      @taggable = Article.new(:name => "Bob Jones")
    end

    it "should respond 'true' to taggable?" do
      @taggable.class.should be_taggable
    end

    it "should create a class attribute for tag types" do
      @taggable.class.should respond_to(:scheme_names)
    end

    it "should not create an instance attribute for tag types" do
      @taggable.should_not respond_to(:tag_types)
    end

    it "should instead respond to scheme names" do
      @taggable.should respond_to(:scheme_names)
    end

    it "should have all tag schemes" do
      @taggable.scheme_names.should == [:keywords, :dg_topics, :ipsv_subjects]
    end

    it "should generate an association for each scheme" do
      @taggable.should respond_to(:keywords, :dg_topics, :ipsv_subjects)
    end

    it "should add tagged_with to singleton" do
      Article.should respond_to(:tagged_with)
    end

    it "should generate a tag_list accessor/setter for each tag type" do
      @taggable.should respond_to(:keyword_list, :dg_topic_list, :ipsv_subject_list)
      @taggable.should respond_to(:keyword_list=, :dg_topic_list=, :ipsv_subject_list=)
    end

    it "should not generate a tag_list accessor, that includes owned tags, for each tag type" do
      @taggable.should respond_to(:all_keywords_list, :all_ipsv_subjects_list, :all_dg_topics_list)
    end
  end

  describe "Reloading" do
    it "should save a model instantiated by Model.find" do
      taggable = Article.create!(:name => "Taggable")
      found_taggable = Article.find(taggable.id)
      found_taggable.save
    end
  end

  describe 'Tagging Contexts' do
    it 'should eliminate duplicate tagging contexts ' do
      Article.semantically_taggable(:skills, :skills)
      Article.scheme_names.freq[:skills].should_not == 3
    end

    it "should not contain embedded/nested arrays" do
      Article.semantically_taggable([:array], [:array])
      Article.scheme_names.freq[[:array]].should == 0
    end

    it "should _flatten_ the content of arrays" do
      Article.semantically_taggable([:array], [:array])
      Article.scheme_names.freq[:array].should == 1
    end

    it "should not raise an error when passed nil" do
      lambda {
        Article.semantically_taggable()
      }.should_not raise_error
    end

    it "should not raise an error when passed [nil]" do
      lambda {
        Article.semantically_taggable([nil])
      }.should_not raise_error
    end
  end

#  describe 'Caching' do
#    before(:each) do
#      @taggable = CachedModel.new(:name => "Bob Jones")
#    end
#
#    it "should add saving of tag lists and cached tag lists to the instance" do
#      @taggable.should respond_to(:save_cached_tag_list)
#      @taggable.should respond_to(:save_tags)
#    end
#
#    it "should generate a cached column checker for each tag type" do
#      CachedModel.should respond_to(:caching_tag_list?)
#    end
#
#    it 'should not have cached tags' do
#      @taggable.cached_tag_list.should be_blank
#    end
#
#    it 'should cache tags' do
#      @taggable.update_attributes(:tag_list => 'awesome, epic')
#      @taggable.cached_tag_list.should == 'awesome, epic'
#    end
#
#    it 'should keep the cache' do
#      @taggable.update_attributes(:tag_list => 'awesome, epic')
#      @taggable = CachedModel.find(@taggable)
#      @taggable.save!
#      @taggable.cached_tag_list.should == 'awesome, epic'
#    end
#
#    it 'should update the cache' do
#      @taggable.update_attributes(:tag_list => 'awesome, epic')
#      @taggable.update_attributes(:tag_list => 'awesome')
#      @taggable.cached_tag_list.should == 'awesome'
#    end
#
#    it 'should remove the cache' do
#      @taggable.update_attributes(:tag_list => 'awesome, epic')
#      @taggable.update_attributes(:tag_list => '')
#      @taggable.cached_tag_list.should be_blank
#    end
#
#    it 'should have a tag list' do
#      @taggable.update_attributes(:tag_list => 'awesome, epic')
#      @taggable = CachedModel.find(@taggable.id)
#      @taggable.tag_list.sort.should == %w(awesome epic).sort
#    end
#
#    it 'should keep the tag list' do
#      @taggable.update_attributes(:tag_list => 'awesome, epic')
#      @taggable = CachedModel.find(@taggable.id)
#      @taggable.save!
#      @taggable.tag_list.sort.should == %w(awesome epic).sort
#    end
#  end

end
