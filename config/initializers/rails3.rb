# RAILS_ROOT = Rails.root

class ActiveModel::Errors
  alias :length :size
end

class ActiveRecord::Base
  alias :callback :run_callbacks
  
  def self.merge_conditions(*conditions)
    segments = []

    conditions.each do |condition|
      unless condition.blank?
        sql = sanitize_sql(condition)
        segments << sql unless sql.blank?
      end
    end

    "(#{segments.join(') AND (')})" unless segments.empty?
  end
end


# https://gist.github.com/akaspick/rails/commit/60d358b23348a14447d176fa51624ad5434eb575
class HTML::Document  
  alias :old_initialize :initialize
  def initialize(doc, *args)
    old_initialize(doc.to_s, *args)
  end
end

# http://www.rabbitcreative.com/2010/09/20/rails-3-still-fucking-up-field_with_errors/
ActionView::Base.field_error_proc = Proc.new do |html_tag, instance|
  include ActionView::Helpers::RawOutputHelper
  raw %(<span class="field_with_errors">#{html_tag}</span>)
  # include ActionView::Helpers::OutputSafetyHelper
  # safe_join ['<span class="field_with_errors">'.html_safe, html_tag, '</span>'.html_safe]
end
