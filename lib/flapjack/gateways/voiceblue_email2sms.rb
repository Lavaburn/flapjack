#!/usr/bin/env ruby

require 'mail'
require 'erb'
require 'socket'
require 'chronic_duration'
require 'active_support/inflector'

require 'em-synchrony'
require 'em/protocols/smtpclient'

require 'flapjack/redis_pool'
require 'flapjack/utility'

require 'flapjack/data/entity_check'
require 'flapjack/data/alert'

module Flapjack
  module Gateways

    class VoiceblueEmail2sms

      include Flapjack::Utility

      def initialize(opts = {})
        @config = opts[:config]
        @logger = opts[:logger]
        @redis_config = opts[:redis_config] || {}
        @redis = Flapjack::RedisPool.new(:config => @redis_config, :size => 1, :logger => @logger)

        @logger.info("starting")
        @logger.debug("new voiceblue_email2sms gateway pikelet with the following options: #{@config.inspect}")
        @smtp_config = @config.delete('smtp_config')
        @sent = 0
        
        @fqdn = `/bin/hostname -f`.chomp      
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
            @logger.debug("voiceblue_email2sms gateway is going into blpop mode on #{queue}")
            alert = Flapjack::Data::Alert.next(queue, :redis => @redis, :logger => @logger)
            deliver(alert) unless alert.nil?
          rescue => e
            @logger.error "Error generating or dispatching email message for VoiceBlue Email2SMS: #{e.class}: #{e.message}\n" +
              e.backtrace.join("\n")
          end
        end
      end

      def deliver(alert)
        host = 'localhost'
        port = 25
        starttls = false
        auth = nil  
        
        domain = @fqdn
        m_from = "flapjack@#{domain}"
        m_reply_to = "flapjack@#{domain}"
      
        if @smtp_config     
          domain = @smtp_config['domain'] ? @smtp_config['domain'] : @fqdn   
            
          host = @smtp_config['host'] ? @smtp_config['host'] : 'localhost'
          port = @smtp_config['port'] ? @smtp_config['port'] : 25
          starttls = @smtp_config['starttls'] ? true : false
          m_from = @smtp_config['from'] ? @smtp_config['from'] : "flapjack@#{domain}"
          m_reply_to = @smtp_config['reply_to'] ? @smtp_config['reply_to'] : m_from
            
          if auth_config = @smtp_config['auth']
            auth = {}
            auth[:type]     = auth_config['type'].to_sym || :plain
            auth[:username] = "#{auth_config['username']}@#{domain}"
            auth[:password] = auth_config['password']
          end                  
        end
        
        m_to = "#{alert.address}@#{domain}"

        @logger.debug("flapjack_mailer: host:port = #{host.to_s}:#{port.to_s}")
        @logger.debug("flapjack_mailer: starttls  = #{starttls.to_s}")
        @logger.debug("flapjack_mailer: from = #{m_from.to_s}")
        @logger.debug("flapjack_mailer: reply_to = #{m_reply_to.to_s}")
        @logger.debug("flapjack_mailer: auth = #{auth.inspect}")
        @logger.debug("flapjack_mailer: TO = #{m_to}")
        
        mail = prepare_email(:from       => m_from,
                             :reply_to   => m_reply_to,
                             :to         => m_to,
                             :message_id => "<#{alert.notification_id}@#{@fqdn}>",
                             :alert      => alert)

        smtp_from = m_from.clone
        while smtp_from =~ /(<|>)/
          smtp_from.sub!(/^.*</, '')
          smtp_from.sub!(/>.*$/, '')
        end
        
        smtp_args = {:from     => smtp_from,
                     :to       => m_to,
                     :content  => "#{mail.to_s}\r\n.\r\n",
                     :domain   => domain,
                     :host     => host || 'localhost',
                     :port     => port || 25,
                     :starttls => starttls}
        smtp_args.merge!(:auth => auth) if auth

        email = EM::P::SmtpClient.send(smtp_args)

        response = EM::Synchrony.sync(email)

        # http://tools.ietf.org/html/rfc821#page-36 SMTP response codes
        if response && response.respond_to?(:code) &&
          ((response.code == 250) || (response.code == 251))
          alert.record_send_success!
          @sent += 1
        else
          @logger.error "Email sending failed"
        end

        @logger.debug "Email response: #{response.inspect}"

      rescue => e
        @logger.error "Error generating or delivering email to #{alert.address}: #{e.class}: #{e.message}"
        @logger.error e.backtrace.join("\n")
        raise
      end

      private

      # returns a Mail object
      def prepare_email(opts = {})
        from       = opts[:from]
        reply_to   = opts[:reply_to]
        to         = opts[:to]
        message_id = opts[:message_id]
        alert      = opts[:alert]

        message_type = alert.rollup ? 'rollup' : 'alert'

        text_template_erb, text_template =
          load_template(@config['templates'], message_type,
                        'text', File.join(File.dirname(__FILE__), 'voiceblue'))

        @alert  = alert
        bnd     = binding

        # do some intelligence gathering in case an ERB execution blows up
        begin
          erb_to_be_executed = text_template
          body_text = text_template_erb.result(bnd)
        rescue => e
          @logger.error "Error while executing ERBs for an email: " +
            "ERB being executed: #{erb_to_be_executed}"
          raise
        end

        subject = "SMS Alert from Flapjack: #{message_id}"
        sms_body = truncate(body_text, 159)      
        
        @logger.debug("preparing email to: #{to}, subject: #{subject}")
          
        mail = Mail.new do
          from       from
          to         to
          subject    subject
          reply_to   reply_to
          message_id message_id

          text_part do
            body sms_body
          end
        end

      end
    end
  end
end
