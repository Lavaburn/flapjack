require 'spec_helper'
require 'flapjack/gateways/hipchat'

describe Flapjack::Gateways::Hipchat, :logger => true do

  let(:lock) { double(Monitor) }

  let(:redis) { double('redis') }

  let(:hipchat_v2_endpoint) { "https://api.hipchat.com/v2/room/room1/notification" }

  let(:config) { {
    'auth_token' => 'TOKEN123',
    'format'     => 'card',
    'card_id'    => 'RSPEC'
  } }

  let(:time) { Time.new(2018, 02, 18, 13, 37) }

  let(:time_str) { Time.at(time).strftime('%-d %b %H:%M') }

  let(:incident) { {'notification_type'  => 'recovery',
                 'contact_first_name' => 'John',
                 'contact_last_name'  => 'Smith',
                 'state'              => 'ok',
                 'summary'            => 'smile',
                 'last_state'         => 'problem',
                 'last_summary'       => 'frown',
                 'time'               => time.to_i,
                 'address'            => 'room1',
                 'event_id'           => 'example.com:ping',
                 'id'                 => '123456789',
                 'duration'           => 55,
                 'state_duration'     => 23
                }
              }

  let(:notification) { {   
    "notify"     => true,
    "color"      => "green",
    "message"    => "OK: ping",
    "card"       => {
      "id"          => "RSPEC",
      "style"       => "application",
      "format"      => "medium",
      "title"       => "smile",
      "description" => {
        "format" => "html",
        "value"  => ""
      },
      "activity" => {
        "html" => "OK: ping",
        "icon" => {
          "url" => "https://static.rcswimax.com/images/logo.gif"
        }
      },
      "attributes" => [
        {
          "label" => "Entity",
          "value" => {
            "label" => "example.com"
          }
        }
      ]
    }
  } }
              
  it "sends a room notification" do
    payload = ''

    req = stub_request(:post, "#{hipchat_v2_endpoint}?auth_token=TOKEN123").
      with(:body => notification, :headers => {'Accept'=>'application/json', 'Content-Type'=>'application/json'}).
      to_return(:status => 200)

    EM.synchrony do
      expect(Flapjack::RedisPool).to receive(:new).and_return(redis)

      alert = Flapjack::Data::Alert.new(incident, :logger => @logger)
      hipchat = Flapjack::Gateways::Hipchat.new(:config => config, :logger => @logger)
      hipchat.deliver(alert)
      EM.stop
    end
    expect(req).to have_been_requested
  end

  it "does not send a room notification with an invalid config" do
    EM.synchrony do
      expect(Flapjack::RedisPool).to receive(:new).and_return(redis)

      alert = Flapjack::Data::Alert.new(incident, :logger => @logger)
      hipchat = Flapjack::Gateways::Hipchat.new(:config => config.reject {|k, v| k == 'auth_token'}, :logger => @logger)
      hipchat.deliver(alert)
      EM.stop
    end

    expect(WebMock).not_to have_requested(:post, hipchat_v2_endpoint)
  end

  # TODO: test text formatting and rollups !!!
end
