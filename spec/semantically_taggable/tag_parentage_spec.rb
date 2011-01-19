require "spec_helper"

describe SemanticallyTaggable::TagParentage do
  include SharedSpecHelpers

  describe "Refreshing the closure" do
    before :all do
      reset_database!
      import_rdf('dg_abridged.rdf')
      SemanticallyTaggable::TagParentage.refresh_closure!
    end

    let(:taxonomy_tag) { SemanticallyTaggable::Tag.find_by_name('Directgov Taxonomy') }
    let(:health_and_care_tag) { SemanticallyTaggable::Tag.find_by_name('Health and care') }
    let(:travel_health_tag) { SemanticallyTaggable::Tag.find_by_name('Travel health') }
    let(:nhs_direct_tag) { SemanticallyTaggable::Tag.find_by_name('NHS Direct') }

    specify { taxonomy_tag.should parent(travel_health_tag).at_distance(2) }
    specify { taxonomy_tag.should parent(nhs_direct_tag).at_distance(3) }
    specify { health_and_care_tag.should parent(nhs_direct_tag).at_distance(2)}
  end
end