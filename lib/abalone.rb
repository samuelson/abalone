require 'json'
require 'logger'
require 'sinatra/base'
require 'sinatra-websocket'

require 'pty'
require 'io/console'

class Abalone < Sinatra::Base
  set :logging, true
  set :strict, true
  set :public_folder, 'public'
  set :views, 'views'

  before {
    env["rack.logger"] = settings.logger if settings.logger
  }

  get '/?:user?' do
    if !request.websocket?
      #redirect '/index.html'
      @requestUsername = (settings.respond_to?(:ssh) and ! settings.ssh.include?(:user)) rescue false
      erb :index
    else
      request.websocket do |ws|

        ws.onopen do
          warn("websocket opened")
          reader, @writer, @pid = PTY.spawn(*shell_command)
          @writer.winsize = [24,80]

#           reader.sync = true
#           EM.add_periodic_timer(0.05) do
#             begin
#               PTY.check(@pid, true)
#               data = reader.read_nonblock(512) # we read non-blocking to stream data as quickly as we can
#               ws.send({'event' => 'output', 'data' => data}.to_json)
#             rescue IO::WaitReadable
#               # nop
#             rescue PTY::ChildExited => e
#               puts "Terminal has exited!"
#               ws.send({'event' => 'logout'}.to_json)
#             end
#           end

          # there must be some form of event driven pty interaction, EM or some gem maybe?
          reader.sync = true
          @term = Thread.new do
            loop do
              begin
                PTY.check(@pid, true)
                data = reader.read_nonblock(512) # we read non-blocking to stream data as quickly as we can
              rescue IO::WaitReadable
                IO.select([reader])
                retry
              rescue PTY::ChildExited => e
                puts "Terminal has exited!"
                ws.send({'event' => 'logout'}.to_json)
                Thread.exit
              end
              ws.send({'event' => 'output', 'data' => data}.to_json)
              sleep(0.05)
            end
          end

        end

        ws.onclose do
          warn("websocket closed")
          stop_term()
        end

        ws.onmessage do |message|
          message = JSON.parse(message)

          begin
            case message['event']
            when 'input'
              @writer.write message['data']

            when 'resize'
              row = message['row']
              col = message['col']
              @writer.winsize = [row, col]

            when 'logout', 'disconnect'
              warn("Client exited.")
              stop_term()

            else
              warn("Unrecognized message: #{message.inspect}")
            end
          rescue Errno::EIO => e
            puts "Terminal has died!"
            puts e.message
            ws.send({'event' => 'logout'}.to_json)
          end

        end
      end
    end
  end

  not_found do
    halt 404, "You shall not pass! (page not found)\n"
  end

  helpers do
    def stop_term()
      Process.kill('TERM', @pid) rescue nil
      @term.join
    end

    def shell_command()
      return settings.command if settings.respond_to? :command

      if settings.respond_to? :ssh
        config = settings.ssh.dup
        raise "SSH configuration should be a Hash, not a #{config.class}." unless config.class == Hash

        config[:user] ||= params['user']
        raise "SSH configuration must include the host" unless config.include? :host
        raise "SSH configuration must include the user" unless config.include? :user

        command = ['ssh', config[:host] ]
        command << '-l' << config[:user] if config.include? :user
        command << '-p' << config[:port] if config.include? :port
        command << '-i' << config[:cert] if config.include? :cert

        return command
      end

      # default just to running login
      'login'
    end
  end
end
