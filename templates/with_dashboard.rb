file 'app/controllers/main_controller.rb', <<-MC
class MainController < ApplicationController
  before_filter :authenticate_user!

  def dashboard
    @users = User.all

  end

end
MC

file 'app/helpers/main_helper.rb', <<-MH
module MainHelper
  def vk_user_link vku
    return 'None' unless vku

    our_link = vk_user_url(vku)
    vk_link = "http://vkontakte.ru/id\#{vku.id}"

    link_to("\#{vku.first_name} \#{vku.last_name}",
            our_link) + " (" +
    link_to("id\#{vku.id}",
            vk_link,
            :target => '_blank') +")"

  end
end
MH

file 'app/views/main/dashboard.html.erb', <<-DASH
<div id='header'>
  <h1>Краткая информация</h1>
</div>

<% @users.each do |user| %>
  <p>User: <%= link_to user.name, user %> </p>
<% end %>

<div id='col1'>
    <h2>Welcome to the dashboard</h2>
</div>
DASH

route "root :to => 'main#dashboard'"