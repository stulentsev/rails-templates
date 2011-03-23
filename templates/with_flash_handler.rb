file 'app/controllers/flash_base_controller.rb', <<-FLASH
class FlashController < ApplicationController

  before_filter :authenticate
  before_filter :init_state

  layout 'void'


  def send_friends
    profiles = JSON.parse(params[:profiles] || '[]')

    # save info for each user (to its shard)

    profiles.compact.each do |prof|
      next unless prof['uid']

      u              = VkUser.get_record(prof['uid'])
      u.first_name   = prof['first_name'];
      u.last_name    = prof['last_name'];
      u.sex          = prof['sex'].to_i
      u.photo        = prof['photo_rec']
      u.photo_medium = prof['photo_medium_rec']
      u.is_app_user  = prof['is_app_user'].to_i
      u.settings     = prof['settings'] ? prof['settings'].to_i : 0

      u.groups       ||= []
      # TODO: handle groups
      u.convert_groups

      u.put_record
    end

    # reload viewer to refresh balance changes
    init_viewer

    fr_uids          = JSON.parse(params[:fr_uids])
    @viewer.friends  = fr_uids

    @viewer.app_friends = JSON.parse(params[:app_fr_uids])

    msgs             = @viewer.messages
    @viewer.messages = []
    @viewer.put_record

    @answer      = {:ok          => 'ok',
                    :messages    => msgs,
                    :new_balance => @viewer.balance}
    render_answer
  end

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

  def render_answer answer = nil
    answer ||= @answer || {}
    render :json => answer, :content_type => 'application/json', :layout => false
  end


  private

  def make_purchase_for_votes cost, success_handler
    balance = VkApi.get_user_balance @viewer.id

    if balance < cost
      @answer = {:ok      => 'error',
                 :code    => 'not_enough_votes',
                 :cost    => cost / 100,
                 :balance => balance / 100}
    else
      money = VkApi.withdraw_votes @viewer.id, cost
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

  def authenticate
    return if Rails.env == 'development'

    viewer_id       = params[:viewer_id] #.to_s.gsub("\r\n", '')
    sent_auth_key   = params[:auth_key] #.to_s.gsub("\r\n", '')
#    mode = params[:test_mode] ? :test : :production
    api_id          = params[:api_id]

    auth_key_source = "\#{api_id}_\#{viewer_id || ''}_\#{VkApi.secret_api_secret(api_id)}"
    my_auth_key     = Digest::MD5.hexdigest(auth_key_source)

    if sent_auth_key != my_auth_key
      filename    = 'log/cheating.log'
      output_file = File.open(filename, 'a')

      output_file.puts(params.inspect)

      output_file.puts "source_string for auth_key: \#{auth_key_source}"
      output_file.puts "Calculated auth_key: \#{my_auth_key}"
      output_file.puts('')
      output_file.close

      throw Exception.new("Cheating? Нехорошо!")
    end

    # check my request signature
    sig_params = params.dup
    sent_sig   = sig_params.delete(:sig)

    sig_params.delete(:controller)
    sig_params.delete(:action)
    sig_params.delete(:id)

    test_str = "salty salt: f8fARyZjNv3Io1l8" + sig_params[:viewer_id].dup.to_s
    sig_params.stringify_keys.sort.each do |k, v|
      test_str << "\#{k}=\#{v}"
    end
    test_str << VkApi.api_secret(api_id)

    sig = Digest::MD5.hexdigest(test_str)


    if sent_sig != sig
      logger.warn "Sent sig: \#{sent_sig}"
      logger.warn "Calculated sig; \#{sig}"
      logger.warn "Test str; \#{test_str}"
      logger.warn "params: \#{sig_params.inspect}"

      filename    = 'log/cheating.log'
      output_file = File.open(filename, 'a')

      output_file.puts(params.inspect)
      output_file.puts('')
      output_file.close

      throw Exception.new("Cheating? Нехорошо! Плохой мальчик!")
    end
  end

  def init_state
    init_viewer

    if @viewer.status && @viewer.status == 3 && Time.now.to_i - @viewer.banned_at.to_i > 5*86400
      @viewer.status = nil
      @viewer.put_record
    end

    if @viewer.status && (@viewer.status == 1 || @viewer.status == 3) # banned
      logger.warn "Banned user \#{@viewer.id} is sending request for \#{params[:action]}"
      @answer = {:ok => 'banned'}
      render_answer
    end
  end

  def init_viewer
    viewer_id           = params[:viewer_id].to_i
    @viewer             = VkUser.get_record(viewer_id)
  end

end
FLASH

file 'app/models/vk_user.rb', <<-VKU
class VkUser
  include Mongoid::Document
  include Mongoid::Timestamps


  identity :type => Integer

  field :first_name
  field :last_name
  field :sex, :type => Integer, :default => 0
  field :is_app_user, :type => Integer, :default => 0
  field :photo
  field :photo_medium

  field :banned_at, :type => DateTime
  field :approver_status, :type => Integer

  field :friends, :type => Array
  field :app_friends, :type => Array

  def self.get_record id
    id = id.to_i

    if id == 0 || id == '0'
      Rails.logger.warn "Trying to get vk_user with id=0"
      return nil
    end

    user = VkUser.find_or_create_by(:_id => id)

    return user
  end

  def put_record
    save!
  end

  #alias :old_save :save

  def full_name
    "\#{first_name} \#{last_name}"
  end

  # attr_changes specifies which fields to include and which to remove
  # EXAMPLE: to_compact_hash :daily_counter_count => true, :photo_medium => false, :photo_big => false
  def to_compact_hash attr_changes = {}
    res = {
        :uid          => _id,
        :first_name   => first_name,
        :last_name    => last_name,
        :sex          => sex,
        :photo        => photo,
        :photo_medium => photo_medium
    }

    attr_changes.each do |k, should_include|
      if should_include
        res[k] = attributes[k]
      else
        res.delete(k)
      end
    end

    res
  end
end
VKU

puts "Don't forget to check identity of VkUser"

prod_app_id = ask("What's your production APP ID?")
staging_app_id = ask("What's your testing APP ID (press ENTER to skip)")

apps = staging_app_id.empty? ? [prod_app_id] : [prod_app_id, staging_app_id]

lib 'vk_api.rb', <<-VKAPI
class VkApi

  API_ID = #{apps}
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

      last_id = ids.last

      break unless last_id != nil

      total_count += ids.length

      chunk_length = 100

      (ids.length.to_f / chunk_length).ceil.times do |chunk_num|
        part = ids.slice(chunk_num * chunk_length, chunk_length)

        actual_sent_arr = VkApi.send_notifications(msg, part)
        QUEUE[UPDATE_APP_USER_QUEUE] = actual_sent_arr
        actual_sent += actual_sent_arr.length
        processed += part.length

        elapsed = Time.now - total_start
        rate = (processed == 0 || elapsed == 0) ? 0 : processed / elapsed
        rate2 = (processed == 0 || elapsed == 0) ? 0 : actual_sent / elapsed

        print "\rMessage is sent to (#{actual_sent} | #{last_id}, #{processed})  of #{total_count}, time elapsed: #{elapsed.to_i} secs, rate: #{rate2.to_i} and  #{rate.to_i} ups"
        STDOUT.flush
#          sleep(0.1)
      end

    end
    puts "\nTime taken: #{Time.now - shard_start}, total: #{Time.now - total_start}"
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
    msg = msg.gsub("\"", "").gsub("'", '')
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

lib 'utils.rb', <<-UTILS
def convert_db_id str
  #4d50 b64b 9b3b 491e 7300 0011
  if str.is_a?(String) && str.length == 24
    return str
  end

  str.to_i
end

def get_from_random_server(key)
  idx = rand(DATA_CACHE.length)
  DATA_CACHE[idx][key]
end

def store_to_all_servers key, value

  DATA_CACHE.each do |cache|
    cache[key] = value
  end
end

def declense num, noun_root, for_1, for_234, for_56789, for_teen
  if num >= 11 && num <= 19
    noun_root + for_teen
  elsif num % 10 == 1
    noun_root + for_1
  elsif [2,3,4].member?(num % 10)
    noun_root + for_234
  else
    noun_root + for_56789
  end
end

def friendlify_date date
  elapsed = Time.now - date

  if elapsed < 60
    # less than a minute
    'только что'
  elsif elapsed < 60 * 60
    # less than an hour
    how_many = (elapsed / 60).to_i
    what = declense(how_many, 'минут', 'а', 'ы', '', '')
    "\#{how_many} \#{what} назад"

  elsif elapsed < 24 * 60 * 60
    # less than a day
    how_many = (elapsed / (60 * 60)).to_i
    what = declense(how_many, 'час', '', 'а', 'ов', 'ов')
    "\#{how_many} \#{what} назад"

  elsif elapsed < 7 * 24 * 60 * 60
    # less then a week
    how_many = (elapsed / (24 * 60 * 60)).to_i
    what = declense(how_many, '', 'день', 'дня', 'дней', 'дней')
    "\#{how_many} \#{what} назад"
  else
    date.strftime('%d.%m.%y')
  end
end
UTILS