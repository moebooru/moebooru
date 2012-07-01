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
  match 'artist/create(.:format)' => 'artist#create'
  match 'artist/destroy(.:format)(/:id)' => 'artist#destroy'
  match 'artist/preview'
  match 'artist/show(/:id)'
  match 'artist/update(.:format)(/:id)' => 'artist#update'

  # Banned
  match 'banned(/index)' => 'banned#index'

  # Batch
  match 'batch/index'
  match 'batch/update'
  match 'batch/create'
  match 'batch/enqueue'

  # Blocks
  match 'blocks/block_ip'
  match 'blocks/unblock_ip'

  # Comment
  match 'comment/edit'
  match 'comment/update'
  match 'comment/destroy'
  match 'comment/create'
  match 'comment/show'
  match 'comment/index'
  match 'comment/search'
  match 'comment/moderate'
  match 'comment/mark_as_spam'

  # Dmail
  match 'dmail/preview'
  match 'dmail/auto_complete_for_dmail_to_name'
  match 'dmail/show_previous_messages'
  match 'dmail/compose'
  match 'dmail/create'
  match 'dmail/inbox'
  match 'dmail/show'
  match 'dmail/mark_all_read'

  # Favorite
  match 'favorite/list_users'
  match 'favorite/favorited_users_for_post(post)'

  # Forum
  match 'forum/stick'
  match 'forum/unstick'
  match 'forum/preview'
  match 'forum/new'
  match 'forum/create'
  match 'forum/add'
  match 'forum/destroy'
  match 'forum/edit'
  match 'forum/update'
  match 'forum/show'
  match 'forum/index'
  match 'forum/search'
  match 'forum/lock'
  match 'forum/unlock'
  match 'forum/mark_all_read'

  # Help

  # History
  match 'history/index'
  match 'history/undo'

  # Inline
  match 'inline/create'
  match 'inline/index'
  match 'inline/delete'
  match 'inline/add_image'
  match 'inline/delete_image'
  match 'inline/update'
  match 'inline/copy'
  match 'inline/edit'
  match 'inline/crop'

  # JobTask
  match 'job_task/index'
  match 'job_task/show'
  match 'job_task/destroy'
  match 'job_task/restart'

  # Note
  match 'note/search'
  match 'note/index'
  match 'note/history'
  match 'note/revert'
  match 'note/update'

  # Pool
  match 'pool/index'
  match 'pool/show'
  match 'pool/update'
  match 'pool/create'
  match 'pool/copy'
  match 'pool/destroy'
  match 'pool/add_post'
  match 'pool/remove_post'
  match 'pool/order'
  match 'pool/import'
  match 'pool/select'
  match 'pool/zip'
  match 'pool/transfer_metadata'

  # Post
  match 'post/verify_action(options)'
  match 'post/activate'
  match 'post/upload_problem'
  match 'post/upload'
  match 'post/create'
  match 'post/moderate'
  match 'post/update'
  match 'post/update_batch'
  match 'post/delete'
  match 'post/destroy'
  match 'post/deleted_index'
  match 'post/acknowledge_new_deleted_posts'
  match 'post/index'
  match 'post/atom'
  match 'post/piclens'
  match 'post/show'
  match 'post/browse'
  match 'post/view'
  match 'post/popular_recent'
  match 'post/popular_by_day'
  match 'post/popular_by_week'
  match 'post/popular_by_month'
  match 'post/revert_tags'
  match 'post/vote'
  match 'post/flag'
  match 'post/random'
  match 'post/similar'
  match 'post/search(params)'
  match 'post/undelete'
  match 'post/error'
  match 'post/exception'
  match 'post/download'
  match 'post/histogram'

  # PostTagHistory
  match 'post_tag_history/index'

  # Report
  match 'report/tag_updates'
  match 'report/note_updates'
  match 'report/wiki_updates'
  match 'report/post_uploads'
  match 'report/votes'
  match 'report/set_dates'

  # Static
  match 'static/index'

  # TagAlias
  match 'tag_alias/create'
  match 'tag_alias/index'
  match 'tag_alias/update'

  # Tag
  match 'tag/cloud'
  match 'tag/summary'
  match 'tag/index'
  match 'tag/mass_edit'
  match 'tag/edit_preview'
  match 'tag/edit'
  match 'tag/update'
  match 'tag/related'
  match 'tag/popular_by_day'
  match 'tag/popular_by_week'
  match 'tag/popular_by_month'
  match 'tag/show'

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
    # Posts
    match 'post(/index)(.:format)' => 'post#index'
    match 'post/create(.:format)' => 'post#create', :via => :post
    match 'post/update(.:format)' => 'post#update', :via => [:post, :put]
    match 'post/revert_tags(.:format)' => 'post#revert_tags', :via => [:post, :put]
    match 'post/vote(.:format)' => 'post#vote', :via => [:post, :put]
    match 'post/destroy(.:format)' => 'post#destroy', :via => [:post, :delete]
    # Tags
    match 'tag(/index)(.:format)' => 'tag#index'
    match 'tag/related(.:format)' => 'tag#related'
    match 'tag/update(.:format)' => 'tag#update', :via => [:post, :put]
    # Comments
    match 'comment/show(.:format)' => 'comment#show'
    match 'comment/create(.:format)' => 'comment#create', :via => :post
    match 'comment/destroy(.:format)' => 'comment#destroy', :via => [:post, :delete]
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
    # Notes
    match 'note(/index)(.:format)' => 'note#index'
    match 'note/search(.:format)' => 'note#search'
    match 'note/history(.:format)' => 'note#history'
    match 'note/revert(.:format)' => 'note#revert', :via => [:post, :put]
    match 'note/update(.:format)' => 'note#update', :via => [:post, :put]
    # Users
    match 'user(/index)(.:format)' => 'user#index'
    # Forum
    match 'forum(/index)(.:format)' => 'forum#index'
    # Pools
    match 'pool(/index)(.:format)' => 'pool#index'
    match 'pool/create(.:format)' => 'pool#create', :via => :post
    match 'pool/show(.:format)(/:id)' => 'pool#show'
    match 'pool/update(.:format)(/:id)' => 'pool#update', :via => [:post, :put]
    match 'pool/destroy(.:format)(/:id)' => 'pool#destroy', :via => [:post, :delete]
    match 'pool/add_post(.:format)' => 'pool#add_post', :via => [:post, :put]
    match 'pool/remove_post(.:format)' => 'pool#remove_post', :via => [:post, :put]
    # Favorites
    match 'favorite/list_users(.:format)' => 'favorite#list_users', :constraints => { :format => 'json' }
  end

  # Atom
  match 'post/atom(.xml)' => 'post#atom'
  match 'post/atom.feed' => 'post#atom'
  match 'atom' => 'post#atom'

  match 'post/show/:id(/*tag_title)' => 'post#show', :constraints => { :id => /\d+/ }, :format => false
  match 'pool/zip/:id/:filename' => 'pool#zip', :constraints => { :id => /\d+/, :filename => /.*/ }
  match 'histogram' => 'post#histogram'
  match 'download' => 'post#download'
  root :to => 'static#index'
end
