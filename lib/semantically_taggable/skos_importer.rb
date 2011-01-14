module SemanticallyTaggable
  class SkosImporter
    def initialize(skos_filename, scheme)
      @doc = Nokogiri::XML(File.read(skos_filename))
      @scheme = scheme
      @concept_urls = {}
    end

    def import &block
      raise ArgumentError, "Can't import SKOS for non-hierarchical schemes" unless @scheme.polyhierarchical?
      root_nodes = @doc.xpath('//skos:Concept[not(skos:broader)]')
      raise ArgumentError, "Expected only one root, got #{root_nodes.length}" unless root_nodes.length == 1

      import_concepts &block
      import_relations :narrower, :broader, :related
      import_synonyms
    end

    def import_synonyms
      iterate_concepts do |concept, label|
        tag = SemanticallyTaggable::Tag.find_by_name label
        tag.create_synonyms(concept.xpath('skos:altLabel').collect(&:content))
      end
    end

    def import_relations(*relations)
      relations.each do |relation|
        iterate_concepts do |concept, label|
          tag = SemanticallyTaggable::Tag.find_by_name label
          skos_element = "skos:#{relation}"
          others = concept.xpath(skos_element).collect { |other_node| lookup_tag(other_node) }
          tag.send("#{relation}_tags=".to_sym, others)
        end
      end
    end

    def import_concepts(&block)
      iterate_concepts do |concept, label|
        @scheme.create_tag(:name => label) do |tag|
          block.call tag, concept if block
        end
      end
    end

    private
    def iterate_concepts
      concepts = @doc.xpath('//skos:Concept')
      concepts.each do |concept|
        pref_label = concept.at_xpath('skos:prefLabel').content
        yield concept, pref_label
      end
    end

    def lookup_tag(pointer_node)
      url_xpath = "//skos:Concept[@rdf:resource='#{pointer_node['resource']}']"
      concept_node = pointer_node.at_xpath(url_xpath) || (raise RuntimeError, "Concept at #{url_xpath} not found")
      pref_label = concept_node.at_xpath('skos:prefLabel').content
      Tag.find_by_name pref_label
    end
  end
end