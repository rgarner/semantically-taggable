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
    add_index :taggings, [:taggable_id, :taggable_type, :scheme_id]
  end

  def self.down
    drop_table :schemes
    drop_table :taggings
    drop_table :tags
  end
end
