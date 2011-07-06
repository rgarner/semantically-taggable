ActiveRecord::Schema.define :version => 0 do

  # semantically-taggable tables

  create_table "taggings", :force => true do |t|
    t.integer  "tag_id",        :limit => 11
    t.integer  "taggable_id",   :limit => 11
    t.string   "taggable_type"
    t.datetime "created_at"
  end

  add_index "taggings", ["tag_id"], :name => "index_taggings_on_tag_id"
  add_index "taggings", ["taggable_id", "taggable_type"], :name => "index_taggings_on_taggable_id_and_taggable_type"

  create_table "tags", :force => true do |t|
    t.string "name"
    t.integer "scheme_id"
    t.string "original_id"
  end

  add_index "tags", ["scheme_id"]
  add_index "tags", ["name"]

  create_table :schemes, :force => true do |t|
    t.string :name
    t.string :meta_name
    t.string :meta_scheme
    t.string :description
    t.string :delimiter, :limit => 10, :default => ','
    t.boolean :polyhierarchical, :default => false
    t.boolean :restrict_to_known_tags, :default => false
  end

  # Transitive closure table for multiple parent tags
  create_table :tag_parentages, :id => false, :force => true do |t|
    t.integer :parent_tag_id
    t.integer :child_tag_id
    t.integer :distance, :default => 1
  end

  add_index :tag_parentages, :parent_tag_id
  add_index :tag_parentages, :child_tag_id
  add_index :tag_parentages, [:parent_tag_id, :child_tag_id, :distance], :unique => :true, :name => 'index_tag_parentages_on_parent_child_distance'

  create_table :related_tags, :id => false, :force => true do |t|
    t.integer :tag_id
    t.integer :related_tag_id
  end

  add_index :related_tags, [:tag_id, :related_tag_id], :uniq => :true

  create_table :synonyms, :force => true do |t|
    t.string :name
    t.integer :tag_id
  end

  add_index :synonyms, :tag_id

  # Tables for testing models from here on in

  create_table :articles, :force => true do |t|
    t.column :name, :string
    t.column :type, :string
  end

  create_table :contacts, :force => true do |t|
    t.column :contact_point, :string
  end
  
  create_table :untaggable_models, :force => true do |t|
    t.column :article_id, :integer
    t.column :name, :string
  end
  
  create_table :cached_models, :force => true do |t|
    t.column :name, :string
    t.column :type, :string
    t.column :cached_tag_list, :string
  end
  
  create_table :taggable_users, :force => true do |t|
    t.column :name, :string
  end
  
  create_table :other_taggable_models, :force => true do |t|
    t.column :name, :string
    t.column :type, :string
  end
end
