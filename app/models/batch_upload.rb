class BatchUpload < ActiveRecord::Base
  belongs_to :user

  def data
    JSON.parse(data_as_json)
  end

  def data=(hoge)
    self.data_as_json = hoge.to_json
  end

  def run
    self.active = true
    self.save!

    @post = Post.create({:source => self.url, :tags => self.tags, :updater_user_id => self.user_id, :updater_ip_addr => self.ip, :user_id => self.user_id, :ip_addr => self.ip, :status => "active"})

    if @post.errors.empty?
      if CONFIG["dupe_check_on_upload"] && @post.image? && @post.parent_id.nil?
        options = { :services => SimilarImages.get_services("local"), :type => :post, :source => @post }

        res = SimilarImages.similar_images(options)
        if not res[:posts].empty?
          @post.tags = @post.tags + " possible_duplicate"
          @post.save!
        end
      end

      self.data = { :success => true, :post_id => @post.id }
    elsif @post.errors.invalid?(:md5)
      p @post.errors
      p = Post.find_by_md5(@post.md5)
      self.data = { :success => false, :error => "Post already exists", :post_id => p.id }
    else
      p @post.errors
      self.data = { :success => false, :error => @post.errors.full_messages.join(", ") }
    end

    self.active = false

    if self.data["success"] then
      self.status = 'finished'
    else
      self.status = 'error'
    end

    self.save!
  end
end

