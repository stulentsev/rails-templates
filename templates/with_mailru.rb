
mm_app_id = ask("What's your Mailru APP ID?  ")

if mm_app_id.length > 0

  download_file 'http://connect.mail.ru/receiver.html', 'public/receiver.html'

  file 'app/controllers/mm_controller.rb', <<-MMCONTROLLER
  class MmController < FlashBaseController
    skip_before_filter :authenticate
    before_filter :authenticate, :except => [:wrapper, :payment]


    def wrapper
      @swfurl = "http://cdn7.appsmail.ru/hosting/#{mm_app_id}/preloader_mm.swf"

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

route <<-RT
  resources :mm do
    collection do
      post  :send_friends
    end
  end

RT

