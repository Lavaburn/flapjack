#!/usr/bin/env ruby

require 'erb'
require 'socket'
require 'chronic_duration'
require 'active_support/inflector'

require 'json'

require 'em-synchrony'
require 'em-synchrony/em-http'

require 'flapjack/redis_pool'
require 'flapjack/utility'

require 'flapjack/data/entity_check'
require 'flapjack/data/alert'

module Flapjack
  module Gateways

    class Hipchat

      include Flapjack::Utility

      def initialize(opts = {})
        @config = opts[:config]
        @logger = opts[:logger]
        @redis_config = opts[:redis_config] || {}
        @redis = Flapjack::RedisPool.new(:config => @redis_config, :size => 1, :logger => @logger)

        @logger.info("starting")
        @logger.debug("new hipchat gateway pikelet with the following options: #{@config.inspect}")
        
        @sent = 0  
      end

      def stop
        @logger.info("stopping")
        @should_quit = true

        redis_uri = @redis_config[:path] ||
          "redis://#{@redis_config[:host] || '127.0.0.1'}:#{@redis_config[:port] || '6379'}/#{@redis_config[:db] || '0'}"
        shutdown_redis = EM::Hiredis.connect(redis_uri)
        shutdown_redis.rpush(@config['queue'], Flapjack.dump_json('notification_type' => 'shutdown'))
      end

      def start
        queue = @config['queue']

        until @should_quit
          begin
            @logger.debug("hipchat gateway is going into blpop mode on #{queue}")
            alert = Flapjack::Data::Alert.next(queue, :redis => @redis, :logger => @logger)
            deliver(alert) unless alert.nil?
          rescue => e
            @logger.error "Error generating or dispatching notification for Hipchat: #{e.class}: #{e.message}\n" +
              e.backtrace.join("\n")
          end
        end
      end

      def deliver(alert)
        # Settings
        api_url    = @config['api_url'] || 'https://api.hipchat.com'
        auth_token = @config['auth_token']

        alert_type = alert.rollup ? 'rollup' : 'alert'
        format     = @config['format'] || 'text'

        # Validation
        errors = []

        [
         [auth_token, "Hipchat API Authentication Token is missing"]
        ].each do |val_err|
          next unless val_err.first.nil? || (val_err.first.respond_to?(:empty?) && val_err.first.empty?)
          errors << val_err.last
        end

        unless errors.empty?
          errors.each {|err| @logger.error err }
          return
        end

        # Template Binding
        hipchat_template_erb, hipchat_template =
          load_template(@config['templates'], alert_type, format,
                        File.join(File.dirname(__FILE__), 'hipchat'))

        # Config should be used onlly  by RSPEC
        @alert_id = @config['card_id'] || SecureRandom.uuid

        if (alert_type == 'alert')
          if (alert.state == 'ok')
            @color = "green"
          elsif (alert.state == 'warning')
            @color = "yellow"
          elsif (alert.state == 'critical')
            @color = "red"
          elsif (alert.state == 'unknown')
            @color = "gray"
          else
            @color = "purple"
          end
        else
          if (alert.rollup == 'recovery')
            @color = "green"
          elsif (alert.state == 'warning')

          
          end
        end

        @alert = alert
        bnd = binding

        begin
          message = hipchat_template_erb.result(bnd).chomp
        rescue => e
          @logger.error "Error while executing the ERB for Hipchat Room notification: " +
            "ERB being executed: #{hipchat_template}"
          raise
        end
        @logger.debug "message: #{message.inspect}"

        # Create Payload
        content_type = (format == 'text') ? 'text/plain' : 'application/json'

        http = EM::HttpRequest.new("#{api_url}/v2/room/#{alert.address}/notification").post(
          :head  => {
            'Accept'       => content_type,
            'Content-Type' => content_type
          },
          :body  => message,
          :query => {
            :auth_token => auth_token
          }
        )

        @logger.debug "server response: #{http.response}"

        status = (http.nil? || http.response_header.nil?) ? nil : http.response_header.status
        if (status >= 200) && (status <= 206)
          @sent += 1
          alert.record_send_success!
          @logger.debug "Sent message via Hipchat, response status is #{status}"
        else
          @logger.error "Failed to send message via Hipchat, response status is #{status}"
        end
      rescue => e
        @logger.error "Error generating or delivering Hipchat Notification to #{alert.address}: #{e.class}: #{e.message}"
        @logger.error e.backtrace.join("\n")
        raise
      end

#      private
#
#      def prepare_X(opts = {})
#
#      end
    end
  end
end
