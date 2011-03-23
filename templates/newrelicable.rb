
license_key = ask('Please provide your NewRelic license key: ')

if license_key && license_key.gsub(/\s/, '').length > 0
  gem 'rpm_contrib', :git => "git://github.com/newrelic/rpm_contrib.git"
  gem 'newrelic_rpm'

  file 'config/newrelic.yml', <<-NR
#
# This file configures the NewRelic RPM Agent, NewRelic RPM monitors Rails
# applications with deep visibility and low overhead.  For more information,
# visit www.newrelic.com.
#
# This configuration file is custom generated for Sergei Tulentsev
#
# here are the settings that are common to all environments
common: &default_settings
  # ============================== LICENSE KEY ===============================
  # You must specify the licence key associated with your New Relic account.
  # This key binds your Agent's data to your account in the New Relic RPM service.
  license_key: '#{license_key}'

  disable_mongodb: true
  # Application Name
  # Set this to be the name of your application as you'd like it show up in RPM.
  # RPM will then auto-map instances of your application into a RPM "application"
  # on your home dashboard page. This setting does not prevent you from manually
  # defining applications.
  app_name: #{@app_name}

  # the 'enabled' setting is used to turn on the NewRelic Agent.  When false,
  # your application is not instrumented and the Agent does not start up or
  # collect any data; it is a complete shut-off.
  #
  # when turned on, the agent collects performance data by inserting lightweight
  # tracers on key methods inside the rails framework and asynchronously aggregating
  # and reporting this performance data to the NewRelic RPM service at NewRelic.com.
  # below.
  enabled: false

  # The newrelic agent generates its own log file to keep its logging information
  # separate from that of your application.  Specify its log level here.
  log_level: debug

  # The newrelic agent communicates with the RPM service via http by default.
  # If you want to communicate via https to increase security, then turn on
  # SSL by setting this value to true.  Note, this will result in increased
  # CPU overhead to perform the encryption involved in SSL communication, but this
  # work is done asynchronously to the threads that process your application code, so
  # it should not impact response times.
  ssl: false

  # Set your application's Apdex threshold value with the 'apdex_t' setting, in seconds. The
  # apdex_t value determines the buckets used to compute your overall Apdex score. Requests
  # that take less than apdex_t seconds to process will be classified as Satisfying transactions;
  # more than apdex_t seconds as Tolerating transactions; and more than four times the apdex_t
  # value as Frustrating transactions. For more
  # about the Apdex standard, see http://support.newrelic.com/faqs/general/apdex
  apdex_t: 1.0

  # Proxy settings for connecting to the RPM server.
  #
  # If a proxy is used, the host setting is required.  Other settings are optional.  Default
  # port is 8080.
  #
  # proxy_host: hostname
  # proxy_port: 8080
  # proxy_user:
  # proxy_pass:


  # Tells transaction tracer and error collector (when enabled) whether or not to capture HTTP params.
  # When true, the RoR filter_parameters mechanism is used so that sensitive parameters are not recorded
  capture_params: true


  # Transaction tracer captures deep information about slow
  # transactions and sends this to the RPM service once a minute. Included in the
  # transaction is the exact call sequence of the transactions including any SQL statements
  # issued.
  transaction_tracer:

    # Transaction tracer is enabled by default. Set this to false to turn it off. This feature
    # is only available at the Silver and above product levels.
    enabled: true


    # When transaction tracer is on, SQL statements can optionally be recorded. The recorder
    # has three modes, "off" which sends no SQL, "raw" which sends the SQL statement in its
    # original form, and "obfuscated", which strips out numeric and string literals
    record_sql: obfuscated

    # Threshold in seconds for when to collect stack trace for a SQL call. In other words,
    # when SQL statements exceed this threshold, then capture and send to RPM the current
    # stack trace. This is helpful for pinpointing where long SQL calls originate from
    stack_trace_threshold: 0.500

  # Error collector captures information about uncaught exceptions and sends them to RPM for
  # viewing
  error_collector:

    # Error collector is enabled by default. Set this to false to turn it off. This feature
    # is only available at the Silver and above product levels
    enabled: true

    # Tells error collector whether or not to capture a source snippet around the place of the
    # error when errors are View related.
    capture_source: true

    # To stop specific errors from reporting to RPM, set this property to comma separated
    # values
    #
    #ignore_errors: ActionController::RoutingError, ...


# override default settings based on your application's environment

# NOTE if your application has other named environments, you should
# provide newrelic conifguration settings for these enviromnents here.

development:
  <<: *default_settings
  # turn off communication to RPM service in development mode.
  # NOTE: for initial evaluation purposes, you may want to temporarily turn
  # the agent on in development mode.
  enabled: true

  # When running in Developer Mode, the New Relic Agent will present
  # performance information on the last 100 transactions you have
  # executed since starting the mongrel.  to view this data, go to
  # http://localhost:3000/newrelic
  developer: true
  app_name: #{@app_name} (Dev)

test:
  <<: *default_settings
  # it almost never makes sense to turn on the agent when running unit, functional or
  # integration tests or the like.
  enabled: false

# Turn on the agent in production for 24x7 monitoring.  NewRelic testing shows
# an average performance impact of < 5 ms per transaction, you you can leave this on
# all the time without incurring any user-visible performance degredation.
production:
  <<: *default_settings
  enabled: true

# many applications have a staging environment which behaves identically to production.
# Support for that environment is provided here.  By default, the staging environment has
# the agent turned on.
staging:
  <<: *default_settings
  enabled: true
  app_name: #{@app_name} (Staging)

  NR
end