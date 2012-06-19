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
