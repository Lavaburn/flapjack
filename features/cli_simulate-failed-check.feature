@process
Feature: simulate-failed-check command line
  As a systems administrator
  I should be able to use simulate-failed-check
  From the command line

  Background:
    Given a file named "simulate-failed-check.yaml" with:
"""
test:
  redis:
    db: 14
    driver: ruby
"""

# Fails on Bundler 1.12.4 (shows bundle exec help instead)
#  Scenario: Running with --help shows usage information
#    When I run `bundle exec bin/flapjack simulate --help`
#    Then the exit status should be 0
#    And  the output should contain "Simulates a check by creating a stream of events for Flapjack"
#    And  the output should contain "-k arg|--check arg"

  Scenario: Running simulate-failed-check with no arguments exits uncleanly and shows usage
    When I run `bundle exec bin/flapjack simulate`
    Then the exit status should not be 0
    And  the output should contain "Simulates a check by creating a stream of events for Flapjack"

  Scenario: Simulate a failed check
    When I run `bundle exec bin/flapjack -n test -c tmp/cucumber_cli/simulate-failed-check.yaml simulate fail -t 0 -i 0.1 -e 'test' -k 'PING'`
    Then the exit status should be 0
    And  the output should contain "sending failure event"
    And  the output should contain "stopping"

