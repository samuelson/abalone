require 'json'
class Abalone::Buffer
  def initialize
    @buffer = ''
  end

  def send(message)
    @buffer << JSON.parse(message)['data']
  rescue
    nil
  end

  def close_connection
    # nop
  end

  def replay
    retval  = @buffer
    @buffer = ''
    retval
  end
end