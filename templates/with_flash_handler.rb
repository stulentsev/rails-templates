file 'app/controllers/flash_base_controller.rb', <<-FLASH
class FlashBaseController < ApplicationController

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


  def render_answer answer = nil
    answer ||= @answer || {}
    render :json => answer, :content_type => 'application/json', :layout => false
  end


  private

  def authenticate
    return if Rails.env == 'development'

    viewer_id       = params[:viewer_id] #.to_s.gsub("\\r\\n", '')
    sent_auth_key   = params[:auth_key] #.to_s.gsub("\\r\\n", '')
#    mode = params[:test_mode] ? :test : :production
    api_id          = params[:api_id]

    auth_key_source = "\#{api_id}_\#{viewer_id || ''}_\#{SN_API.secret_api_secret(api_id)}"
    my_auth_key     = Digest::MD5.hexdigest(auth_key_source)

    if sent_auth_key != my_auth_key
      filename    = 'log/cheating.log'
      output_file = File.open(filename, 'a')

      output_file.puts(params.inspect)

      output_file.puts "source_string for auth_key: \#{auth_key_source}"
      output_file.puts "Calculated auth_key: \#{my_auth_key}"
      output_file.puts('')
      output_file.close

      throw Exception.new("Cheating? Not good!")
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
    test_str << SN_API.api_secret(api_id)

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

      throw Exception.new("Cheating? Bad boy!")
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

puts red("Don't forget to check identity of VkUser")


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