# Very (maybe too) simple IRC client that is used for IRC notifications.
#
# based on:
# https://github.com/sr/shout-bot
#
# other libs to take note of:
# https://github.com/tbuehlmann/ponder
# https://github.com/cinchrb/cinch
# https://github.com/cho45/net-irc
require 'socket'
require 'openssl'

module Travis
  class Task
    class Irc
      class Client
        attr_accessor :channel, :socket, :ping_thread, :numeric_received

        def self.wrap_ssl(socket)
          ssl_context = OpenSSL::SSL::SSLContext.new
          ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE # XXX
          OpenSSL::SSL::SSLSocket.new(socket, ssl_context).tap do |sock|
            sock.sync = true
            sock.connect
          end
        end

        def initialize(server, nick, options = {}, skip_numeric = false)
          @socket = TCPSocket.open(server, options[:port] || 6667)
          @socket = self.class.wrap_ssl(@socket) if options[:ssl]

          @ping_thread = start_ping_thread
          @numeric_received = skip_numeric

          socket.puts "PASS #{options[:password]}" if options[:password]
          socket.puts "NICK #{nick}"
          socket.puts "USER #{nick} #{nick} #{nick} :#{nick}"
        end

        def wait_for_numeric
            # Loop until we get a numeric (second word is a 3-digit number).
          until @numeric_received
            sleep 0.1
          end
        end

        def join(channel, key = nil)
          socket.puts "JOIN ##{channel} #{key}".strip
        end

        def run(&block)
          yield(self) if block_given?
        end

        def leave(channel)
          socket.puts "PART ##{channel}"
        end

        def say(message, channel, use_notice = false)
          message_type = use_notice ? "NOTICE" : "PRIVMSG"
          socket.puts "#{message_type} ##{channel} :#{message}"
        end

        def quit
          socket.puts 'QUIT'
          socket.gets until socket.eof?
          socket.close
          ping_thread.exit
        end

        private

          def start_ping_thread
            Thread.new(socket) do |s|
              loop do
                  case s.gets
                  when /^PING (.*)/
                    s.puts "PONG #{$1}"
                  when /^:\S+ \d{3} .*$/
                    @numeric_received = true
                  end
              end
            end
          end
      end
    end
  end
end
