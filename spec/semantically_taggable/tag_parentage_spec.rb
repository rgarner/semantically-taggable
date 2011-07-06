require "spec_helper"

describe SemanticallyTaggable::TagParentage do
  include SharedSpecHelpers

  describe "The transitive closure table" do
    before :all do
      reset_database!
      import_rdf('dg_abridged.rdf')
      SemanticallyTaggable::TagParentage.refresh_closure!
      ActiveRecord::Base.logger = Logger.new(STDOUT)
    end

    let(:taxonomy_tag) { SemanticallyTaggable::Tag.find_by_name('Directgov Taxonomy') }
    let(:health_and_care_tag) { SemanticallyTaggable::Tag.find_by_name('Health and care') }
    let(:travel_health_tag) { SemanticallyTaggable::Tag.find_by_name('Travel health') }
    let(:nhs_direct_tag) { SemanticallyTaggable::Tag.find_by_name('NHS Direct') }

    specify { taxonomy_tag.should parent(travel_health_tag).at_distance(2) }
    specify { taxonomy_tag.should parent(nhs_direct_tag).at_distance(3) }
    specify { health_and_care_tag.should parent(nhs_direct_tag).at_distance(2) }

    it "should not make direct connections to indirect tags through narrower_tags" do
      taxonomy_tag.narrower_tags.should_not include(nhs_direct_tag)
    end

    it "should not make direct connections to indirect tags through broader_tags" do
      nhs_direct_tag.broader_tags.should_not include(taxonomy_tag)
    end

    describe "Getting indirectly tagged articles" do
      before :all do
        @nhs_article = Article.create(:name => 'NHS Direct article', :dg_topic_list => 'NHS Direct')
        @generic_health_article = Article.create(:name => 'Health article', :dg_topic_list => 'Health and care')
        @jobs_article = Article.create(:name => 'Jobs article', :dg_topic_list => ['Job Grants', 'Directgov Taxonomy'])

        @generic_health_contact = Contact.create(:contact_point => 'Health contact', :dg_topic_list => 'Health and care')
      end

      it "should get articles tagged_with 'Health and care' when they're tagged with a sub-tag" do
        Article.tagged_with('Health and care', :on => :dg_topics).should have(2).articles
      end

      it "should get all articles for the taxonomy" do
        Article.tagged_with('Directgov taxonomy', :on => :dg_topics).uniq.should have(3).articles
      end

      describe "The :any option" do
        subject { Article.tagged_with('Health and care', :on => :dg_topics, :any => true) }

        it { should have(2).articles }
        its(:first) { should eql(@nhs_article) }
        specify do
          Article.tagged_with(['Health and care', 'Job Grants'], :on => :dg_topics, :any => true).
              should have(3).articles
        end
      end

      describe "Indirect exclusions" do
        subject { Article.tagged_with(['Health and care', 'Travel'], :on => :dg_topics, :exclude => true) }

        its(:length) { should eql(1) }
        its(:first)  { should eql(@jobs_article) }
      end

      describe "Tag counts for a schemed tag" do
        subject { SemanticallyTaggable::Tag.named('Directgov Taxonomy').first.model_counts }

        it { should eql({ 'Article' => 3, 'Contact' => 1 }) }
      end
    end
  end
end