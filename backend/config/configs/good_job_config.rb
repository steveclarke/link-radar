# frozen_string_literal: true

class GoodJobConfig < ApplicationConfig
  config_name :good_job
  attr_config(
    :dashboard_username,
    :dashboard_password
  )

  required :dashboard_username, env: "production"
  required :dashboard_password, env: "production"
end
