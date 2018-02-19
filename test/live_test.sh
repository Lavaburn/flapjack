#!/bin/bash

config_file="test/flapjack_config.yaml"
environment="development"

working_dir=$1

export FLAPJACK_ENV=${environment}

cd $working_dir

# Requirements
gem install flapjack-diner -v 1.4.0
gem install redis

# Start Server
bundle exec bin/flapjack -n $environment -c ${config_file} server start
sleep 30

# Setup
ruby test/setup.rb

# Testing !!
# A - custom alert plugin - use normal simulation
#bundle exec bin/flapjack -c $config_file simulate fail_and_recover -T $environment -e testEntity -k testCheck -s CRITICAL -i 60 -t 3

# B - custom workflow - input your own data
ruby test/fail.rb

# Stop Server 
bundle exec bin/flapjack -n $environment -c ${config_file} server stop
  
# Clean up Redis
redis-cli -n 13 FLUSHALL
