require "spec_helper"

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

describe "Importing from SKOS" do
  include SharedSpecHelpers

  let(:scheme) { SemanticallyTaggable::Scheme.by_name(:dg_topics) }
  set(:other_scheme) { SemanticallyTaggable::Scheme.by_name(:keywords) }

  describe "Multiple roots" do
    it "should not allow two roots" do
      lambda {
        scheme.import_skos(File.join(File.dirname(__FILE__), 'testdata/dg_two_roots.rdf'))
      }.should raise_error(ArgumentError)
    end
  end

  describe "Abridged import" do
    before :all do
      reset_database!
      # Some spoilers to check we're looking in the right scheme only
      other_scheme.create_tag(:name => 'Travel')
      other_scheme.create_tag(:name => 'Job grants')
      other_scheme.create_tag(:name => 'Directgov Taxonomy')
      import_rdf('dg_abridged.rdf')
    end

    it "should have some tags" do
      scheme.tags.count.should > 0
    end

    it "should have only one root tag in this scheme" do
      scheme.root_tag.name.should == 'Directgov Taxonomy'
    end

    it "should disallow root tag requests to non-hierarchical schemes" do
      lambda { other_scheme.root_tag }.should raise_error(ArgumentError)
    end

    it "should keep original ids of concepts" do
      scheme.tags.find_by_name('Travel').original_id.should == '313'
    end

    it "should have concepts with multiple parents" do
      scheme.tags.find_by_name('Travel health').should have(2).broader_tags
    end

    it "should have concepts with multiple children" do
      scheme.root_tag.should have(3).narrower_tags
    end

    it "should have concepts with multiple synonyms" do
      scheme.tags.find_by_name('Job grants').should have(4).synonyms
    end

    it "should have concepts with multiple related tags" do
      scheme.tags.find_by_name('Health and care').should have(2).related_tags
    end
  end
end


