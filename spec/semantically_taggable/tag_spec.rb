require "spec_helper"

describe SemanticallyTaggable::Tag do
  let(:dg_topics) { SemanticallyTaggable::Scheme.by_name(:dg_topics) }
  let(:keywords) { SemanticallyTaggable::Scheme.by_name(:keywords) }

  before do
    reset_database!
  end

  describe "Finding or creating with LIKE by name" do
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

    describe "creating tags within schemes" do
      it "should save schemes with the tag" do
        SemanticallyTaggable::Tag.create!(:name => '1') do |tag|
          tag.scheme = dg_topics
        end

        tag = SemanticallyTaggable::Tag.find_by_name('1')
        tag.scheme.should == dg_topics
      end

      it "should treat tags in different schemes as different tags" do
        SemanticallyTaggable::Tag.create(:name => '1') do |tag|
          tag.scheme = dg_topics
        end

        lambda {
          SemanticallyTaggable::Tag.find_or_create_all_with_like_by_name('1', '2', :keywords)
        }.should change(SemanticallyTaggable::Tag, :count).by(2)
      end

      it "should not find tags in different schemes equal" do
        topic = SemanticallyTaggable::Tag.create(:name => '1') do |tag|
          tag.scheme = dg_topics
        end
        tag = SemanticallyTaggable::Tag.create(:name => '1') do |tag|
          tag.scheme = keywords
        end

        topic.should_not == tag
      end

      it "should silently drop tags when the scheme is set to restrict_to_known_tags" do
        tag = SemanticallyTaggable::Tag.create(:name => '1') do |tag|
          tag.scheme = dg_topics
        end

        lambda {
          SemanticallyTaggable::Tag.find_or_create_all_with_like_by_name('1', '2', :dg_topics).should == [tag]
        }.should change(SemanticallyTaggable::Tag, :count).by(0)
      end
    end
  end

  describe "Tree properties of a tag" do
    describe "Tag relationships" do
      describe "Bidirectional associations" do
        before do
          @parent = dg_topics.create_tag(:name => 'Tax')
          @child = dg_topics.create_tag(:name => 'Income Tax')
          @unrelated = dg_topics.create_tag(:name => 'unrelated')
        end

        describe "when assigning with narrower" do
          before do
            @parent.narrower_tags << @child
            @parent.save
          end

          specify { @child.broader_tags.should include(@parent) }
          specify { @parent.narrower_tags.should include(@child) }
        end

        describe "when assigning with broader" do
          before do
            @child.broader_tags << @parent
            @child.save
            @parent.reload
          end

          specify { @child.broader_tags.should include(@parent) }
          specify { @parent.narrower_tags.should include(@child) }
        end
      end

      describe "Related tags" do
        before do
          @tax_tag = dg_topics.create_tag(:name => 'Tax')
          @income_tax_tag = dg_topics.create_tag(:name => 'Income Tax')
          @inheritance_tax_tag = dg_topics.create_tag(:name => 'Inheritance Tax')
          @giraffes = dg_topics.create_tag(:name => 'giraffes')

          @tax_tag.related_tags << [@income_tax_tag, @inheritance_tax_tag]
          @tax_tag.save

          [@tax_tag, @income_tax_tag, @inheritance_tax_tag].each(&:reload)
        end

        it "should have the income tax tag related to the tax tag" do
          @tax_tag.related_tags.should include(@income_tax_tag)
        end

        it "should have the same relationship in the other direction" do
          @income_tax_tag.related_tags.should include(@tax_tag)
        end

        it "should not include giraffes in either set" do
          @tax_tag.related_tags.should_not include(@giraffes)
          @income_tax_tag.related_tags.should_not include(@giraffes)
        end

        specify { @tax_tag.should have(2).related_tags }
        specify { @income_tax_tag.should have(1).related_tag }
        specify { @inheritance_tax_tag.should have(1).related_tag }

        describe "deleting related tags" do
          before do
            @tax_tag.related_tags.first.destroy # remove income tax
            @tax_tag.save
          end

          specify { @tax_tag.should have(1).related_tag }
          specify { @inheritance_tax_tag.should have(1).related_tags }
          specify { @income_tax_tag.should have(0).related_tags }
        end
      end

    end
  end

  describe "Tag synonyms" do
    let(:benefits_tag) { dg_topics.create_tag(:name => 'Benefits') }
    let(:benefits_keyword) { keywords.create_tag(:name => 'Benefits') }

    it "should allow a tag to have synonyms" do
      benefits_tag.synonyms << SemanticallyTaggable::Synonym.new(:name => 'State Benefits')
      benefits_tag.save
      benefits_tag.reload

      benefits_tag.should have(1).synonym
    end

    it "should have a handy shorthand form for creating them" do
      lambda {
        benefits_tag.create_synonyms('State benefits', 'Another synonym for state benefits')
      }.should change(SemanticallyTaggable::Synonym, :count).by(2)
    end

    it "should discard dupes" do
      lambda { benefits_tag.create_synonyms('1','1') }.should change(SemanticallyTaggable::Synonym, :count).by(1)
    end

    it "should not cross-wire synonyms from different schemes" do
      benefits_keyword.save
      benefits_tag.save
      lambda { benefits_tag.create_synonyms('dupe') }.should change(SemanticallyTaggable::Synonym, :count).by(1)
      lambda { benefits_keyword.create_synonyms('dupe') }.should change(SemanticallyTaggable::Synonym, :count).by(1)
    end
  end
end