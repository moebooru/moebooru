class BatchUpload < ApplicationRecord
  belongs_to :user

  def data
    JSON.parse(data_as_json)
  end

  def data=(hoge)
    self.data_as_json = hoge.to_json
  end

  def run
    # Ugly: set the current user ID to the one set in the batch, so history entries
    # will be created as that user.
    old_thread_user = Thread.current["danbooru-user"]
    old_thread_user_id = Thread.current["danbooru-user_id"]
    old_ip_addr = Thread.current["danbooru-ip_addr"]
    Thread.current["danbooru-user"] = User.find_by_id(user_id)
    Thread.current["danbooru-user_id"] = user_id
    Thread.current["danbooru-ip_addr"] = ip

    self.active = true
    self.save!

    @post = Post.create(:source => url, :tags => tags, :updater_user_id => user_id, :updater_ip_addr => ip, :user_id => user_id, :ip_addr => ip, :status => "active")

    if @post.errors.empty?
      if CONFIG["dupe_check_on_upload"] && @post.image? && @post.parent_id.nil?
        options = { :services => SimilarImages.get_services("local"), :type => :post, :source => @post }

        res = SimilarImages.similar_images(options)
        unless res[:posts].empty?
          @post.tags = @post.tags + " possible_duplicate"
          @post.save!
        end
      end

      self.data = { :success => true, :post_id => @post.id }
    elsif @post.errors[:md5].any?
      p @post.errors
      p = Post.find_by_md5(@post.md5)
      self.data = { :success => false, :error => "Post already exists", :post_id => p.id }
    else
      p @post.errors
      self.data = { :success => false, :error => @post.errors.full_messages.join(", ") }
    end

    self.active = false

    if data["success"]
      self.status = "finished"
    else
      self.status = "error"
    end

    self.save!

    Thread.current["danbooru-user"] = old_thread_user
    Thread.current["danbooru-user_id"] = old_thread_user_id
    Thread.current["danbooru-ip_addr"] = old_ip_addr
  end
end
