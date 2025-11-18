Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  namespace :api, defaults: {format: :json} do
    namespace :v1 do
      resources :links do
        collection do
          get :by_url
        end
      end
      resources :tags

      # Snapshot export/import
      post "snapshot/export", to: "snapshot#export"
      post "snapshot/import", to: "snapshot#import"
      get "snapshot/exports/:filename", to: "snapshot#download", constraints: {filename: /[^\/]+/}, defaults: {format: false}
    end
  end

  #---------------------------------------------------------------------------
  # GoodJob Dashboard
  # Secured by basic auth. See config/initializers/good_job.rb
  #---------------------------------------------------------------------------
  mount GoodJob::Engine, at: "/goodjob"
end
