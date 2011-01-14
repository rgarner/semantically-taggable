require "spec_helper"

describe SemanticallyTaggable::Tag do
  let(:scheme) { SemanticallyTaggable::Scheme.by_name(:dg_topics) }
  let(:other_scheme) { SemanticallyTaggable::Scheme.by_name(:keywords) }

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

  describe "Tree properties of a tag" do
    describe "The unhappy path" do
      it "should not allow creation of a tag with a parent in a non-hierarchical scheme" do
        pending "To allow checkin"
        scheme = SemanticallyTaggable::Scheme.by_name(:ipsv_subjects)
        lambda { scheme.create_tag(:name => 'fail', :parent => SemanticallyTaggable::Tag.new) }.should raise_error(ArgumentError)
      end
    end

    describe "Tag relationships" do
      describe "Bidirectional associations" do
        before do
          @parent = scheme.create_tag(:name => 'Tax')
          @child = scheme.create_tag(:name => 'Income Tax')
          @unrelated = scheme.create_tag(:name => 'unrelated')
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

#        describe "when assigning from both ends, such as might happen in the import" do
#          before do
#            @parent.narrower_tags << @child
#            @child.broader_tags << @parent
#
#            @child.save
#            @parent.save
#          end
#
#          specify { @parent.should have(1).narrower_tag }
#          specify { @child.should have(1).broader_tag }
#        end
      end

      describe "Related tags" do
        before do
          @tax_tag = scheme.create_tag(:name => 'Tax')
          @income_tax_tag = scheme.create_tag(:name => 'Income Tax')
          @inheritance_tax_tag = scheme.create_tag(:name => 'Inheritance Tax')
          @giraffes = scheme.create_tag(:name => 'giraffes')

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
    let(:benefits_tag) { scheme.create_tag(:name => 'Benefits') }

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
  end
end