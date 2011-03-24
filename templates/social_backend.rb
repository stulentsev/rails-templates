def colorize(text, color_code)
  "#{color_code}#{text}\033[0m"
end

def red(text)
  colorize(text, "\033[31m")
end

def green(text)
  colorize(text, "\033[32m")
end

def download_file from, to
  puts "downloading file from '#{from}' to '#{to}'"
  write_out = open(to, 'wb')
  write_out.write(open(from).read)
  write_out.close
end


git :init

run "echo 'TODO add readme content' > README"
run "touch tmp/.gitignore log/.gitignore vendor/.gitignore"
run "mv config/database.yml config/example_database.yml"
run "rm public/index.html"
run <<-FFF
echo "source 'http://rubygems.org'

" > Gemfile
FFF


new_ignores = <<-END
config/database.yml
END

run "echo '#{new_ignores}' >> .gitignore"

file 'app/views/layouts/void.erb', '<%= yield %>'

gem 'rails', '3.0.5'

gem 'bson_ext'
gem 'mongoid', '2.0.0.rc.8'
#gem 'mongoid', :git => 'https://github.com/mongoid/mongoid.git'
gem 'devise'

apply "https://github.com/stulentsev/rails-templates/raw/master/templates/heartbeatable.rb"
apply "https://github.com/stulentsev/rails-templates/raw/master/templates/with_mongoid.rb"
apply "https://github.com/stulentsev/rails-templates/raw/master/templates/newrelicable.rb"
apply "https://github.com/stulentsev/rails-templates/raw/master/templates/with_flash_handler.rb"
apply "https://github.com/stulentsev/rails-templates/raw/master/templates/with_dashboard.rb"
apply "https://github.com/stulentsev/rails-templates/raw/master/templates/with_configuration.rb"
apply "https://github.com/stulentsev/rails-templates/raw/master/templates/with_styles.rb"
apply "https://github.com/stulentsev/rails-templates/raw/master/templates/with_javascripts.rb"

run 'bundle install'

generate 'scaffold User name:string email:string'

generate 'devise:install'
generate 'devise User'

file 'app/models/user.rb', <<-USER
class User
  include Mongoid::Document
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable, :lockable and :timeoutable
  devise :database_authenticatable,# :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  field :name
  field :roles, :type => Array
  validates_presence_of :name
  validates_uniqueness_of :email, :case_sensitive => false
  attr_accessible :name, :email, :password, :password_confirmation


  def role? rol
    rr = roles || []

    rr.member?(rol.to_s)
  end
end
USER

route "resources :users, :only => [:show,:index]"


generate 'jquery:install'


git :add => ".", :commit => "-m 'initial commit'"
