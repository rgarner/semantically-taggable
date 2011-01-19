require File.expand_path('../../spec_helper', __FILE__)

describe "Tagging articles" do
  before(:each) do
    reset_database!
    @article = Article.new(:name => "Bob Jones")
  end

  it "should have tag schemes" do
    [:keywords, :ipsv_subjects, :dg_topics].each do |name|
      Article.scheme_names.should include name
    end

    @article.scheme_names.should == Article.scheme_names
  end

  it "should have tag_counts_on" do
    Article.tag_counts_on(:keywords).all.should be_empty

    @article.keyword_list = ["awesome", "epic"]
    @article.save

    Article.tag_counts_on(:keywords).length.should == 2
    @article.tag_counts_on(:keywords).length.should == 2
  end

  it "should be able to create tags using the scheme's delimiter" do
    @article.ipsv_subject_list = "ruby; rails; css"
    @article.instance_variable_get("@ipsv_subject_list").instance_of?(SemanticallyTaggable::TagList).should be_true
    
    lambda { @article.save }.should change(SemanticallyTaggable::Tag, :count).by(3)
    
    @article.reload
    @article.ipsv_subject_list.sort.should == %w(ruby rails css).sort
  end

  it "should assign the associated scheme when tagging" do
    @article.keyword_list = %w{one two three}
    ActiveRecord::Base.logger.info "******* "
    ActiveRecord::Base.logger.info "******* ASSOCIATED SCHEME"
    ActiveRecord::Base.logger.info "******* "
    @article.save
    @article.keywords.each {|k| k.scheme.should == SemanticallyTaggable::Scheme.by_name(:keywords)}
  end
  it "should assign the associated scheme when tagging" do
    @article.keyword_list = %w{one two three}
    @article.save
    @article.keywords.each {|k| k.scheme.should == SemanticallyTaggable::Scheme.by_name(:keywords)}
  end

  it "should differentiate between schemes" do
    @article.ipsv_subject_list = "ruby, rails, css"
    @article.keyword_list = "ruby, bob, charlie"
    @article.save
    @article.reload
    @article.keyword_list.should include("ruby")
    @article.keyword_list.should_not include("rails")
  end

  it "should differentiate between schemes on tag collections too" do
    @article.keyword_list = 'foo'
    @article.ipsv_subject_list = 'bar'
    @article.save

    foo = SemanticallyTaggable::Tag.find_by_name('foo')

    @article.reload
    @article.ipsv_subjects.should_not include(foo)
  end

  it "should be able to remove tags through list alone" do
    @article.ipsv_subject_list = "ruby; rails; css"
    @article.save
    @article.reload
    @article.should have(3).ipsv_subjects
    @article.ipsv_subject_list = "ruby; rails"
    @article.save
    @article.reload
    @article.should have(2).ipsv_subjects
  end

  it "should be able to find by tag with scheme" do
    @article.ipsv_subject_list = "ruby; rails; css"
    @article.keyword_list = "bob, charlie"
    @article.save

    Article.tagged_with("bob", :on => :ipsv_subjects).first.should_not == @article
    Article.tagged_with("bob", :on => :keywords).first.should == @article
  end

  it "should not care about case" do
    Article.create(:name => "Bob", :keyword_list => "ruby")
    Article.create(:name => "Frank", :keyword_list => "Ruby")

    SemanticallyTaggable::Tag.all.size.should == 1
    Article.tagged_with("ruby", :on => :keywords).to_a.should == Article.tagged_with("Ruby", :on => :keywords).to_a
  end

  it "should be able to get tag counts on model as a whole" do
    Article.create(:name => "Bob", :keyword_list => "ruby, rails, css")
    Article.create(:name => "Frank", :keyword_list => "ruby, rails")
    Article.create(:name => "Charlie", :keyword_list => "ruby")
    Article.keyword_counts.all.should_not be_empty
  end

  it "should not return read-only records" do
    Article.create(:name => "Bob", :keyword_list => "ruby, rails, css")
    Article.tagged_with("ruby", :on => :keywords).first.should_not be_readonly
  end

  it "should be able to get scoped tag counts" do
    Article.create(:name => "Bob", :keyword_list => "ruby, rails, css")
    Article.create(:name => "Frank", :keyword_list => "ruby, rails")
    Article.create(:name => "Charlie", :ipsv_subject_list => "ruby")

    s = Article.tagged_with("ruby", :on => :keywords).keyword_counts(:order => 'tags.id')
    s.first.count.should == 2   # ruby
    Article.tagged_with("ruby", :on => :ipsv_subjects).ipsv_subject_counts.first.count.should == 1 # ruby
  end

  it "should be able to get all scoped tag counts" do
    Article.create(:name => "Bob", :keyword_list => "ruby, rails, css")
    Article.create(:name => "Frank", :keyword_list => "ruby, rails")
    Article.create(:name => "Charlie", :ipsv_subject_list => "ruby")

    Article.tagged_with("ruby", :on => :keywords).all_tag_counts(:order => 'tags.id').first.count.should == 2 # ruby
  end

  it 'should only return tag counts for the available scope' do
    bob = Article.create(:name => "Bob", :keyword_list => "ruby, rails, css")
    frank = Article.create(:name => "Frank", :keyword_list => "ruby, rails")
    charlie = Article.create(:name => "Charlie", :ipsv_subject_list => "ruby, java")
 
    Article.tagged_with('rails', :on => :keywords).all_tag_counts.should have(3).items
    Article.tagged_with('rails', :on => :keywords).all_tag_counts.any? { |tag| tag.name == 'java' }.should be_false
    
    # Test specific join syntaxes:
    frank.untaggable_models.create!
    Article.tagged_with('rails', :on => :keywords).scoped(:joins => :untaggable_models).all_tag_counts.should have(2).items
    Article.tagged_with('rails', :on => :keywords).scoped(:joins => { :untaggable_models => :article }).all_tag_counts.should have(2).items
    Article.tagged_with('rails', :on => :keywords).scoped(:joins => [:untaggable_models]).all_tag_counts.should have(2).items
  end

  it "should be able to find tagged" do
    bob = Article.create(:name => "Bob", :keyword_list => "fitter, happier, more productive", :ipsv_subject_list => "ruby; rails; css")
    frank = Article.create(:name => "Frank", :keyword_list => "weaker, depressed, inefficient", :ipsv_subject_list => "ruby; rails; css")
    steve = Article.create(:name => 'Steve', :keyword_list => 'fitter, happier, more productive', :ipsv_subject_list => 'c++; java; ruby')

    Article.tagged_with("ruby", :on => :ipsv_subjects, :order => 'articles.name').to_a.should == [bob, frank, steve]
    Article.tagged_with("ruby, rails", :on => :ipsv_subjects, :order => 'articles.name').to_a.should == [bob, frank]
    Article.tagged_with(["ruby", "rails"], :on => :ipsv_subjects, :order => 'articles.name').to_a.should == [bob, frank]
  end
  
  it "should be able to find tagged with quotation marks" do
    bob = Article.create(:name => "Bob", :keyword_list => "fitter, happier, more productive, 'I love the ,comma,'")
    Article.tagged_with("'I love the ,comma,'", :on => :keywords).should include(bob)
  end
  
  it "should be able to find tagged with invalid tags" do
    bob = Article.create(:name => "Bob", :keyword_list => "fitter, happier, more productive")    
    Article.tagged_with("sad, happier", :on => :keywords).should_not include(bob)
  end

  it "should be able to find tagged with any tag" do
    bob = Article.create(:name => "Bob", :keyword_list => "fitter, happier, more productive", :ipsv_subject_list => "ruby; rails; css")
    frank = Article.create(:name => "Frank", :keyword_list => "weaker, depressed, inefficient", :ipsv_subject_list => "ruby; rails; css")
    steve = Article.create(:name => 'Steve', :keyword_list => 'fitter, happier, more productive', :ipsv_subject_list => 'c++; java; ruby')

    Article.tagged_with(["ruby", "java"], :on => :keywords, :order => 'articles.name', :any => true).to_a.should == [bob, frank, steve]
    Article.tagged_with(["c++", "fitter"], :on => :keywords, :order => 'articles.name', :any => true).to_a.should == [bob, steve]
    Article.tagged_with(["depressed", "css"], :on => :keywords, :order => 'articles.name', :any => true).to_a.should == [bob, frank]
  end

  it "should be able to use named scopes to chain tag finds" do
    bob = Article.create(:name => "Bob", :keyword_list => "fitter, happier, more productive", :ipsv_subject_list => "ruby; rails; css")
    frank = Article.create(:name => "Frank", :keyword_list => "weaker, depressed, inefficient", :ipsv_subject_list => "ruby; rails; css")
    steve = Article.create(:name => 'Steve', :keyword_list => 'fitter, happier, more productive', :ipsv_subject_list => 'c++; java; python')

    # Let's only find those productive Rails developers
    Article.tagged_with('rails', :on => :ipsv_subjects, :order => 'articles.name').to_a.should == [bob, frank]
    Article.tagged_with('happier', :on => :keywords, :order => 'articles.name').to_a.should == [bob, steve]
    Article.tagged_with('rails', :on => :ipsv_subjects).tagged_with('happier', :on => :keywords).to_a.should == [bob]
  end

  it "should be able to find tagged with only the matching tags" do
    Article.create(:name => "Bob", :keyword_list => "lazy, happier")
    Article.create(:name => "Frank", :keyword_list => "fitter, happier, inefficient")
    steve = Article.create(:name => 'Steve', :keyword_list => "fitter, happier")

    Article.tagged_with("fitter, happier", :on => :keywords, :match_all => true).to_a.should == [steve]
  end

  it "should be able to find tagged with some excluded tags" do
    bob = Article.create(:name => "Bob", :keyword_list => "happier, lazy")
    frank = Article.create(:name => "Frank", :keyword_list => "happier")
    steve = Article.create(:name => 'Steve', :keyword_list => "happier")

    Article.tagged_with("lazy", :on => :keywords, :exclude => true).to_a.should == [frank, steve]
  end

  it "should not create duplicate taggings" do
    bob = Article.create(:name => "Bob")
    lambda {
      bob.keyword_list << "happier"
      bob.keyword_list << "happier"
      bob.save
    }.should change(SemanticallyTaggable::Tagging, :count).by(1)
  end
 
  describe "Associations" do
    before(:each) do
      @article = Article.create(:keyword_list => "awesome, epic")
    end
    
    it "should not remove tags when creating associated objects" do
      @article.untaggable_models.create!
      @article.reload
      @article.keyword_list.should have(2).items
    end
  end

  describe "grouped_column_names_for method" do
    it "should return all column names joined for Tag GROUP clause" do
      @article.grouped_column_names_for(SemanticallyTaggable::Tag).should == "tags.id, tags.name, tags.scheme_id, tags.original_id"
    end

    it "should return all column names joined for Article GROUP clause" do
      @article.grouped_column_names_for(Article).should == "articles.id, articles.name, articles.type"
    end
  end

  describe "Single Table Inheritance" do
    before do
      @article = Article.new(:name => "taggable")
      @inherited_same = InheritingArticle.new(:name => "inherited same")
      @inherited_different = AlteredInheritingArticle.new(:name => "inherited different")
    end
  
    it "should be able to save tags for inherited models" do
      @inherited_same.keyword_list = "bob, kelso"
      @inherited_same.save
      InheritingArticle.tagged_with("bob", :on => :keywords).first.should == @inherited_same
    end
  
    it "should find STI tagged models on the superclass" do
      @inherited_same.keyword_list = "bob, kelso"
      @inherited_same.save
      Article.tagged_with("bob", :on => :keywords).first.should == @inherited_same
    end
  
    it "should be able to add in schemes only to some subclasses" do
      @inherited_different.life_event_list = "birth, marriage"
      @inherited_different.save
      InheritingArticle.tagged_with("birth", :on => :life_events).should be_empty
      AlteredInheritingArticle.tagged_with("birth", :on => :life_events).first.should == @inherited_different
    end
  
    it "should have different tag_counts_on for inherited models" do
      @inherited_same.keyword_list = "bob, kelso"
      @inherited_same.save!
      @inherited_different.keyword_list = "fork, spoon"
      @inherited_different.save!
  
      InheritingArticle.tag_counts_on(:keywords, :order => 'tags.id').map(&:name).should == %w(bob kelso)
      AlteredInheritingArticle.tag_counts_on(:keywords, :order => 'tags.id').map(&:name).should == %w(fork spoon)
      Article.tag_counts_on(:keywords, :order => 'tags.id').map(&:name).should == %w(bob kelso fork spoon)
    end
  
    it 'should store same tag without validation conflict' do
      @article.keyword_list = 'one'
      @article.save!
  
      @inherited_same.keyword_list = 'one'
      @inherited_same.save!
  
      @inherited_same.update_attributes! :name => 'foo'
    end
  end
end
