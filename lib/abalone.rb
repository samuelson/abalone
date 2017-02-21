require 'json'
require 'logger'
require 'sinatra/base'
require 'sinatra-websocket'

class Abalone < Sinatra::Base
  set :logging, true
  set :strict, true
  set :protection, :except => :frame_options
  set :public_folder, "#{settings.root}/../public"
  set :views, "#{settings.root}/../views"

  before {
    env["rack.logger"] = settings.logger if settings.logger

    trap('INT') do
      # this forces all the spawned children to terminate as well
      puts "Caught SIGINT. Terminating active sessions (#{Process.pid}) now."
      exit!
    end

  }

  # super low cost heartbeat response.
  # Add this first to ensure that the user route doesn't take precedence.
  get '/heartbeat/ping' do
    'alive'
  end

  get '/?:user?' do
    if !request.websocket?
      @requestUsername = (settings.respond_to?(:ssh) and ! settings.ssh.include?(:user)) rescue false
      @autoconnect     = settings.autoconnect
      erb :index
    else
      request.websocket do |ws|

        ws.onopen do
          warn("websocket opened")
          @terminal = Abalone::Terminal.new(settings, ws, sanitized(params))
        end

        ws.onclose do
          warn('websocket closed')
          @terminal.stop if @terminal
        end

        ws.onmessage do |message|
          message = JSON.parse(message)

          begin
            case message['event']
            when 'input'
              @terminal.write(message['data'])

            when 'resize'
              row = message['row']
              col = message['col']
              @terminal.resize(row, col)

            when 'logout', 'disconnect'
              warn("Client exited.")
              @terminal.stop()

            else
              warn("Unrecognized message: #{message.inspect}")
            end
          rescue Errno::EIO => e
            puts "Remote terminal closed."
            puts e.message
            @terminal.stop()

          end

        end
      end
    end
  end

  not_found do
    halt 404, "You shall not pass! (page not found)\n"
  end

  helpers do

    def sanitized(params)
      params.reject do |key,val|
        ['captures','splat'].include?(key) or not allowed(key, val)
      end
    end

    def allowed(param, value)
      return false unless settings.params.include? param

      config = settings.params[param]
      return true if config.nil?
      return true unless config.include? :values

      config[:values].each do |pattern|
        case pattern
        when String
          return true if value == pattern
        when Regexp
          return true if pattern.match(value)
        end
      end

      false
    end

  end
end
