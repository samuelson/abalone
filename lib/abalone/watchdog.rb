class Abalone::Watchdog
  def initialize(period, options)
    raise 'Watchdog needs a port to be set' unless options.include? :port
    raise 'Watchdog needs a logger to be set' unless options.include? :logger
    logger = options[:logger]

    Thread.new do
      require 'net/http'
      sleep 5 # give the service time to wake up

      logger.warn "Starting watchdog with period #{period}"
      loop do
        http = Net::HTTP.new('localhost', options[:port])
        http.open_timeout = 1
        http.read_timeout = 1
        begin
          http.start
          http.request_get('/heartbeat/ping') do |res|
            logger.debug "Heartbeat response: #{res.read_body}"
            system('systemd-notify WATCHDOG=1')
          end
        rescue => e
          logger.warn 'Abalone service failed heartbeat check!'
          logger.debug e.message
        end

        sleep period
      end
    end
  end
end
