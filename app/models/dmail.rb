class Dmail < ApplicationRecord
  validates_presence_of :to_id
  validates_presence_of :from_id
  validates_format_of :title, :with => /\S/
  validates_format_of :body, :with => /\S/

  belongs_to :to, :class_name => "User", :foreign_key => "to_id"
  belongs_to :from, :class_name => "User", :foreign_key => "from_id"

  after_create :update_recipient
  after_create :send_dmail

  def send_dmail
    if to.receive_dmails? && to.email.include?("@")
      UserMailer.dmail(to, from, title, body).deliver_now
    end
  end

  def mark_as_read!(current_user)
    update_attribute(:has_seen, true)

    unless Dmail.exists?(["to_id = ? AND has_seen = false", current_user.id])
      current_user.update_attribute(:has_mail, false)
    end
  end

  def update_recipient
    to.update_attribute(:has_mail, true)
  end

  def to_name
    return "" if to_id.nil?
    User.find_name(to_id)
  end

  def from_name
    User.find_name(from_id)
  end

  def to_name=(name)
    user = User.find_by_name(name)
    return if user.nil?
    self.to_id = user.id
  end

  def from_name=(name)
    user = User.find_by_name(name)
    return if user.nil?
    self.from_id = user.id
  end

  def title
    if parent_id
      return "Re: " + self[:title]
    else
      return self[:title]
    end
  end
end
