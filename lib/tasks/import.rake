namespace :import do
  desc "Import a SKOS thesaurus"
  task :skos, :scheme_name, :skos_filename, :needs => :environment do |t, args|
    scheme = SemanticallyTaggable::Scheme.by_name args.scheme_name
    scheme.import_skos(args.skos_filename) do |tag, node|
      # Extract original_id from the rdf:resource URI
      tag.original_id = node['resource'].match(%r{.*/([0-9]*)$})[1]
    end
  end

  desc "Refresh the tag_parentages table closure for indirect hierarchy tagging support"
  task :refresh_closure => :environment do
    SemanticallyTaggable::TagParentage.refresh_closure!
  end
end