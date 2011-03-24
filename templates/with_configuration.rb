file 'config/environment.rb', <<-ENV
# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
#{@app_name.camelize}::Application.initialize!

require 'lib/vk_api.rb'
#require 'lib/mailru_api.rb'
require 'lib/utils.rb'

#QUEUE = MemCache.new('local_starling_server:22122')

#REQUEST_CACHE = []
#50.times do |num|
#  REQUEST_CACHE << MemCache.new("local_starling_server:\#{(16000 + num).to_s}")
#end
ENV

file 'config/application.rb', <<-APP
require File.expand_path('../boot', __FILE__)

#require 'rails/all'
require "action_controller/railtie"
require "action_mailer/railtie"
require "active_resource/railtie"


# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.

Bundler.require(:default, Rails.env) if defined?(Bundler)

module #{@app_name.camelize}
  class Application < Rails::Application
    config.generators do |g|
      g.orm             :mongoid
    end

    config.time_zone = 'UTC'

    config.encoding = "utf-8"

    config.filter_parameters += [:password, :password_confirmation]

    config.action_view.javascript_expansions[:defaults] = ['jquery.1.4.2.min', 'jquery-ui-1.8.4.min', 'jquery-ujs/src/rails']
  end
end

APP