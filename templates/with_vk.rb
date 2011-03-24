prod_app_id = ask("What's your VK production APP ID?")
staging_app_id = ask("What's your VK testing APP ID (press ENTER to skip)")

apps = staging_app_id.empty? ? [prod_app_id] : [prod_app_id, staging_app_id]

lib 'vk_api.rb', <<-VKAPI
class VkApi

  API_ID = #{apps.inspect}
  API_SECRET = {}
  SECRET_API_SECRET = {}

  GET_USER_BALANCE = 'secure.getBalance'
  GET_APP_BALANCE = 'secure.getAppBalance'
  ADD_VOTES = 'secure.addVotes'
  WITHDRAW_VOTES = 'secure.withdrawVotes'
  TRANSFER_VOTES = 'secure.transferVotes'
  SEND_NOTIFICATION = 'secure.sendNotification'
  SEND_SMS_NOTIFICATION = 'secure.sendSMSNotification'
  GET_TRANSACTIONS_HISTORY = 'secure.getTransactionsHistory'


  @@api_id = nil

  def self.api_secret aid
    return '' unless API_ID.member?(aid.to_s)

    val = API_SECRET[aid]
    unless val
      get_app_config aid
      val = api_secret aid
    end

    @@api_id = aid
    val
  end

  def self.secret_api_secret aid
    return '' unless API_ID.member?(aid.to_s)

    val = SECRET_API_SECRET[aid]
    unless val
      get_app_config aid
      val = secret_api_secret aid
    end
    @@api_id = aid
    val
  end


  def self.get_user_balance vk_id
    send_secure_request(GET_USER_BALANCE, :uid => vk_id)['response'].to_i
  end

  def self.get_app_balance
    send_secure_request(GET_APP_BALANCE)['response'].to_i
  end

  def self.add_votes vk_id, value
    send_secure_request(ADD_VOTES, :uid => vk_id, :votes => value)
  end

  def self.withdraw_votes vk_id, value
    send_secure_request(WITHDRAW_VOTES, :uid => vk_id, :votes => value)['response'].to_i
  end

  def self.transfer_votes vk_from, vk_to, value
    send_secure_request(TRANSFER_VOTES,
                        :uid_from => vk_from,
                        :uid_to => vk_to,
                        :votes => value)
  end

  def self.add_rating vk_id, rate, msg = ''
    send_secure_request 'secure.addRating',
                        :uid     => vk_id,
                        :rate    => rate,
                        :message => msg
  end

  def self.set_counter uid, counter
    send_secure_request 'secure.setCounter',
                        :uid => uid,
                        :counter => counter
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
            actual_sent_arr = VkApi.send_notifications(msg, part)
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

        print "\rMessage is sent to (\#{actual_sent} | \#{last_id}, \#{processed})  of \#{total_count}, time elapsed: \#{elapsed.to_i} secs, rate: \#{rate2.to_i} and  \#{rate.to_i} ups"
        STDOUT.flush
#          sleep(0.1)
      end
      last_id = ids.last

    end
    puts "\nTime taken: \#{Time.now - shard_start}, total: \#{Time.now - total_start}"
    puts ""
  end

  def self.send_notifications msg, *vk_ids
    processed = []
    chunk_length = 100

    vk_ids = vk_ids.flatten

    (vk_ids.length.to_f / chunk_length).ceil.times do |chunk_num|
      part = vk_ids.slice(chunk_num * chunk_length, chunk_length)
      reply = send_secure_request(SEND_NOTIFICATION, :uids => part.join(','), :message => msg)
      response = reply['response']
      if response
        response.split(',').map { |n| n.to_i }.each { |a| processed << a }
      else
        puts reply.inspect
        break
      end
    end

    processed
  end

  def self.send_sms msg, vk_id
    response = send_secure_request(SEND_SMS_NOTIFICATION, :uid => vk_id, :message => msg)['response']

    response
  end

  def self.get_transaction_history type = 0, uid_from = nil, uid_to = nil, date_from = nil, date_to = nil, limit = nil
    parms = {:type => type}

    parms.merge!({:uid_from => uid_from}) if uid_from
    parms.merge!({:uid_to => uid_to}) if uid_to
    parms.merge!({:date_from => date_from}) if date_from
    parms.merge!({:date_to => date_to}) if date_to
    parms.merge!({:limit => limit}) if limit

    send_secure_request GET_TRANSACTIONS_HISTORY, parms
  end

  def self.send_secure_request method_name, additional_params = {}
    aid   = @@api_id || API_ID[0]
    parms = {:api_id => aid,
             :method => method_name,
             :v => '2.0',
             :format => 'JSON',
             #:test_mode => 1,
             :random => rand,
             :timestamp => Time.now.to_i}.merge(additional_params)
    parms[:sig] = get_signature(aid, parms)
    url = 'http://api.vkontakte.ru/api.php'
    return JSON.parse(Net::HTTP.post_form(URI.parse(url), parms.stringify_keys).body)
  end

  def self.get_app_config aid
    aid = aid.to_s

    cache_key = "app_config_\#{aid}"
    app = get_from_random_server cache_key

    unless app
      Rails.logger.warn "Getting app config for app\#{aid}"
      stats_url = "http://counter.42bytes.ru/flash/get_apps?api_id=\#{aid}&access_token=Fz4myLSP27x6i5n"
      data = JSON.parse(Net::HTTP.get URI.parse(stats_url))

      Rails.logger.warn "Got: \#{data.inspect}"
      app = data['apps'][aid]
      store_to_all_servers cache_key, app
    end

    API_SECRET[aid] = app['private_key']
    SECRET_API_SECRET[aid] = app['secret_key']
  end

  def self.get_signature aid, parameters = {}
    aid = aid.to_s

    str = ""
    parameters.stringify_keys.sort.each do |k, v|
      str << "\#{k}=\#{v}"
    end
    str << secret_api_secret(aid)

    Digest::MD5.hexdigest(str)
  end

end
VKAPI


file 'app/controllers/flash_controller.rb', <<-MMCONTROLLER
class FlashController < FlashBaseController

#  def buy_coins
#    # update balance for viewer
#    num_votes        = params[:num_votes].to_i
#
#    coins_to_receive =
#        case num_votes
#          when 1
#            30 #20 #40
#          when 2
#            70 #50 #100
#          when 3
#            110 #90 #180
#          else
#            0
#        end
#
#    success_handler  = lambda do
#      @viewer.balance += coins_to_receive
#      @viewer.put_record
#
#      Purchase.create(:amount_votes => num_votes,
#                      :buyer_id     => @viewer.id)
#
#      @answer = {:ok          => 'ok',
#                 :new_balance => @viewer.balance}
#    end
#
#
#    make_purchase_for_votes num_votes * 100, success_handler
#    render_answer
#  end

  private

  def make_purchase_for_votes cost, success_handler
    balance = SN_API.get_user_balance @viewer.id

    if balance < cost
      @answer = {:ok      => 'error',
                 :code    => 'not_enough_votes',
                 :cost    => cost / 100,
                 :balance => balance / 100}
    else
      money = SN_API.withdraw_votes @viewer.id, cost
      if money == cost
        success_handler.call(cost) if success_handler
      else
        @answer = {:ok      => 'error',
                   :code    => 'couldnt_withdraw_enough_votes',
                   :cost    => cost / 100,
                   :balance => balance / 100}
      end
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

route <<-RT
resources :flash do
  collection do
    post  :send_friends
  end
end
RT