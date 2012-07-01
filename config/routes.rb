Moebooru::Application.routes.draw do
  # Admin
  match 'admin(/index)' => 'admin#index'
  match 'admin/edit_user'
  match 'admin/reset_password'

  # Advertisements
  resources :advertisements do
    collection do
      post :update_multiple
    end
    member do
      get :redirect
    end
  end

  # Artist
  match 'artist(/index)(.:format)' => 'artist#index'
  match 'artist/create(.:format)'
  match 'artist/destroy(.:format)(/:id)' => 'artist#destroy'
  match 'artist/preview'
  match 'artist/show(/:id)' => 'artist#show'
  match 'artist/update(.:format)(/:id)' => 'artist#update'

  # Banned
  match 'banned(/index)' => 'banned#index'

  # Batch
  match 'batch(/index)' => 'batch#index'
  match 'batch/create'
  post 'batch/enqueue'
  post 'batch/update'

  # Blocks
  post 'blocks/block_ip'
  post 'blocks/unblock_ip'

  # Comment
  match 'comment(/index)' => 'comment#index'
  match 'comment/edit(/:id)' => 'comment#edit'
  match 'comment/moderate'
  match 'comment/search'
  match 'comment/show(.:format)(/:id)' => 'comment#show'
  match 'comment/destroy(.:format)(/:id)' => 'comment#destroy', :via => [:post, :delete]
  match 'comment/update(/:id)' => 'comment/update', :via => [:post, :put]
  post 'comment/create(.:format)'
  post 'comment/mark_as_spam(/:id)' => 'comment#mark_as_spam'

  # Dmail
  match 'dmail(/inbox)' => 'dmail#inbox'
  match 'dmail/auto_complete_for_dmail_to_name'
  match 'dmail/compose'
  match 'dmail/preview'
  match 'dmail/show(/:id)' => 'dmail#show'
  match 'dmail/show_previous_messages'
  post 'dmail/create'
  post 'dmail/mark_all_read'

  # Favorite
  match 'favorite/list_users(.:format)'

  # Forum
  match 'forum(/index)(.:format)' => 'forum#index'
  match 'forum/preview'
  match 'forum/new'
  match 'forum/add'
  match 'forum/edit(/:id)' => 'forum#edit'
  match 'forum/show(/:id)' => 'forum#show'
  match 'forum/search'
  match 'forum/mark_all_read'
  match 'forum/lock', :via => [:post, :put]
  match 'forum/stick(/:id)' => 'forum#stick', :via => [:post, :put]
  match 'forum/unlock(/:id)' => 'forum#unlock', :via => [:post, :put]
  match 'forum/unstick(/:id)' => 'forum#unstick', :via => [:post, :put]
  match 'forum/update(/:id)' => 'forum#update', :via => [:post, :put]
  match 'forum/destroy(/:id)' => 'forum#destroy', :via => [:post, :delete]
  post 'forum/create'

  # Help
  match 'help/:action' => 'help#:action'

  # History
  match 'history(/index)' => 'history#index'
  post 'history/undo'

  # Inline
  match 'inline(/index)' => 'inline#index'
  match 'inline/add_image(/:id)' => 'inline#add_image'
  match 'inline/create'
  match 'inline/crop(/:id)' => 'inline#crop'
  match 'inline/edit(/:id)' => 'inline#edit'
  match 'inline/copy(/:id)' => 'inline#copy', :via => [:post, :put]
  match 'inline/update(/:id)' => 'inline#update', :via => [:post, :put]
  match 'inline/delete(/:id)' => 'inline#delete', :via => [:post, :delete]
  match 'inline/delete_image(/:id)' => 'inline#delete_image', :via => [:post, :delete]

  # JobTask
  match 'job_task(/index)' => 'job_task#index'
  match 'job_task/destroy(/:id)' => 'job_task#destroy'
  match 'job_task/restart(/:id)' => 'job_task#restart'
  match 'job_task/show(/:id)' => 'job_task#show'

  # Note
  match 'note(/index)(.:format)' => 'note#index'
  match 'note/history(.:format)(/:id)' => 'note#history'
  match 'note/search(.:format)'
  match 'note/revert(.:format)(/:id)' => 'note#revert', :via => [:post, :put]
  match 'note/update(.:format)(/:id)' => 'note#update', :via => [:post, :put]

  # Pool
  match 'pool(/index)(.:format)' => 'pool#index'
  match 'pool/add_post(.:format)' => 'pool#add_post'
  match 'pool/copy(/:id)' => 'pool#copy'
  match 'pool/create(.:format)' => 'pool#create'
  match 'pool/destroy(.:format)(/:id)' => 'pool#destroy'
  match 'pool/import(/:id)' => 'pool#import'
  match 'pool/order(/:id)' => 'pool#order'
  match 'pool/remove_post(.:format)' => 'pool#remove_post'
  match 'pool/select'
  match 'pool/show(.:format)(/:id)' => 'pool#show'
  match 'pool/transfer_metadata'
  match 'pool/update(.:format)(/:id)' => 'pool#update'
  match 'pool/zip/:id/:filename' => 'pool#zip', :constraints => { :filename => /.*/ }

  # Post
  match 'post(/index)(.:format)' => 'post#index'
  match 'post/acknowledge_new_deleted_posts'
  match 'post/activate'
  match 'post/atom(.:format)' => 'post#atom'
  match 'post/browse'
  match 'post/delete(/:id)' => 'post#delete'
  match 'post/deleted_index'
  match 'post/download'
  match 'post/error'
  match 'post/exception'
  match 'post/histogram'
  match 'post/moderate'
  match 'post/piclens'
  match 'post/popular_by_day'
  match 'post/popular_by_month'
  match 'post/popular_by_week'
  match 'post/popular_recent'
  match 'post/random(/:id)' => 'post#random'
  match 'post/show(/:id)(/*tag_title)' => 'post#show', :constraints => { :id => /\d+/ }, :format => false
  match 'post/similar(/:id)' => 'post#similar'
  match 'post/undelete(/:id)' => 'post#undelete'
  match 'post/update_batch'
  match 'post/upload'
  match 'post/upload_problem'
  match 'post/verify_action(options)'
  match 'post/view(/:id)' => 'post#view'
  match 'post/flag(/:id)' => 'post#flag', :via => [:post, :put]
  match 'post/revert_tags(.:format)(/:id)' => 'post#revert_tags', :via => [:post, :put]
  match 'post/update(.:format)(/:id)' => 'post#update', :via => [:post, :put]
  match 'post/vote(.:format)(/:id)' => 'post#vote', :via => [:post, :put]
  match 'post/destroy(.:format)(/:id)' => 'post#destroy', :via => [:post, :delete]
  post 'post/create(.:format)' => 'post#create'

  match 'atom' => 'post#atom'
  match 'download' => 'post#download'
  match 'histogram' => 'post#histogram'

  # PostTagHistory
  match 'post_tag_history(/index)' => 'post_tag_history#index'

  # Report
  match 'report/tag_updates'
  match 'report/note_updates'
  match 'report/wiki_updates'
  match 'report/post_uploads'
  match 'report/votes'
  match 'report/set_dates'

  # Static
  match 'static/500'
  match 'static/index'
  match 'static/more'
  match 'static/terms_of_service'

  # TagAlias
  match 'tag_alias(/index)' => 'tag_alias#index'
  match 'tag_alias/update', :via => [:post, :put]
  post 'tag_alias/create'

  # Tag
  match 'tag(/index)(.:format)' => 'tag#index'
  match 'tag/cloud'
  match 'tag/edit'
  match 'tag/edit_preview'
  match 'tag/mass_edit'
  match 'tag/popular_by_day'
  match 'tag/popular_by_month'
  match 'tag/popular_by_week'
  match 'tag/related(.:format)' => 'tag#related'
  match 'tag/show'
  match 'tag/summary'
  match 'tag/update(.:format)' => 'tag#update'

  # TagImplication
  match 'tag_implication/create'
  match 'tag_implication/update'
  match 'tag_implication/index'

  # TagSubscription
  match 'tag_subscription/create'
  match 'tag_subscription/update'
  match 'tag_subscription/index'
  match 'tag_subscription/destroy'

  # User
  match 'user/save_cookies(user)'
  match 'user/change_password'
  match 'user/change_email'
  match 'user/auto_complete_for_member_name'
  match 'user/show'
  match 'user/invites'
  match 'user/home'
  match 'user/index'
  match 'user/authenticate'
  match 'user/check'
  match 'user/login'
  match 'user/create'
  match 'user/signup'
  match 'user/logout'
  match 'user/update'
  match 'user/modify_blacklist'
  match 'user/remove_from_blacklist'
  match 'user/edit'
  match 'user/reset_password'
  match 'user/block'
  match 'user/unblock'
  match 'user/show_blocked_users'
  match 'user/resend_confirmation'
  match 'user/activate_user'
  match 'user/set_avatar'
  match 'user/error'
  match 'user/get_view_name_for_edit(param)'

  # UserRecord
  match 'user_record/index'
  match 'user_record/create'
  match 'user_record/destroy'

  # Wiki
  match 'wiki/destroy'
  match 'wiki/lock'
  match 'wiki/unlock'
  match 'wiki/index'
  match 'wiki/preview'
  match 'wiki/add'
  match 'wiki/create'
  match 'wiki/edit'
  match 'wiki/update'
  match 'wiki/show'
  match 'wiki/revert'
  match 'wiki/recent_changes'
  match 'wiki/history'
  match 'wiki/diff'
  match 'wiki/rename'

  # API 1.13.0
  scope :defaults => { :format => 'html' }, :constraints => { :format => /(json|xml|html)/, :id => /\d+/ } do
    # Wiki
    match 'wiki(/index)(.:format)' => 'wiki#index'
    match 'wiki/show(.:format)' => 'wiki#show'
    match 'wiki/history(.:format)' => 'wiki#history'
    match 'wiki/create(.:format)' => 'wiki#create', :via => :post
    match 'wiki/update(.:format)' => 'wiki#update', :via => [:post, :put]
    match 'wiki/lock(.:format)' => 'wiki#lock', :via => [:post, :put]
    match 'wiki/unlock(.:format)' => 'wiki#unlock', :via => [:post, :put]
    match 'wiki/revert(.:format)' => 'wiki#revert', :via => [:post, :put]
    match 'wiki/destroy(.:format)' => 'wiki#destroy', :via => [:post, :delete]
    # Users
    match 'user(/index)(.:format)' => 'user#index'
  end

  root :to => 'static#index'
end
