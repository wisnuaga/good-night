Rails.application.routes.draw do
  # Simple health check endpoint
  get "healthz", to: proc { [ 200, { "Content-Type" => "application/json" }, [ { status: "OK" }.to_json ] ] }

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  put "users/:id/follow",   to: "follows#follow",   as: :follow_user
  put "users/:id/unfollow", to: "follows#unfollow",  as: :unfollow_user

  post "/sleep_records/clock_in", to: "sleep_record#clock_in", as: :clock_in
  put "/sleep_records/clock_out", to: "sleep_record#clock_out", as: :clock_out
  get "/sleep_records", to: "sleep_record#index", as: :sleep_records
end
