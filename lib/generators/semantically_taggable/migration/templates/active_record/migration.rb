class SemanticallyTaggableMigration < ActiveRecord::Migration
  def self.up
    create_table :schemes do |t|
      t.string :name
      t.string :meta_name
      t.string :meta_scheme
      t.string :description
      t.string :delimiter, :limit => 10, :default => ','
      t.boolean :polyhierarchical, :default => false
    end

    add_index :schemes, :name, :unique => true

    create_table :tags do |t|
      t.string :name
      t.integer :scheme_id
      t.string :original_id
    end

    create_table :taggings do |t|
      t.references :tag

      # You should make sure that the column created is
      # long enough to store the required class names.
      t.references :taggable, :polymorphic => true

      t.datetime :created_at
    end

    add_index :taggings, :tag_id
    add_index :taggings, [:taggable_id, :taggable_type]

    # Transitive closure table for multiple parent tags
    # Works bidirectionally to support model.narrower_tags and model.broader_tags
    create_table :tag_parentages, :id => false, :force => true do |t|
      t.integer :parent_tag_id
      t.integer :child_tag_id
      t.integer :distance, :default => 1
    end

    add_index :tag_parentages, [:parent_tag_id, :child_tag_id, :distance], :unique => true,
              :name => 'index_tag_parentages_on_parent_child_distance'

    create_table :related_tags, :id => false, :force => true do |t|
      t.integer :tag_id
      t.integer :related_tag_id
    end

    add_index :related_tags, [:tag_id, :related_tag_id], :unique => true

    create_table :synonyms, :force => true do |t|
      t.string :name
      t.integer :tag_id
    end

    add_index :synonyms, :tag_id
  end

  def self.down
    drop_table :schemes
    drop_table :taggings
    drop_table :tags
    drop_table :tag_parentages
    drop_table :related_tags
    drop_table :synonyms
  end
end
