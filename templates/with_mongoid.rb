new_ignores =  <<-END
config/mongoid.yml
END

run "echo '#{new_ignores}' >> .gitignore"


file 'config/mongoid.yml', <<-END
development:
  host: localhost
  port: 27017
  database: #{@app_name}_development

test:
  host: localhost
  port: 27017
  database: #{@app_name}_test

# set these environment variables on your prod server
production:
  host: localhost
  port: 27017
  database: #{@app_name}_production
END

