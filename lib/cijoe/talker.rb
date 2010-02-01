require 'net/https'
require 'uri'

class CIJoe
  module Talker
    class TalkerRoom
      def initialize(subdomain, options)
        @subdomain  = subdomain
        @ssl        = options[:ssl]
        @room_id    = options[:room]
        @token      = options[:token]
      end

      def leave
      end

      def speak msg
        send msg
      end

      def paste msg
        send msg
      end

    private

      def send msg
        uri = URI.parse("https://#{@subdomain}.talkerapp.com/rooms/#{@room_id}/messages.json")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        request = Net::HTTP::Post.new(uri.request_uri)
        request['X-Talker-Token'] = @token
        request['Accept']         = 'application/json'
        request['Content-Type']   = 'application/json'
        params = {:message => msg}
        request.set_form_data params
        response = http.request(request)
      end
    end

    def self.activate
      if valid_config?

        CIJoe::Build.class_eval do
          include CIJoe::Talker
        end

        puts "Loaded Talker notifier"
      else
        puts "Can't load Talker notifier."
        puts "Please add the following to your project's .git/config:"
        puts "[talker]"
        puts "\ttoken = yourtalkertoken"
        puts "\tsubdomain = whatever"
        puts "\troom_id = nnn"
        puts "\tssl = false"
      end
    end

    def self.config
      @config ||= {
        :subdomain  => Config.talker.subdomain.to_s,
        :token      => Config.talker.token.to_s,
        :room       => Config.talker.room.to_s,
        :ssl        => Config.talker.ssl.to_s.strip == 'true'
      }
    end

    def self.valid_config?
      %w( subdomain token room ).all? do |key|
        !config[key.intern].empty?
      end
    end

    def notify
      room.speak "#{short_message}. #{commit.url}"
      room.paste full_message if failed?
      room.leave
    end

  private
    def room
      @room ||= begin
        config = Talker.config
        options = {}
        options[:ssl] = config[:ssl] ? true : false
        options[:room] = config[:room]
        options[:token] = config[:token]
        TalkerRoom.new(config[:subdomain], options)
      end
    end

    def short_message
      "Build #{short_sha} of #{project} #{worked? ? "was successful" : "failed"}"
    end

    def full_message
      <<-EOM
Commit Message: #{commit.message}
Commit Date: #{commit.committed_at}
Commit Author: #{commit.author}

#{clean_output}
EOM
    end
  end
end
