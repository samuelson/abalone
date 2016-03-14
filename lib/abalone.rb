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

  before {
    env["rack.logger"] = settings.logger if settings.logger
  }

  get '/' do
    if !request.websocket?
      redirect '/index.html'
    else
      request.websocket do |ws|
        ws.onopen do
          warn("websocket opened")
          reader, @writer, @pid = PTY.spawn(login_binary)
          @writer.winsize = [24,80]

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
              sleep(0.01)
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

    def login_binary()
      [ '/bin/login', '/usr/bin/login' ].each do |path|
        return path if File.executable? path
      end
      raise 'No login binary found.'
    end
  end
end
