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

    let(:scheme) { taxonomy_tag.scheme }
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

    it "should find the root tag" do
      scheme.root_tag.should == taxonomy_tag
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

        it "should cope with all missing tags" do
          Article.tagged_with(['Not here'], :on => :dg_topics, :any => true).should be_empty
        end
      end

      describe "Indirect exclusions" do
        subject { Article.tagged_with(['Health and care', 'Travel'], :on => :dg_topics, :exclude => true) }

        its(:length) { should eql(1) }
        its(:first) { should eql(@jobs_article) }
      end

      describe "Tag counts for a schemed tag" do
        subject { SemanticallyTaggable::Tag.named('Directgov Taxonomy').first.model_counts }

        it { should eql({'Article' => 3, 'Contact' => 1}) }
      end

      describe "Counting resources" do
        it "should be able to get a summary of resources by type for a tag" do
          taxonomy_tag.model_counts.should == {'Article' => 3, 'Contact' => 1}
        end

        it "should be able to get a total of all resources for a tag" do
          taxonomy_tag.all_models_total.should == 4
        end

        describe "Summarising tags" do
          it "should be able to get a summary of all counts of all resources for a list of tags" do
            scheme.model_counts_for(
                'Health and care',
                'Travel health',
                'NHS Direct'
            ).should == {
                'Health and care' => 3,
                'NHS Direct' => 1
            }
          end

          it "should just return empty when no tags given" do
            scheme.model_counts_for().should be_empty
          end
        end
      end
    end
  end
end