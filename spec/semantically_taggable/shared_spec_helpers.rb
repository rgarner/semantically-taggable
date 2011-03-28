module SharedSpecHelpers
  def import_rdf(filename, scheme = SemanticallyTaggable::Scheme.by_name(:dg_topics))
    abridged = File.join(File.dirname(__FILE__), "testdata/#{filename}")
    scheme.import_skos(abridged) do |tag, node|
      tag.original_id = node['about'].match(%r{.*/([0-9]*)$})[1]
    end
  end
end