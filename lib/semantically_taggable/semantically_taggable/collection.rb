module SemanticallyTaggable::Taggable
  module Collection
    def self.included(base)
      base.send :include, SemanticallyTaggable::Taggable::Collection::InstanceMethods
      base.extend SemanticallyTaggable::Taggable::Collection::ClassMethods
      base.initialize_semantically_taggable_collection
    end
    
    module ClassMethods
      def initialize_semantically_taggable_collection
        scheme_names.map(&:to_s).each do |scheme_name|
          class_eval %(
            def self.#{scheme_name.singularize}_counts(options={})
              tag_counts_on('#{scheme_name}', options)
            end

            def #{scheme_name.singularize}_counts(options = {})
              tag_counts_on('#{scheme_name}', options)
            end

            def top_#{scheme_name}(limit = 10)
              tag_counts_on('#{scheme_name}', :order => 'count desc', :limit => limit.to_i)
            end

            def self.top_#{scheme_name}(limit = 10)
              tag_counts_on('#{scheme_name}', :order => 'count desc', :limit => limit.to_i)
            end        
          )
        end        
      end
      
      def semantically_taggable(*args)
        super(*args)
        initialize_semantically_taggable_collection
      end
      
      def tag_counts_on(scheme_name, options = {})
        all_tag_counts(options.merge({:on => scheme_name.to_s}))
      end
      
      ##
      # Calculate the tag counts for all tags.
      #
      # @param [Hash] options Options:
      #                       * :start_at   - Restrict the tags to those created after a certain time
      #                       * :end_at     - Restrict the tags to those created before a certain time
      #                       * :conditions - A piece of SQL conditions to add to the query
      #                       * :limit      - The maximum number of tags to return
      #                       * :order      - A piece of SQL to order by. Eg 'tags.count desc' or 'taggings.created_at desc'
      #                       * :at_least   - Exclude tags with a frequency less than the given value
      #                       * :at_most    - Exclude tags with a frequency greater than the given value
      #                       * :on         - Scope the find to only include a certain scheme name
      def all_tag_counts(options = {})
        options.assert_valid_keys :start_at, :end_at, :conditions, :at_least, :at_most, :order, :limit, :on, :id

        scope = {}

        ## Generate conditions:
        options[:conditions] = sanitize_sql(options[:conditions]) if options[:conditions]     
        scheme_name = options.delete(:on)

        start_at_conditions = sanitize_sql(["#{SemanticallyTaggable::Tagging.table_name}.created_at >= ?", options.delete(:start_at)]) if options[:start_at]
        end_at_conditions   = sanitize_sql(["#{SemanticallyTaggable::Tagging.table_name}.created_at <= ?", options.delete(:end_at)])   if options[:end_at]
        
        taggable_conditions  = sanitize_sql(["#{SemanticallyTaggable::Tagging.table_name}.taggable_type = ?", base_class.name])
        taggable_conditions << sanitize_sql([" AND #{SemanticallyTaggable::Tagging.table_name}.taggable_id = ?", options.delete(:id)])  if options[:id]
        taggable_conditions << sanitize_sql([" AND #{SemanticallyTaggable::Scheme.table_name}.name = ?", scheme_name]) if scheme_name

        tagging_conditions = [
          taggable_conditions,
          scope[:conditions],
          start_at_conditions,
          end_at_conditions
        ].compact.reverse
        
        tag_conditions = [
          options[:conditions]        
        ].compact.reverse
        
        ## Generate joins:
        taggable_join = "INNER JOIN #{table_name} ON #{table_name}.#{primary_key} = #{SemanticallyTaggable::Tagging.table_name}.taggable_id"
        taggable_join << " AND #{table_name}.#{inheritance_column} = '#{name}'" unless descends_from_active_record? # Current model is STI descendant, so add type checking to the join condition
        if scheme_name
          taggable_join << " INNER JOIN tags on tags.id = taggings.tag_id "
          taggable_join << " INNER JOIN schemes on schemes.id = tags.scheme_id "
        end

        tagging_joins = [
          taggable_join,
          scope[:joins]
        ].compact

        tag_joins = [
        ].compact

        [tagging_joins, tag_joins].each(&:reverse!) if ActiveRecord::VERSION::MAJOR < 3

        ## Generate scope:
        tagging_scope = SemanticallyTaggable::Tagging.select("#{SemanticallyTaggable::Tagging.table_name}.tag_id, COUNT(#{SemanticallyTaggable::Tagging.table_name}.tag_id) AS tags_count")
        tag_scope = SemanticallyTaggable::Tag.select("#{SemanticallyTaggable::Tag.table_name}.*, #{SemanticallyTaggable::Tagging.table_name}.tags_count AS count").order(options[:order]).limit(options[:limit])

        # Joins and conditions
        tagging_joins.each      { |join|      tagging_scope = tagging_scope.joins(join)      }        
        tagging_conditions.each { |condition| tagging_scope = tagging_scope.where(condition) }

        tag_joins.each          { |join|      tag_scope     = tag_scope.joins(join)          }
        tag_conditions.each     { |condition| tag_scope     = tag_scope.where(condition)     }

        # GROUP BY and HAVING clauses:
        at_least  = sanitize_sql(['tags_count >= ?', options.delete(:at_least)]) if options[:at_least]
        at_most   = sanitize_sql(['tags_count <= ?', options.delete(:at_most)]) if options[:at_most]
        having    = ["COUNT(#{SemanticallyTaggable::Tagging.table_name}.tag_id) > 0", at_least, at_most].compact.join(' AND ')

        group_columns = "#{SemanticallyTaggable::Tagging.table_name}.tag_id"

        # Append the current scope to the scope, because we can't use scope(:find) in RoR 3.0 anymore:
        scoped_select = "#{table_name}.#{primary_key}"
        tagging_scope = tagging_scope.where("taggings.taggable_id IN(#{select(scoped_select).to_sql})").
                                      group(group_columns).
                                      having(having)

        tag_scope = tag_scope.joins("JOIN (#{tagging_scope.to_sql}) AS taggings ON taggings.tag_id = tags.id")
        tag_scope
      end
    end
    
    module InstanceMethods
      def tag_counts_on(scheme_name, options={})
        self.class.tag_counts_on(scheme_name, options.merge(:id => id))
      end
    end
  end
end