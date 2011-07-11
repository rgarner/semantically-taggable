class Article < ActiveRecord::Base
  semantically_taggable :ipsv_subjects
  semantically_taggable :keywords, :dg_topics
  has_many :untaggable_models
end

class Contact < ActiveRecord::Base
  semantically_taggable :keywords, :dg_topics
end

class CachedModel < ActiveRecord::Base
  semantically_taggable :keywords
end

class OtherTaggableModel < ActiveRecord::Base
#  semantically_taggable :tags, :languages
#  semantically_taggable :needs, :offerings
end

class InheritingArticle < Article
end

class AlteredInheritingArticle < Article
  semantically_taggable :life_events
end

class UntaggableModel < ActiveRecord::Base
  belongs_to :article
end