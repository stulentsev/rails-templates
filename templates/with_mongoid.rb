new_ignores =  <<-END
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

