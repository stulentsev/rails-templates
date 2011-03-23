route "match 'heartbeat' => 'pulse#pulse'"

file 'app/controllers/pulse_controller', <<-PULSE
class PulseController < ActionController::Base
  session :off

  #The pulse action. Runs <tt>select 1</tt> on the DB. If a sane result is
  #returned, 'OK' is displayed and a 200 response code is returned. If not,
  #'ERROR' is returned along with a 500 response code.
  def pulse
    begin
      # just get some small object from the DB
      User.first
      render :text => "<html><body>OK  \#{Time.now.utc.to_s(:db)}</body></html>"
    rescue Exception => ex
      render :text => '<html><body>ERROR</body></html>', :status => :internal_server_error
    end

  end

  #cancel out loggin for the PulseController by defining logger as <tt>nil</tt>
  def logger
    nil
  end
end
PULSE