file 'config/environment.rb', <<-ENV
# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
#{@app_name.camelize}::Application.initialize!

require 'lib/vk_api.rb'
#require 'lib/mailru_api.rb'
require 'lib/utils.rb'

SN_API = VkApi

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

    config.action_view.javascript_expansions[:defaults] = ['jquery.min', 'jquery-ui.min', 'rails']
  end
end
APP

file 'app/views/layouts/application.html.erb', <<-ERB
<!DOCTYPE html>
<html>
<head>
  <title>Ror</title>
  <%= stylesheet_link_tag :all %>
  <%= javascript_include_tag :defaults %>
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