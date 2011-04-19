
prod_app_id = ask("What's your Mailru APP ID?  ")
staging_app_id = ask("What's your Mailru testing APP ID (press ENTER to skip)?  ")

apps = staging_app_id.empty? ? [prod_app_id] : [prod_app_id, staging_app_id]

if prod_app_id.length > 0

  download_file 'http://connect.mail.ru/receiver.html', 'public/receiver.html'

  file 'app/controllers/mm_controller.rb', <<-MMCONTROLLER
  require 'net/http'

  class MmController < FlashBaseController
    skip_before_filter :authenticate
    before_filter :authenticate, :except => [:wrapper, :payment]


    def wrapper
      @swfurl = "http://cdn7.appsmail.ru/hosting/#{prod_app_id}/preloader_mm.swf"

      @flashvars_js = ''
      params.each do |k, v|
        @flashvars_js << "flashvars.\#{k.to_s} = \#{v.inspect};"
      end
    end

    def payment
      render_answer :status => 1
    end

    private

    def make_purchase_for_roubles cost, success_handler
      credit_roubles = @viewer['credit_roubles']
      if credit_roubles && credit_roubles >= cost
        @viewer.credit_roubles -= cost
        @viewer.save
        success_handler.call(cost) if success_handler
      else
        @answer = {:ok => 'error',
                   :code => 'not_enough_money'}

      end
    end

    def make_purchase_for_sms cost, success_handler
      credit_sms = @viewer['credit_sms']
      if credit_sms && credit_sms >= cost
        @viewer.credit_sms -= cost
        @viewer.save
        success_handler.call(cost) if success_handler
      else
        @answer = {:ok => 'error',
                   :code => 'not_enough_money'}

      end
    end

    def params_viewer_id
      params[:vid] || params[:viewer_id]
    end

    def init_state
      params[:viewer_id] ||= params[:vid]

      super
    end
  end
  MMCONTROLLER

  file 'app/views/mm/wrapper.html.erb', <<-WRAPPER
  <style type="text/css" media="screen">
      * {
          margin: 0;
          padding: 0; /*font-size: 0;*/
      /*line-height: 0;*/
      }

      iframe {
          border: 0;
      }

  </style>
  <%= javascript_include_tag 'http://ajax.googleapis.com/ajax/libs/swfobject/2.2/swfobject.js' %>
  <%= javascript_include_tag 'http://connect.mail.ru/js/loader.js' %>
  <script type="text/javascript">
      var flashvars = {};
  </script>
  <%= javascript_tag @flashvars_js %>
  <%= javascript_tag "var no_cache = \#{rand(1_000_000)};" %>
  <%= javascript_tag "var swfurl = '\#{@swfurl}';" %>

  <script type="text/javascript">

      var params = {};
      params.AllowScriptAccess = "always";
      params.allowNetworking = "all";
      params.allowFullScreen = "true";

      var attributes = {};
      attributes.id = "flash-app";
      attributes.name = "flash-app";

      var swfurl = swfurl + '?nc=' + no_cache;
      swfobject.embedSWF(swfurl, "flash-app", "730", "600", "10.0.0", false, flashvars, params, attributes);
  </script>

  <div id='flash-app'></div>

  <div>
    С вопросами и предложениями - в <a href='http://my.mail.ru/community/42bytes/' target="_blank">группу</a>.
  </div>
  WRAPPER
end

lib 'mailru_api.rb', <<-MMAPI
require 'uri'

class MailruApi

  API_ID = #{apps.inspect}
  API_SECRET = {}
  SECRET_API_SECRET = {}

  @@api_id = nil

  def self.api_secret aid
    aid = aid.to_s
    return '' unless API_ID.member?(aid)

    val = API_SECRET[aid]
    unless val
      get_app_config aid
      val = api_secret aid
    end
    @@api_id = aid
    val
  end

  def self.secret_api_secret aid
    aid = aid.to_s
    return '' unless API_ID.member?(aid)

    val = SECRET_API_SECRET[aid]
    unless val
      get_app_config aid
      val = secret_api_secret aid
    end
    @@api_id = aid
    val
  end


  def self.perform_mass_mailing msg, first_n = nil, start_from = nil

    total_start = Time.now
    page_size = 5_000

    processed = 0
    actual_sent = 0
    total_count = 0

    last_id = start_from || 1

    shard_start = Time.now
    loop do
      break unless !first_n || (first_n && processed <= first_n)

#      ids = VkUser.where(:is_app_user => 1).only(:_id).where(:_id => {'$gt' => last_id}).asc(:_id).limit(page_size).map(&:id)
      ids = VkUser.only(:_id).where(:_id => {'$gt' => last_id}).asc(:_id).limit(page_size).map(&:id)


      break unless last_id != nil

      total_count += ids.length

      chunk_length = 100

      (ids.length.to_f / chunk_length).ceil.times do |chunk_num|
        part = ids.slice(chunk_num * chunk_length, chunk_length)

        begin
          begin
            actual_sent_arr = send_notifications(msg, part)
          rescue Exception => ex
            win1251 = Iconv.new('utf-8', "windows-1251")
            err = win1251.iconv(ex.message)
            puts ''
            puts err
            puts ''
            sleep(1)
          end
        end while actual_sent_arr.nil?

        QUEUE[UPDATE_APP_USER_QUEUE] = actual_sent_arr
        actual_sent += actual_sent_arr.length
        processed += part.length

        elapsed = Time.now - total_start
        rate = (processed == 0 || elapsed == 0) ? 0 : processed / elapsed
        rate2 = (processed == 0 || elapsed == 0) ? 0 : actual_sent / elapsed

        print "\\rMessage is sent to (\#{actual_sent} | \#{last_id}, \#{processed})  of \#{total_count}, time elapsed: \#{elapsed.to_i} secs, rate: \#{rate2.to_i} and  \#{rate.to_i} ups"
        STDOUT.flush
#          sleep(0.1)
      end
      last_id = ids.last

    end
    puts "\\nTime taken: \#{Time.now - shard_start}, total: \#{Time.now - total_start}"
    puts ""
  end

  def self.send_notifications msg, *vk_ids
    msg = msg.gsub("\"", "").gsub("'", '')
    processed = []
    chunk_length = 100

    vk_ids = vk_ids.flatten

    (vk_ids.length.to_f / chunk_length).ceil.times do |chunk_num|
      part = vk_ids.slice(chunk_num * chunk_length, chunk_length)
      reply = send_secure_request('notifications.send', :uids => part.join(','), :text => msg)
      response = reply
      if response
        processed = response
      else
        puts reply.inspect
        break
      end
    end

    processed
  end


  def self.send_secure_request method_name, additional_params = {}
    aid = @@api_id || API_ID.last
    parms = {:app_id => aid,
             :method => method_name,
            :secure => 1,
             :format => 'json'}.merge(additional_params)

    parms[:sig] = get_signature(aid, parms)
    url = 'http://www.appsmail.ru/platform/api'
    res = JSON.parse(Net::HTTP.post_form(URI.parse(url), parms.stringify_keys).body)

    if res.is_a?(Hash) && res['error']
      begin
        error_log = File.new 'log/mm_api_errors.log', 'a'
        error_log.puts "Calling method \#{method_name} with params \#{parms.inspect}, got result: \#{res.inspect}"
      ensure
        error_log.close
      end
    end

    return res
  end

  def self.get_app_config aid
    aid = aid.to_s

    Rails.logger.warn "Getting app config for app\#{aid}"
    stats_url = "http://counter.42bytes.ru/flash/get_apps?api_id=\#{aid}&access_token=Fz4myLSP27x6i5n"
    data = JSON.parse(Net::HTTP.get URI.parse(stats_url))

    Rails.logger.warn "Got: \#{data.inspect}"
    app = data['apps'][aid]

    API_SECRET[aid] = app['private_key']
    SECRET_API_SECRET[aid] = app['secret_key']
  end

  def self.get_signature aid, parameters = {}
    str = ""
    parameters.stringify_keys.sort.each do |k, v|
      str << "\#{k}=\#{v}"
    end
    str << secret_api_secret(aid)

    Digest::MD5.hexdigest(str)
  end

end

MMAPI


route <<-RT
resources :mm do
  collection do
    post  :send_friends
  end
end
RT

