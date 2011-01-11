module SemanticallyTaggable::Taggable
  module Core
    def self.included(base)
      base.send :include, SemanticallyTaggable::Taggable::Core::InstanceMethods
      base.extend SemanticallyTaggable::Taggable::Core::ClassMethods

      base.class_eval do
        attr_writer :custom_scheme_names
        after_save :save_tags
      end
      
      base.initialize_semantically_taggable_core
    end
    
    module ClassMethods
      def initialize_semantically_taggable_core
        scheme_names.map(&:to_s).each do |scheme_name|
          singular_scheme_name  = scheme_name.to_s.singularize
          context_taggings      = "#{singular_scheme_name}_taggings".to_sym
          context_tags          = scheme_name.to_sym

          class_eval do
            has_many context_taggings, :as => :taggable, :dependent => :destroy, :include => :tag, :class_name => "SemanticallyTaggable::Tagging"
            has_many context_tags, :through => context_taggings, :source => :tag, :class_name => "SemanticallyTaggable::Tag"
          end

          class_eval %(
            def #{singular_scheme_name}_list
              tag_list_on('#{scheme_name}')
            end

            def #{singular_scheme_name}_list=(new_tags)
              set_tag_list_on('#{scheme_name}', new_tags)
            end

            def all_#{scheme_name}_list
              all_tags_list_on('#{scheme_name}')
            end
          )
        end        
      end
      
      def semantically_taggable(*args)
        super(*args)
        initialize_semantically_taggable_core
      end
      
      # all column names are necessary for PostgreSQL group clause
      def grouped_column_names_for(object)
        object.column_names.map { |column| "#{object.table_name}.#{column}" }.join(", ")
      end

      ##
      # Return a scope of objects that are tagged with the specified tags.
      #
      # @param tags The tags that we want to query for
      # @param [Hash] options A hash of options to alter you query:
      #                       * <tt>:exclude</tt> - if set to true, return objects that are *NOT* tagged with the specified tags
      #                       * <tt>:any</tt> - if set to true, return objects that are tagged with *ANY* of the specified tags
      #                       * <tt>:match_all</tt> - if set to true, return objects that are *ONLY* tagged with the specified tags
      #
      # Example:
      #   User.tagged_with("awesome", "cool")                     # Users that are tagged with awesome and cool
      #   User.tagged_with("awesome", "cool", :exclude => true)   # Users that are not tagged with awesome or cool
      #   User.tagged_with("awesome", "cool", :any => true)       # Users that are tagged with awesome or cool
      #   User.tagged_with("awesome", "cool", :match_all => true) # Users that are tagged with just awesome and cool
      def tagged_with(tags, options = {})
        scheme_name = options.delete(:on)
        raise ArgumentError, 'tagged_with requires :on' unless scheme_name

        tag_list = SemanticallyTaggable::TagList.from(tags)

        return {} if tag_list.empty?

        joins = []
        conditions = []


        if options.delete(:exclude)
          tags_conditions = tag_list.map { |t| sanitize_sql(["tags.name LIKE ?", t]) }.join(" OR ")
          conditions << "#{table_name}.#{primary_key} NOT IN (SELECT #{SemanticallyTaggable::Tagging.table_name}.taggable_id FROM taggings JOIN tags ON taggings.tag_id = tags.id AND (#{tags_conditions}) WHERE taggings.taggable_type = #{quote_value(base_class.name)})"

        elsif options.delete(:any)
          tags_conditions = tag_list.map { |t| sanitize_sql(["tags.name LIKE ?", t]) }.join(" OR ")
          conditions << "#{table_name}.#{primary_key} IN (SELECT taggings.taggable_id FROM taggings JOIN tags ON taggings.tag_id = tags.id AND (#{tags_conditions}) WHERE taggings.taggable_type = #{quote_value(base_class.name)})"

        else
          tags = SemanticallyTaggable::Tag.named_any(tag_list, scheme_name)
          return scoped(:conditions => "1 = 0") unless tags.length == tag_list.length

          tags.each do |tag|
            safe_tag = tag.name.gsub(/[^a-zA-Z0-9]/, '')
            prefix   = "#{safe_tag}_#{rand(1024)}"

            taggings_alias = "#{undecorated_table_name}_taggings_#{prefix}"

            tagging_join  = "JOIN #{SemanticallyTaggable::Tagging.table_name} #{taggings_alias}" +
                            "  ON #{taggings_alias}.taggable_id = #{table_name}.#{primary_key}" +
                            " AND #{taggings_alias}.taggable_type = #{quote_value(base_class.name)}" +
                            " AND #{taggings_alias}.tag_id = #{tag.id}"

            joins << tagging_join
          end
        end

        taggings_alias = "#{undecorated_table_name}_taggings_group"

        if options.delete(:match_all)
          joins << "LEFT OUTER JOIN #{SemanticallyTaggable::Tagging.table_name} #{taggings_alias}" +
                   "  ON #{taggings_alias}.taggable_id = #{table_name}.#{primary_key}" +
                   " AND #{taggings_alias}.taggable_type = #{quote_value(base_class.name)}"


          group_columns = SemanticallyTaggable::Tag.using_postgresql? ? grouped_column_names_for(self) : "#{table_name}.#{primary_key}"
          group = "#{group_columns} HAVING COUNT(#{taggings_alias}.taggable_id) = #{tags.size}"
        end


        scoped(:joins      => joins.join(" "),
               :group      => group,
               :conditions => conditions.join(" AND "),
               :order      => options[:order],
               :readonly   => false)
      end

      def is_taggable?
        true
      end
    end    
    
    module InstanceMethods
      # all column names are necessary for PostgreSQL group clause
      def grouped_column_names_for(object)
        self.class.grouped_column_names_for(object)
      end

      def custom_scheme_names
        @custom_scheme_names ||= []
      end

      def is_taggable?
        self.class.is_taggable?
      end

      def add_custom_scheme_name(value)
        custom_scheme_names << value.to_s unless custom_scheme_names.include?(value.to_s) or self.class.scheme_names.map(&:to_s).include?(value.to_s)
      end

      def cached_tag_list_on(scheme_name)
        self["cached_#{scheme_name.to_s.singularize}_list"]
      end

      def tag_list_cache_set_on(scheme_name)
        variable_name = "@#{scheme_name.to_s.singularize}_list"
        !instance_variable_get(variable_name).nil?
      end

      def tag_list_cache_on(scheme_name)
        variable_name = "@#{scheme_name.to_s.singularize}_list"
        instance_variable_get(variable_name) || instance_variable_set(variable_name, SemanticallyTaggable::TagList.new(tags_on(scheme_name).map(&:name)))
      end

      def tag_list_on(scheme_name)
        add_custom_scheme_name(scheme_name)
        tag_list_cache_on(scheme_name)
      end

      def all_tags_list_on(scheme_name)
        variable_name = "@all_#{scheme_name.to_s.singularize}_list"
        return instance_variable_get(variable_name) if instance_variable_get(variable_name)

        instance_variable_set(variable_name, SemanticallyTaggable::TagList.new(all_tags_on(scheme_name).map(&:name)).freeze)
      end

      ##
      # Returns all tags of a given context
      def all_tags_on(scheme_name)
        tagging_table_name = SemanticallyTaggable::Tagging.table_name

        opts  =  ["#{tagging_table_name}.context = ?", scheme_name.to_s]
        scope = base_tags.where(opts)
        
        if SemanticallyTaggable::Tag.using_postgresql?
          group_columns = grouped_column_names_for(SemanticallyTaggable::Tag)
          scope = scope.order("max(#{tagging_table_name}.created_at)").group(group_columns)
        else
          scope = scope.group("#{SemanticallyTaggable::Tag.table_name}.#{SemanticallyTaggable::Tag.primary_key}")
        end

        scope.all
      end

      ##
      # Returns all tags in a given scheme
      def tags_on(scheme_name)
        base_tags.joins(:scheme).where(["schemes.name = ?", scheme_name.to_s]).all
      end

      def set_tag_list_on(scheme_name, new_list)
        add_custom_scheme_name(scheme_name)

        variable_name = "@#{scheme_name.to_s.singularize}_list"
        instance_variable_set(variable_name, SemanticallyTaggable::TagList.from(new_list))
      end

      def tagging_scheme_names
        custom_scheme_names + self.class.scheme_names.map(&:to_s)
      end

      def reload(*args)
        self.class.scheme_names.each do |scheme_name|
          instance_variable_set("@#{scheme_name.to_s.singularize}_list", nil)
          instance_variable_set("@all_#{scheme_name.to_s.singularize}_list", nil)
        end
      
        super(*args)
      end

      def save_tags
        tagging_scheme_names.each do |scheme_name|
          next unless tag_list_cache_set_on(scheme_name)

          tag_list = tag_list_cache_on(scheme_name).uniq

          # Find existing tags or create non-existing tags:
          tag_list = SemanticallyTaggable::Tag.find_or_create_all_with_like_by_name(tag_list, scheme_name.to_sym)

          current_tags = tags_on(scheme_name)
          old_tags     = current_tags - tag_list
          new_tags     = tag_list     - current_tags
          
          # Find taggings to remove:
          old_taggings = taggings.joins(:tag => :scheme) \
            .where(:schemes => { :name => scheme_name.to_s}, :tag_id => old_tags).all

          if old_taggings.present?
            # Destroy old taggings:
            SemanticallyTaggable::Tagging.destroy_all :id => old_taggings.map(&:id)
          end

          # Create new taggings:
          new_tags.each do |tag|
            taggings.create!(:tag_id => tag.id, :taggable => self)
          end
        end

        true
      end
    end
  end
end