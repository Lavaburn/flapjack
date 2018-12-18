#!/usr/bin/env ruby

require 'flapjack-diner'

Flapjack::Diner.base_uri('127.0.0.1:3081')

# 1. Create ALL entity
entity_all_data = {
  :id   => 'ALL',
  :name => 'ALL'
}
Flapjack::Diner.create_entities([entity_all_data])

# 2. Create Contact
contact_nicolas_data = {
  :id         => 'nicolas',
  :first_name => 'Nicolas',
  :last_name  => 'Truyens',
  :email      => 'nicolas@rcswimax.com'
}
Flapjack::Diner.create_contacts([contact_nicolas_data])

# 3. Attach Contact to Entity
Flapjack::Diner.update_entities(entity_all_data[:id], :add_contact => contact_nicolas_data[:id])

# 4. Create Media 
#medium_hipchat = {
#  :type             => 'jabber',
#  :address          => '188712_juba_server_infra@conf.hipchat.com',
#  :interval         => 1,
#  :rollup_threshold => 0
#}
#Flapjack::Diner.create_contact_media(contact_nicolas_data[:id], [medium_hipchat])

#medium_vb = {
#  :type             => 'voiceblue_email2sms',
#  :address          => '0955874880',
#  :interval         => 1,
#  :rollup_threshold => 0
#}
#Flapjack::Diner.create_contact_media(contact_nicolas_data[:id], [medium_vb])

medium_slack_wh = {
  :type             => 'slack',
  :address          => 'https://hooks.slack.com/services/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',
  :interval         => 1,
  :rollup_threshold => 0
}
Flapjack::Diner.create_contact_media(contact_nicolas_data[:id], [medium_slack_wh])
