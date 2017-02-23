require 'pty'
require 'io/console'
require 'abalone/buffer'

class Abalone::Terminal
  def initialize(settings, ws, params)
    @settings = settings
    @ws       = ws
    @params   = params
    @buffer   = Abalone::Buffer.new

    ENV['TERM'] ||= 'xterm' # make sure we've got a somewhat sane environment

    if settings.respond_to?(:bannerfile)
      @ws.send({'data' => File.read(settings.bannerfile).encode(crlf_newline: true)}.to_json)
      @ws.send({'data' => "\r\n\r\n"}.to_json)
    end

    reader, @writer, @pid = PTY.spawn(*shell_command)
    @writer.winsize = [24,80]

    # there must be some form of event driven pty interaction, EM or some gem maybe?
    reader.sync = true
    @term = Thread.new do
      carry = []
      loop do
        begin
          PTY.check(@pid, true)
          output = reader.read_nonblock(512).unpack('C*') # we read non-blocking to stream data as quickly as we can
          last_low = output.rindex { |x| x < 128 } # find the last low bit
          trailing = last_low +1

          # use inclusive slices here
          data  = (carry + output[0..last_low]).pack('C*').force_encoding('UTF-8') # repack into a string up until the last low bit
          carry = output[trailing..-1]             # save the any remaining high bits and partial chars for next go-round

          @ws.send({'data' => data}.to_json)

        rescue IO::WaitReadable
          IO.select([reader])
          retry

        rescue PTY::ChildExited => e
          warn('Terminal has exited!')
          @ws.close_connection

          @timer.terminate rescue nil
          @timer.join rescue nil
          Thread.exit
        end

        sleep(0.05)
      end
    end

    if @settings.respond_to? :timeout
      @timer = Thread.new do
        expiration = Time.now + @settings.timeout
        loop do
          remaining = expiration - Time.now
          if remaining < 0
            terminate!
            exit
          end

          time = {
            'event' => 'time',
            'data'  => Time.at(remaining).utc.strftime("%H:%M:%S"),
          }
          ws.send(time.to_json)
          sleep 1
        end
      end
    end
  end

  def alive?
    @term.alive?
  end

  def reconnect(ws)
    if @ttl # stop the countdown
      warn "Stopping timeout"
      @ttl.terminate rescue nil
      @ttl.join rescue nil
      @ttl = nil
    end
    @ws = ws
    @ws.send({'data' => @buffer.replay}.to_json)
    @writer.write "\cl" # ctrl-l forces a screen redraw
  end

  def write(message)
    @writer.write message
  end

  def stop!
    if @settings.respond_to? :ttl
      @ws  = @buffer
      @ttl = Thread.new do
        warn "Providing a shutdown grace period of #{@settings.ttl} seconds."
        sleep @settings.ttl
        terminate!
      end
    else
      terminate!
    end
  end

  def terminate!
    warn "Terminating session."
    Process.kill('TERM', @pid) rescue nil
    sleep 1
    Process.kill('KILL', @pid) rescue nil
    @term.join rescue nil
  end

  def resize(rows, cols)
    @writer.winsize = [rows, cols]
  end

  private
  def shell_command
    if @settings.respond_to? :command
      return @settings.command unless @settings.respond_to? :params

      command = @settings.command
      command = command.split if command.class == String

      @params.each do |param, value|
        config = @settings.params[param]
        case config
        when nil
          command << "--#{param}" << value
        when Hash
          command << (config[:map] || "--#{param}")
          command << value
        end
      end

      return command
    end

    if @settings.respond_to? :ssh
      config = @settings.ssh.dup
      config[:user] ||= @params['user'] # if not in the config file, it must come from the user

      if config[:user].nil?
        warn "SSH configuration must include the user"
        return ['echo', 'no username provided']
      end

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