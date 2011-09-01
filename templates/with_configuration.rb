
file 'config/environment.rb', <<-ENV
# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
#{@app_name.camelize}::Application.initialize!

require './lib/utils.rb'

SN_API = VkApi

ENV

file 'config/application.rb', <<-APP
require File.expand_path('../boot', __FILE__)

#require 'rails/all'
require "action_controller/railtie"
require "action_mailer/railtie"
require "active_resource/railtie"


# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  #Bundler.require *Rails.groups(:assets => %w(development test))
  # If you want your assets lazily compiled in production, use this line
  Bundler.require(:default, :assets, Rails.env)
end

module #{@app_name.camelize}
  class Application < Rails::Application
    config.generators do |g|
      g.orm             :mongoid
    end

    config.autoload_paths += %W(\#{config.root}/lib)

    config.time_zone = 'UTC'

    config.encoding = "utf-8"

    config.filter_parameters += [:password, :password_confirmation]

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'
  end
end
APP

file 'app/views/layouts/application.html.erb', <<-ERB
<!DOCTYPE html>
<html>
<head>
  <title>Ror</title>
  <%= stylesheet_link_tag    "application" %>
  <%= javascript_include_tag "application" %>
  <%= csrf_meta_tag %>
</head>
<body>


<div id='container'>

  <div id='pageLayout'>
    <div id="pageHeader">
      <h1 id="home"><a href="/">#{@app_name}</a></h1>


      <div class="headNav" id="topNav">
        <div></div>
        <% if current_user %>
            <%= link_to('Logout', destroy_user_session_path) %>
            <div><%= current_user.name %> </div>
        <% end %>
      </div>
    </div>
    <div id='left_sidebar'>

      <ul id='nav'>
        <li><%= link_to "Menu item 1", '#' %></li>
        <li><%= link_to "Menu item 2", '#' %></li>
        <li><%= link_to "Menu item 3", '#' %></li>
        <li><%= link_to "Menu item 4", '#' %></li>
      </ul>
    </div>
    <div id='pageBody'>
      <div style="color: green"><%= notice %></div>

      <div style="color: red"><%= alert %></div>

      <%= yield %>

    </div>

  </div>

</div>

</body>
</html>

ERB
