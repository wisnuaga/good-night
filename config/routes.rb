Rails.application.routes.draw do
  # Simple health check endpoint
  get "healthz", to: proc { [ 200, { "Content-Type" => "application/json" }, [ { status: "OK" }.to_json ] ] }

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  put "users/:id/follow",   to: "follows#follow",   as: :follow_user
  put "users/:id/unfollow", to: "follows#unfollow",  as: :unfollow_user

  # Defines the root path route ("/")
  # root "posts#index"
end
