require 'spec_helper'
require 'flapjack/gateways/slack'

describe Flapjack::Gateways::Slack, :logger => true do

  let(:lock) { double(Monitor) }

  let(:redis) { double('redis') }

  let(:config) { {
    'format' => 'attachment'
  } }

  let(:time) { Time.new(2013, 10, 31, 13, 45) }

  let(:time_str) { Time.at(time).strftime('%-d %b %H:%M') }

  let(:incident) { {
    'notification_type'  => 'recovery',  
    'contact_first_name' => 'John',
    'contact_last_name'  => 'Smith',
    'state'              => 'ok',
    'summary'            => 'smile',
    'last_state'         => 'problem',
    'last_summary'       => 'frown',
    'time'               => time.to_i,
    'address'            => 'https://hooks.slack.com/services/AAAAA/BBBBB/CCCCCCCCCCCCC',
    'event_id'           => 'example.com:ping',
    'id'                 => '123456789',
    'duration'           => 55,
    'state_duration'     => 23
  } }

  let(:notification) { {   
    "text"        => "OK: ping",
    "attachments" => [{
      "title"     => "smile",
      "color"     => "good",
      "text"      => "", # alert.details
      "fields"    => [
        {
          "title" => "Entity",
          "value" => "example.com",
          "short" => true
        }
      ]
    }]
  } }

  it "sends a Slack message" do
    payload = ''
    
    req = stub_request(:post, incident['address']).
      with(:body => notification, :headers => {'Content-Type'=>'application/json'}).
      to_return(:status => 200)

    EM.synchrony do
      expect(Flapjack::RedisPool).to receive(:new).and_return(redis)

      alert = Flapjack::Data::Alert.new(incident, :logger => @logger)
      slack = Flapjack::Gateways::Slack.new(:config => config, :logger => @logger)
      slack.deliver(alert)
      EM.stop
    end

    expect(req).to have_been_requested
  end

  it "does not send a Slack message with an invalid config" do
    EM.synchrony do
      expect(Flapjack::RedisPool).to receive(:new).and_return(redis)

      alert = Flapjack::Data::Alert.new(incident.reject {|k, v| k == 'address'}, :logger => @logger)
      slack = Flapjack::Gateways::Slack.new(:config => config, :logger => @logger)
      slack.deliver(alert)
      EM.stop
    end

    expect(WebMock).not_to have_requested(:post, incident['address'])
  end
  
  # TODO: test text formatting and rollups !!!
end
