git :init

run "echo 'TODO add readme content' > README"
run "touch tmp/.gitignore log/.gitignore vendor/.gitignore"
run "cp config/database.yml config/example_database.yml"


new_ignores =  <<-END
config/database.yml
config/mongoid.yml
END

run "echo '#{new_ignores}' >> .gitignore"

file 'config/mongoid.yml', <<-END
defaults: &defaults
  host: localhost

development:
  <<: *defaults
  database: #{@app_name}_development

test:
  <<: *defaults
  database: #{@app_name}_test

# set these environment variables on your prod server
production:
  <<: *defaults
  database: #{@app_name}_production
END

file 'app/views/layouts/void.erb', '<%= yield %>'

gem 'bson_ext'
gem 'mongoid', '2.0.0.rc.8'
gem 'devise'

apply "newrelicable.rb"

run 'bundle install'

generate 'devise:install'
generate 'devise User'

git :add => ".", :commit => "-m 'initial commit'"
