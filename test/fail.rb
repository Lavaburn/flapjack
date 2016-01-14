#!/usr/bin/env ruby

require 'redis'
require 'json'

flapjack_event = {
  "entity"  => 'testEntity',
  "check"   => 'testCheck',
  "type"    => 'service',
  "state"   => 'CRITICAL',
  "details" => 'Simulation - development testing - Details',
  "time"    => Time.new.to_i,
  "tags"    => ['simulation'],
  "extra_data" => {
    "graph1" => '<URL HERE>',
    "graph2" => '<Another URL here?>'
  }
}

redis = Redis.new(:host => "localhost", :port => 6379, :db => 13)

# Push every minute for 3 minutes
2.times do |i|
  flapjack_event['summary'] = "Development testing - Pass #{i}"
  redis.lpush('events', JSON.dump(flapjack_event))
  sleep(60)
end

flapjack_event['summary'] = "Development testing -  Done"
flapjack_event['state'] = 'OK'
flapjack_event['time'] = Time.new.to_i
redis.lpush('events', JSON.dump(flapjack_event))