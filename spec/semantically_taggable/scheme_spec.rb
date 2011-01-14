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

def import_rdf filename
  abridged = File.join(File.dirname(__FILE__), "testdata/#{filename}")
  scheme.import_skos(abridged) do |tag, node|
    tag.original_id = node['resource'].match(%r{.*/([0-9]*)$})[1]
  end
end

describe "Importing from SKOS" do
  let(:scheme) { SemanticallyTaggable::Scheme.by_name(:dg_topics) }

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
      import_rdf('dg_abridged.rdf')
    end

    let(:root_tag) { SemanticallyTaggable::Tag.find_by_name('Directgov taxonomy') }

    it "should have some tags" do
      SemanticallyTaggable::Tag.count.should > 0
    end

    it "should have only one root tag in this scheme" do
      pending "What's the interface for finding a root tag in a poly scheme?"
    end

    it "should keep original ids of concepts" do
      SemanticallyTaggable::Tag.find_by_name('Travel').original_id.should == '313'
    end

    it "should have concepts with multiple parents" do
      SemanticallyTaggable::Tag.find_by_name('Travel health').should have(2).broader_tags
    end

    it "should have concepts with multiple children" do
      root_tag.should have(4).narrower_tags
    end

    it "should have concepts with multiple synonyms" do
      SemanticallyTaggable::Tag.find_by_name('Job grants').should have(4).synonyms
    end

    it "should have concepts with multiple related tags" do
      SemanticallyTaggable::Tag.find_by_name('Health and care').should have(2).related_tags
    end
  end
end


