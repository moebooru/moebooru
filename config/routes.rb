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
  api_format = /(json|xml|html)/
  ## Posts
  match 'post/index.:format' => 'post#index', :constraints => { :format => api_format }

  match 'post/show/:id/:tag_title' => 'post#show', :constraints => { :id => /\d+/ }
  match 'pool/zip/:id/:filename' => 'pool#zip', :constraints => { :id => /\d+/, :filename => /.*/ }
  match ':controller(/:action(/:id))', :id => /\d+/
  match ':controller/:action.:format' => '#index'
  match ':controller/:action' => '#index'
  match 'histogram' => 'post#histogram'
  match 'download' => 'post#download'
  root :to => 'static#index'
end
