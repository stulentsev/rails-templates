git :init

run "echo 'TODO add readme content' > README"
run "touch tmp/.gitignore log/.gitignore vendor/.gitignore"
run "cp config/database.yml config/example_database.yml"
run "rm public/index.html"

new_ignores =  <<-END
config/database.yml
END

run "echo '#{new_ignores}' >> .gitignore"


file 'app/views/layouts/void.erb', '<%= yield %>'

gem 'bson_ext'
gem 'mongoid', '2.0.0.rc.8'
gem 'devise'

apply "https://github.com/stulentsev/rails-templates/raw/master/templates/heartbeatable.rb"
apply "https://github.com/stulentsev/rails-templates/raw/master/templates/with_mongoid.rb"
apply "https://github.com/stulentsev/rails-templates/raw/master/templates/newrelicable.rb"

run 'bundle install'

generate 'devise:install'
generate 'devise User'


git :add => ".", :commit => "-m 'initial commit'"
