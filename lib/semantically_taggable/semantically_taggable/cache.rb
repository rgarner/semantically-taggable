module SemanticallyTaggable::Taggable
  # TODO: reintroduce caching support?
  module Cache
    def self.included(base)
      # Skip adding caching capabilities if table not exists or no cache columns exist
      return unless base.table_exists? && base.scheme_names.any? {
          |scheme_name| base.column_names.include?("cached_#{scheme_name.to_s.singularize}_list") }

      base.send :include, SemanticallyTaggable::Taggable::Cache::InstanceMethods
      base.extend SemanticallyTaggable::Taggable::Cache::ClassMethods
      
      base.class_eval do
        before_save :save_cached_tag_list        
      end
      
      base.initialize_semantically_taggable_cache
    end
    
    module ClassMethods
      def initialize_semantically_taggable_cache
        scheme_names.map(&:to_s).each do |scheme_name|
          class_eval %(
            def self.caching_#{scheme_name.singularize}_list?
              caching_tag_list_on?("#{scheme_name}")
            end        
          )
        end        
      end
      
      def semantically_taggable(*args)
        super(*args)
        initialize_semantically_taggable_cache
      end
      
      def caching_tag_list_on?(scheme_name)
        column_names.include?("cached_#{scheme_name.to_s.singularize}_list")
      end
    end
    
    module InstanceMethods      
      def save_cached_tag_list
        scheme_names.map(&:to_s).each do |scheme_name|
          if self.class.send("caching_#{scheme_name.singularize}_list?")
            if tag_list_cache_set_on(scheme_name)
              list = tag_list_cache_on(scheme_name.singularize).to_a.flatten.compact.join(', ')
              self["cached_#{scheme_name.singularize}_list"] = list
            end
          end
        end
        
        true
      end
    end
  end
end
