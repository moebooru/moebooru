Moebooru::Application.routes.draw do
  # Admin
  get 'admin(/index)' => 'admin#index'
  match 'admin/edit_user', :via => [:post, :get]
  match 'admin/reset_password', :via => [:post, :get]

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
  match 'artist(/index)(.:format)' => 'artist#index', :via => [:post, :get]
  match 'artist/create(.:format)', :via => [:post, :get]
  match 'artist/destroy(.:format)(/:id)' => 'artist#destroy', :via => [:post, :get]
  match 'artist/preview', :via => [:post, :get]
  match 'artist/show(/:id)' => 'artist#show', :via => [:post, :get]
  match 'artist/update(.:format)(/:id)' => 'artist#update', :via => [:post, :get]

  # Banned
  match 'banned(/index)' => 'banned#index', :via => [:post, :get]

  # Batch
  match 'batch(/index)' => 'batch#index', :via => [:post, :get]
  match 'batch/create', :via => [:post, :get]
  post 'batch/enqueue'
  post 'batch/update'

  # Blocks
  post 'blocks/block_ip'
  post 'blocks/unblock_ip'

  # Comment
  match 'comment(/index)' => 'comment#index', :via => [:post, :get]
  match 'comment/edit(/:id)' => 'comment#edit', :via => [:post, :get]
  match 'comment/moderate', :via => [:post, :get]
  match 'comment/search', :via => [:post, :get]
  match 'comment/show(.:format)(/:id)' => 'comment#show', :via => [:post, :get]
  match 'comment/destroy(.:format)(/:id)' => 'comment#destroy', :via => [:post, :delete]
  match 'comment/update(/:id)' => 'comment#update', :via => [:post, :put]
  post 'comment/create(.:format)'
  post 'comment/mark_as_spam(/:id)' => 'comment#mark_as_spam'

  # Dmail
  match 'dmail(/inbox)' => 'dmail#inbox', :via => [:post, :get]
  match 'dmail/compose', :via => [:post, :get]
  get 'dmail/preview'
  match 'dmail/show(/:id)' => 'dmail#show', :via => [:post, :get]
  match 'dmail/show_previous_messages', :via => [:post, :get]
  post 'dmail/create'
  get 'dmail/mark_all_read' => 'dmail#confirm_mark_all_read'
  post 'dmail/mark_all_read'

  # Favorite
  match 'favorite/list_users(.:format)', :via => [:post, :get]

  # Forum
  match 'forum(/index)(.:format)' => 'forum#index', :via => [:post, :get]
  match 'forum/preview', :via => [:post, :get]
  match 'forum/new', :via => [:post, :get]
  match 'forum/add', :via => [:post, :get]
  match 'forum/edit(/:id)' => 'forum#edit', :via => [:post, :get]
  match 'forum/show(/:id)' => 'forum#show', :via => [:post, :get]
  match 'forum/search', :via => [:post, :get]
  match 'forum/mark_all_read', :via => [:post, :get]
  match 'forum/lock', :via => [:post, :put]
  match 'forum/stick(/:id)' => 'forum#stick', :via => [:post, :put]
  match 'forum/unlock(/:id)' => 'forum#unlock', :via => [:post, :put]
  match 'forum/unstick(/:id)' => 'forum#unstick', :via => [:post, :put]
  match 'forum/update(/:id)' => 'forum#update', :via => [:post, :put]
  match 'forum/destroy(/:id)' => 'forum#destroy', :via => [:post, :delete]
  post 'forum/create'

  # Help
  match 'help(/index)' => 'help#index', :via => [:post, :get]
  match 'help/:action' => 'help#:action', :via => [:post, :get]

  # History
  match 'history(/index)' => 'history#index', :via => [:post, :get]
  post 'history/undo'

  # Inline
  match 'inline(/index)' => 'inline#index', :via => [:post, :get]
  match 'inline/add_image(/:id)' => 'inline#add_image', :via => [:post, :get]
  match 'inline/create', :via => [:post, :get]
  match 'inline/crop(/:id)' => 'inline#crop', :via => [:post, :get]
  match 'inline/edit(/:id)' => 'inline#edit', :via => [:post, :get]
  match 'inline/copy(/:id)' => 'inline#copy', :via => [:post, :put]
  match 'inline/update(/:id)' => 'inline#update', :via => [:post, :put]
  match 'inline/delete(/:id)' => 'inline#delete', :via => [:post, :delete]
  match 'inline/delete_image(/:id)' => 'inline#delete_image', :via => [:post, :delete]

  # JobTask
  match 'job_task(/index)' => 'job_task#index', :via => [:post, :get]
  match 'job_task/destroy(/:id)' => 'job_task#destroy', :via => [:post, :get]
  match 'job_task/restart(/:id)' => 'job_task#restart', :via => [:post, :get]
  match 'job_task/show(/:id)' => 'job_task#show', :via => [:post, :get]

  # Note
  match 'note(/index)(.:format)' => 'note#index', :via => [:post, :get]
  match 'note/history(.:format)(/:id)' => 'note#history', :via => [:post, :get]
  match 'note/search(.:format)', :via => [:post, :get]
  match 'note/revert(.:format)(/:id)' => 'note#revert', :via => [:post, :put]
  match 'note/update(.:format)(/:id)' => 'note#update', :via => [:post, :put]

  # Pool
  match 'pool(/index)(.:format)' => 'pool#index', :via => [:post, :get]
  match 'pool/add_post(.:format)' => 'pool#add_post', :via => [:post, :get]
  match 'pool/copy(/:id)' => 'pool#copy', :via => [:post, :get]
  match 'pool/create(.:format)' => 'pool#create', :via => [:post, :get]
  match 'pool/destroy(.:format)(/:id)' => 'pool#destroy', :via => [:post, :get]
  match 'pool/import(/:id)' => 'pool#import', :via => [:post, :get]
  match 'pool/order(/:id)' => 'pool#order', :via => [:post, :get]
  match 'pool/remove_post(.:format)' => 'pool#remove_post', :via => [:post, :get]
  match 'pool/select', :via => [:post, :get]
  match 'pool/show(.:format)(/:id)' => 'pool#show', :via => [:post, :get]
  match 'pool/transfer_metadata', :via => [:post, :get]
  match 'pool/update(.:format)(/:id)' => 'pool#update', :via => [:post, :get]
  match 'pool/zip/:id/:filename' => 'pool#zip', :constraints => { :filename => /.*/ }, :via => [:post, :get]

  # Post
  match 'post(/index)(.:format)' => 'post#index', :via => [:post, :get]
  match 'post/acknowledge_new_deleted_posts', :via => [:post, :get]
  match 'post/activate', :via => [:post, :get]
  match 'post/atom(.:format)' => 'post#atom', :defaults => { :format => :atom }, :via => [:post, :get]
  match 'post/browse', :via => [:post, :get]
  match 'post/delete(/:id)' => 'post#delete', :via => [:post, :get]
  match 'post/deleted_index', :via => [:post, :get]
  match 'post/download', :via => [:post, :get]
  match 'post/error', :via => [:post, :get]
  match 'post/exception', :via => [:post, :get]
  match 'post/histogram', :via => [:post, :get]
  match 'post/moderate', :via => [:post, :get]
  match 'post/piclens', :defaults => { :format => :rss }, :via => [:post, :get]
  match 'post/popular_by_day', :via => [:post, :get]
  match 'post/popular_by_month', :via => [:post, :get]
  match 'post/popular_by_week', :via => [:post, :get]
  match 'post/popular_recent', :via => [:post, :get]
  match 'post/random(/:id)' => 'post#random', :via => [:post, :get]
  match 'post/show(/:id)(/*tag_title)' => 'post#show', :constraints => { :id => /\d+/ }, :format => false, :via => [:post, :get]
  match 'post/similar(/:id)' => 'post#similar', :via => [:post, :get]
  match 'post/undelete(/:id)' => 'post#undelete', :via => [:post, :get]
  match 'post/update_batch', :via => [:post, :get]
  match 'post/upload', :via => [:post, :get]
  match 'post/upload_problem', :via => [:post, :get]
  match 'post/view(/:id)' => 'post#view', :via => [:post, :get]
  match 'post/flag(/:id)' => 'post#flag', :via => [:post, :put]
  match 'post/revert_tags(.:format)(/:id)' => 'post#revert_tags', :via => [:post, :put]
  match 'post/update(.:format)(/:id)' => 'post#update', :via => [:post, :put]
  match 'post/vote(.:format)(/:id)' => 'post#vote', :via => [:post, :put]
  match 'post/destroy(.:format)(/:id)' => 'post#destroy', :via => [:post, :delete]
  post 'post/create(.:format)' => 'post#create'

  match 'atom' => 'post#atom', :defaults => { :format => :atom }, :via => [:post, :get]
  match 'download' => 'post#download', :via => [:post, :get]
  match 'histogram' => 'post#histogram', :via => [:post, :get]

  # PostTagHistory
  match 'post_tag_history(/index)' => 'post_tag_history#index', :via => [:post, :get]

  # Report
  match 'report/tag_updates', :via => [:post, :get]
  match 'report/note_updates', :via => [:post, :get]
  match 'report/wiki_updates', :via => [:post, :get]
  match 'report/post_uploads', :via => [:post, :get]
  match 'report/votes', :via => [:post, :get]
  match 'report/set_dates', :via => [:post, :get]

  # Settings
  namespace :settings do
    resource :api, only: [:show, :update]
  end

  # Static
  match 'static/500', :via => [:post, :get]
  match 'static/more', :via => [:post, :get]
  match 'static/terms_of_service', :via => [:post, :get]
  match '/opensearch' => 'static#opensearch', :via => [:post, :get]

  # TagAlias
  match 'tag_alias(/index)' => 'tag_alias#index', :via => [:post, :get]
  match 'tag_alias/update', :via => [:post, :put]
  post 'tag_alias/create'

  # Tag
  match 'tag(/index)(.:format)' => 'tag#index', :via => [:post, :get]
  get 'tag/autocomplete_name', :as => :ac_tag_name
  match 'tag/cloud', :via => [:post, :get]
  match 'tag/edit(/:id)' => 'tag#edit', :via => [:post, :get]
  match 'tag/edit_preview', :via => [:post, :get]
  match 'tag/mass_edit', :via => [:post, :get]
  match 'tag/popular_by_day', :via => [:post, :get]
  match 'tag/popular_by_month', :via => [:post, :get]
  match 'tag/popular_by_week', :via => [:post, :get]
  match 'tag/related(.:format)' => 'tag#related', :via => [:post, :get]
  match 'tag/show(/:id)' => 'tag#show', :via => [:post, :get]
  match 'tag/summary', :via => [:post, :get]
  match 'tag/update(.:format)' => 'tag#update', :via => [:post, :get]

  # TagImplication
  match 'tag_implication(/index)' => 'tag_implication#index', :via => [:post, :get]
  match 'tag_implication/update', :via => [:post, :put]
  post 'tag_implication/create'

  # TagSubscription
  match 'tag_subscription(/index)' => 'tag_subscription#index', :via => [:post, :get]
  match 'tag_subscription/create', :via => [:post, :get]
  match 'tag_subscription/update', :via => [:post, :get]
  match 'tag_subscription/destroy(/:id)' => 'tag_subscription#destroy', :via => [:post, :get]

  # User
  get 'user/autocomplete_name', :as => :ac_user_name
  match 'user(/index)(.:format)' => 'user#index', :via => [:post, :get]
  match 'user/activate_user', :via => [:post, :get]
  match 'user/block(/:id)' => 'user#block', :via => [:post, :get]
  match 'user/change_email', :via => [:post, :get]
  match 'user/change_password', :via => [:post, :get]
  match 'user/check', :via => [:post, :get]
  match 'user/edit', :via => [:post, :get]
  match 'user/error', :via => [:post, :get]
  match 'user/home', :via => [:post, :get]
  match 'user/invites', :via => [:post, :get]
  match 'user/login', :via => [:post, :get]
  match 'user/logout', :via => [:post, :get]
  match 'user/remove_from_blacklist', :via => [:post, :get]
  match 'user/resend_confirmation', :via => [:post, :get]
  match 'user/reset_password', :via => [:post, :get]
  match 'user/set_avatar(/:id)' => 'user#set_avatar', :via => [:post, :get]
  match 'user/show(/:id)' => 'user#show', :via => [:post, :get]
  match 'user/show_blocked_users', :via => [:post, :get]
  match 'user/signup', :via => [:post, :get]
  match 'user/unblock', :via => [:post, :get]
  match 'user/authenticate', :via => [:post, :put]
  match 'user/modify_blacklist', :via => [:post, :put]
  match 'user/update', :via => [:post, :put, :patch]
  post 'user/create'
  post 'user/remove_avatar/:id' => 'user#remove_avatar'

  # UserRecord
  match 'user_record(/index)' => 'user_record#index', :via => [:post, :get]
  match 'user_record/create(/:id)' => 'user_record#create', :via => [:post, :get]
  match 'user_record/destroy(/:id)' => 'user_record#destroy', :via => [:post, :delete]

  # Wiki
  match 'wiki(/index)(.:format)' => 'wiki#index', :via => [:post, :get]
  match 'wiki/add', :via => [:post, :get]
  match 'wiki/diff', :via => [:post, :get]
  match 'wiki/edit', :via => [:post, :get]
  match 'wiki/history(.:format)(/:id)' => 'wiki#history', :via => [:post, :get]
  match 'wiki/preview', :via => [:post, :get]
  match 'wiki/recent_changes', :via => [:post, :get]
  match 'wiki/rename', :via => [:post, :get]
  match 'wiki/show(.:format)' => 'wiki#show', :via => [:post, :get]
  match 'wiki/lock(.:format)' => 'wiki#lock', :via => [:post, :put]
  match 'wiki/revert(.:format)' => 'wiki#revert', :via => [:post, :put]
  match 'wiki/unlock(.:format)' => 'wiki#unlock', :via => [:post, :put]
  match 'wiki/update(.:format)' => 'wiki#update', :via => [:post, :put]
  match 'wiki/destroy(.:format)' => 'wiki#destroy', :via => [:post, :delete]
  post 'wiki/create(.:format)' => 'wiki#create'

  root :to => 'static#index'

  get "errors/not_found" if Rails.env.development?
  match "*path" => "errors#not_found", :via => [:get, :post] unless Rails.env.development?
end
