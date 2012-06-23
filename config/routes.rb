Moebooru::Application.routes.draw do
  resources :advertisements do
    collection do
      post :update_multiple
    end
    member do
      get :redirect
    end
  end

  # API 1.13.0
  scope :defaults => { :format => 'html' }, :constraints => { :format => /(json|xml|html)/ } do
    # Posts
    match 'post/index(.:format)' => 'post#index'
    match 'post/create(.:format)' => 'post#create', :via => :post
    match 'post/update(.:format)' => 'post#update', :via => [:post, :put]
    match 'post/revert_tags(.:format)' => 'post#revert_tags', :via => [:post, :put]
    match 'post/vote(.:format)' => 'post#vote', :via => [:post, :put]
    match 'post/destroy(.:format)' => 'post#destroy', :via => [:post, :delete]
    # Tags
    match 'tag/index(.:format)' => 'tag#index'
    match 'tag/related(.:format)' => 'tag#related'
    match 'tag/update(.:format)' => 'tag#update', :via => [:post, :put]
    # Artists
    match 'artist/index(.:format)' => 'artist#index'
    match 'artist/create(.:format)' => 'artist#create', :via => :post
    match 'artist/update(.:format)' => 'artist#update', :via => [:post, :put]
    match 'artist/destroy(.:format)' => 'artist#destroy', :via => [:post, :delete]
    # Comments
    match 'comment/show(.:format)' => 'comment#show'
    match 'comment/create(.:format)' => 'comment#create', :via => :post
    match 'comment/destroy(.:format)' => 'comment#destroy', :via => [:post, :delete]
    # Wiki
    match 'wiki/index(.:format)' => 'wiki#index'
    match 'wiki/show(.:format)' => 'wiki#show'
    match 'wiki/history(.:format)' => 'wiki#history'
    match 'wiki/create(.:format)' => 'wiki#create', :via => :post
    match 'wiki/update(.:format)' => 'wiki#update', :via => [:post, :put]
    match 'wiki/lock(.:format)' => 'wiki#lock', :via => [:post, :put]
    match 'wiki/unlock(.:format)' => 'wiki#unlock', :via => [:post, :put]
    match 'wiki/revert(.:format)' => 'wiki#revert', :via => [:post, :put]
    match 'wiki/destroy(.:format)' => 'wiki#destroy', :via => [:post, :delete]
    # Notes
    match 'note/index(.:format)' => 'note#index'
    match 'note/search(.:format)' => 'note#search'
    match 'note/history(.:format)' => 'note#history'
    match 'note/revert(.:format)' => 'note#revert', :via => [:post, :put]
    match 'note/update(.:format)' => 'note#update', :via => [:post, :put]
    # Users
    match 'user/index(.:format)' => 'user#index'
    # Forum
    match 'forum/index(.:format)' => 'forum#index'
    # Pools
    match 'pool/index(.:format)' => 'pool#index'
    match 'pool/show(.:format)' => 'pool#show'
    match 'pool/create(.:format)' => 'pool#create', :via => :post
    match 'pool/update(.:format)' => 'pool#update', :via => [:post, :put]
    match 'pool/add_post(.:format)' => 'pool#add_post', :via => [:post, :put]
    match 'pool/remove_post(.:format)' => 'pool#remove_post', :via => [:post, :put]
    match 'pool/destroy(.:format)' => 'pool#destroy', :via => [:post, :delete]
  end

  match 'post/show/:id/:tag_title' => 'post#show', :constraints => { :id => /\d+/ }
  match 'pool/zip/:id/:filename' => 'pool#zip', :constraints => { :id => /\d+/, :filename => /.*/ }
  match ':controller(/:action(/:id))', :id => /\d+/
  match ':controller/:action.:format' => '#index'
  match ':controller/:action' => '#index'
  match 'histogram' => 'post#histogram'
  match 'download' => 'post#download'
  root :to => 'static#index'
end
