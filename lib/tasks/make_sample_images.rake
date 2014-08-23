namespace :sample_images do
  def regen(post)
#    unless post.regenerate_images(:sample)
#      unless post.errors.empty?
#        error = post.errors.full_messages.join(", ")
#        puts "Error generating sample: post ##{post.id}: #{error}"
#      end
#
#      return false
#    end

    unless post.regenerate_images(:jpeg)
      unless post.errors.empty?
        error = post.errors.full_messages.join(", ")
        puts "Error generating JPEG: post ##{post.id}: #{error}"
      end

      return false
    end

    puts "post ##{post.id}"
    post.save!
    true
  end

  desc "Create missing sample images"
  task :create_missing => :environment do
    Post.order("id DESC").all.each do |post|
      regen(post)
    end
  end
end
