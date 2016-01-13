@process
Feature: flapjack-feed-events command line
  As a systems administrator
  I should be able to use flapjack-feed-events
  From the command line

  Background:
    Given a file named "flapjack-feed-events.yaml" with:
"""
test:
  redis:
    db: 14
    driver: ruby
"""

  Scenario: Running with --help shows usage information
    When I run `bundle exec bin/flapjack -n test receiver json --help`
    Then the exit status should be 0
    And  the output should contain "JSON receiver"
    And  the output should contain "-f, --from=arg"

# Fails on test setup
#  Scenario: Running flapjack-feed-events with no arguments and no STDIN fails with a warning
#    When I run `bundle exec bin/flapjack -n test -c tmp/cucumber_cli/flapjack-feed-events.yaml receiver json`
#    And  the output should contain "No file provided, and STDIN is from terminal! Exiting..."
#    Then the exit status should be 1


  Scenario: Feed a single event into the events queue
    Given a file named "single-event.json" with:
"""
{
  "entity": "client1-localhost-test-1",
  "check": "foo",
  "type": "service",
  "state": "ok",
  "summary": "testing"
}
"""
    When I run `cat tmp/cucumber_cli/single-event.json | bundle exec bin/flapjack -n test -c tmp/cucumber_cli/flapjack-feed-events.yaml receiver json`
    Then the exit status should be 0
    And  the output should not contain "Invalid event data received"
    And  the output should contain "Enqueued event data, "
    And  the output should contain "client1-localhost-test-1"
    And  the output should contain "Done."

    When I run `bundle exec bin/flapjack -n test -c tmp/cucumber_cli/flapjack-feed-events.yaml receiver json -f tmp/cucumber_cli/single-event.json`
    Then the exit status should be 0
    And  the output should not contain "Invalid event data received"
    And  the output should contain "Enqueued event data, "
    And  the output should contain "client1-localhost-test-1"
    And  the output should contain "Done."


  Scenario: Feed multiple events into the events queue
    Given a file named "multiple-events.json" with:
"""
{"entity": "client1-localhost-test-1", "check": "foo",
  "type": "service", "state": "ok", "summary": "testing"}
{"entity": "client1-localhost-test-2",
  "check": "bar", "type": "service", "state": "ok", "summary":
  "testing"
  }
"""
    When I run `cat tmp/cucumber_cli/multiple-events.json | bundle exec bin/flapjack -n test -c tmp/cucumber_cli/flapjack-feed-events.yaml receiver json`
    Then the exit status should be 0
    And  the output should not contain "Invalid event data received"
    And  the output should contain "Enqueued event data, "
    And  the output should contain "client1-localhost-test-1"
    And  the output should contain "client1-localhost-test-2"
    And  the output should contain "Done."

    When I run `bundle exec bin/flapjack -n test -c tmp/cucumber_cli/flapjack-feed-events.yaml receiver json -f tmp/cucumber_cli/multiple-events.json`
    Then the exit status should be 0
    And  the output should not contain "Invalid event data received"
    And  the output should contain "Enqueued event data, "
    And  the output should contain "client1-localhost-test-1"
    And  the output should contain "client1-localhost-test-2"
    And  the output should contain "Done."

  Scenario: Feed invalid events into the events queue
    Given a file named "invalid-events.json" with:
"""
{"entity": "client1-localhost-test-1"}
{"entity": "client1-localhost-test-2", "check": "bar"}
"""
    When I run `cat tmp/cucumber_cli/invalid-events.json | bundle exec bin/flapjack -n test -c tmp/cucumber_cli/flapjack-feed-events.yaml receiver json`
    Then the exit status should be 0
    And  the output should not contain "Enqueued event data, "
    And  the output should contain "Invalid event data received"
    And  the output should contain "client1-localhost-test-1"
    And  the output should contain "client1-localhost-test-2"
    And  the output should contain "Done."

  Scenario: Feed invalid JSON into the events queue
    Given a file named "invalid-json.json" with:
"""
{"entity": "client1-localhost-test-1"
{"entity": "client1-localhost-test-2", "check": "bar"}
"""
    When I run `cat tmp/cucumber_cli/invalid-json.json | bundle exec bin/flapjack -n test -c tmp/cucumber_cli/flapjack-feed-events.yaml receiver json`
    Then the exit status should be 1
    And  the output should not contain "Enqueued event data, "
    And  the output should contain "expected comma at line 2"
