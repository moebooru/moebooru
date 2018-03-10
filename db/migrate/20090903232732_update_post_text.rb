class UpdatePostText < ActiveRecord::Migration[5.1]
  def self.up
    Comment.find(:all, :conditions => ["body ILIKE '%%<i>%%' OR body ILIKE '%%<b>%%'"]).each do |comment|
      comment.body = comment.body.gsub(/<i>/i, "[i]")
      comment.body = comment.body.gsub(/<\/i>/i, "[/i]")
      comment.body = comment.body.gsub(/<b>/i, "[b]")
      comment.body = comment.body.gsub(/<\/b>/i, "[/b]")
      comment.save!
    end
  end

  def self.down
    Comment.find(:all, :conditions => ["body ILIKE '%%[i]%%' OR body ILIKE '%%[b]%%'"]).each do |comment|
      comment.body = comment.body.gsub(/[i]/i, "<i>")
      comment.body = comment.body.gsub(/[\/i]/i, "</i>")
      comment.body = comment.body.gsub(/[b]/i, "<b>")
      comment.body = comment.body.gsub(/[\/b]/i, "</b>")
      comment.save!
    end
  end
end
