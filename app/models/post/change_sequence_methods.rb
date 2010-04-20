module PostChangeSequenceMethods
  attr_accessor :increment_change_seq
  
  def self.included(m)
    m.before_create :touch_change_seq!
    m.after_save :update_change_seq
  end
  
  def touch_change_seq!
    self.increment_change_seq = true
  end

  def update_change_seq
    return if increment_change_seq.nil?
    execute_sql("UPDATE posts SET change_seq = nextval('post_change_seq') WHERE id = ?", id)
    self.change_seq = select_value_sql("SELECT change_seq FROM posts WHERE id = ?", id)
  end
end
