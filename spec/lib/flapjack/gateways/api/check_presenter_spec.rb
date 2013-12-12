require 'spec_helper'
require 'flapjack/gateways/api/check_presenter'

describe 'Flapjack::Gateways::API::CheckPresenter' do

  let(:check) { double(Flapjack::Data::Check) }

  let(:time) { Time.now.to_i }

  let(:states) {
    [double(Flapjack::Data::CheckState, :state => 'critical',
            :timestamp => time - (4 * 60 * 60), :summary => '', :details => ''),
     double(Flapjack::Data::CheckState, :state => 'ok',
            :timestamp => time - (4 * 60 * 60) + (5 * 60), :summary => '', :details => ''),
     double(Flapjack::Data::CheckState, :state => 'critical',
            :timestamp => time - (3 * 60 * 60), :summary => '', :details => ''),
     double(Flapjack::Data::CheckState, :state => 'ok',
            :timestamp => time - (3 * 60 * 60) + (10 * 60), :summary => '', :details => ''),
     double(Flapjack::Data::CheckState, :state => 'critical',
            :timestamp => time - (2 * 60 * 60), :summary => '', :details => ''),
     double(Flapjack::Data::CheckState, :state => 'ok',
            :timestamp => time - (2 * 60 * 60) + (15 * 60), :summary => '', :details => ''),
     double(Flapjack::Data::CheckState, :state => 'critical',
            :timestamp => time - (1 * 60 * 60), :summary => '', :details => ''),
     double(Flapjack::Data::CheckState, :state => 'ok',
            :timestamp => time - (1 * 60 * 60) + (20 * 60), :summary => '', :details => '')
    ]
  }

  # one overlap at start, one overlap at end, one wholly overlapping,
  # one wholly contained
  let(:unscheduled_maintenances) {
    [double(Flapjack::Data::UnscheduledMaintenance,
            :start_time => time - ((4 * 60 * 60) + (1 * 60)), # 1 minute before outage starts
            :end_time   => time - (4 * 60 * 60) + (2 * 60),   # 2 minutes after outage starts
            :duration => (3 * 60)),
     double(Flapjack::Data::UnscheduledMaintenance,
            :start_time => time - (3 * 60 * 60) + (8 * 60),   # 2 minutes before outage ends
            :end_time   => time - (3 * 60 * 60) + (11 * 60),  # 1 minute after outage ends
            :duration => (3 * 60)),
     double(Flapjack::Data::UnscheduledMaintenance,
            :start_time => time - ((2 * 60 * 60) + (1 * 60)), # 1 minute before outage starts
            :end_time   => time - (2 * 60 * 60) + (17 * 60),  # 2 minutes after outage ends
            :duration => (3 * 60)),
     double(Flapjack::Data::UnscheduledMaintenance,
            :start_time => time - (1 * 60 * 60) + (1 * 60),   # 1 minute after outage starts
            :end_time   => time - (1 * 60 * 60) + (10 * 60),  # 10 minutes before outage ends
            :duration => (9 * 60))
    ]
  }

  let(:scheduled_maintenances) {
    [double(Flapjack::Data::ScheduledMaintenance,
            :start_time => time - ((4 * 60 * 60) + (1 * 60)), # 1 minute before outage starts
            :end_time   => time - (4 * 60 * 60) + (2 * 60),   # 2 minutes after outage starts
            :duration => (3 * 60)),
     double(Flapjack::Data::ScheduledMaintenance,
            :start_time => time - (3 * 60 * 60) + (8 * 60),   # 2 minutes before outage ends
            :end_time   => time - (3 * 60 * 60) + (11 * 60),  # 1 minute after outage ends
            :duration => (3 * 60)),
     double(Flapjack::Data::ScheduledMaintenance,
            :start_time => time - ((2 * 60 * 60) + (1 * 60)), # 1 minute before outage starts
            :end_time   => time - (2 * 60 * 60) + (17 * 60),  # 2 minutes after outage ends
            :duration => (3 * 60)),
     double(Flapjack::Data::ScheduledMaintenance,
            :start_time => time - (1 * 60 * 60) + (1 * 60),   # 1 minute after outage starts
            :end_time   => time - (1 * 60 * 60) + (10 * 60),  # 10 minutes before outage ends
            :duration => (9 * 60))
    ]
  }

  it "returns a list of outage hashes for an entity check" do
    all_states = double('all_states', :all => states)
    no_states = double('no_states', :all => [])

    states_assoc = double('states_assoc')
    states_assoc.should_receive(:intersect_range).
      with(time - (5 * 60 * 60), time - (2 * 60 * 60), :by_score => true).
      and_return(all_states)
    states_assoc.should_receive(:intersect_range).
      with(nil, time - (5 * 60 * 60), :by_score => true, :limit => 2,
           :order => "desc").and_return(no_states)
    check.should_receive(:states).twice.and_return(states_assoc)

    check_presenter = Flapjack::Gateways::API::CheckPresenter.new(check)
    outages = check_presenter.outages(time - (5 * 60 * 60), time - (2 * 60 * 60))
    outages.should_not be_nil
    outages.should be_an(Array)
    outages.should have(4).time_ranges

    # TODO check the data in those hashes
  end

  it "returns a list of outage hashes with no start and end time set" do
    all_states = double('all_states', :all => states)

    states_assoc = double('states_assoc')
    states_assoc.should_receive(:intersect_range).
      with(nil, nil, :by_score => true).
      and_return(all_states)
    check.should_receive(:states).and_return(states_assoc)

    check_presenter = Flapjack::Gateways::API::CheckPresenter.new(check)
    outages = check_presenter.outages(nil, nil)
    outages.should_not be_nil
    outages.should be_an(Array)
    outages.should have(4).time_ranges

    # TODO check the data in those hashes
  end

  it "returns a consolidated list of outage hashes with repeated state events" do
    states[1] = double(Flapjack::Data::CheckState, :state => 'critical',
                       :timestamp => time - (4 * 60 * 60) + (5 * 60),
                       :summary => '', :details => '')
    states[2] = double(Flapjack::Data::CheckState, :state => 'ok',
                       :timestamp => time - (3 * 60 * 60),
                       :summary => '', :details => '')

    all_states = double('all_states', :all => states)

    states_assoc = double('states_assoc')
    states_assoc.should_receive(:intersect_range).
      with(nil, nil, :by_score => true).
      and_return(all_states)
    check.should_receive(:states).and_return(states_assoc)

    check_presenter = Flapjack::Gateways::API::CheckPresenter.new(check)
    outages = check_presenter.outages(nil, nil)
    outages.should_not be_nil
    outages.should be_an(Array)
    outages.should have(3).time_ranges
  end

  it "returns a (small) outage hash for a single state change" do
    all_states = double('all_states',
      :all => [double(Flapjack::Data::CheckState, :state => 'critical',
                      :timestamp => time - (4 * 60 * 60) ,
                      :summary => '', :details => '')])

    states_assoc = double('states_assoc')
    states_assoc.should_receive(:intersect_range).
      with(nil, nil, :by_score => true).
      and_return(all_states)
    check.should_receive(:states).and_return(states_assoc)

    ecp = Flapjack::Gateways::API::CheckPresenter.new(check)
    outages = ecp.outages(nil, nil)
    outages.should_not be_nil
    outages.should be_an(Array)
    outages.should have(1).time_range
  end

  it "a list of unscheduled maintenances for an entity check" do
    all_unsched = double('all_unsched', :all => unscheduled_maintenances)
    no_unsched = double('no_unsched', :all => [])

    unsched_assoc = double('unsched_assoc')
    unsched_assoc.should_receive(:intersect_range).
      with(time - (12 * 60 * 60), time, :by_score => true).
      and_return(all_unsched)
    unsched_assoc.should_receive(:intersect_range).
      with(nil, time - (12 * 60 * 60), :by_score => true).and_return(no_unsched)
    check.should_receive(:unscheduled_maintenances_by_start).twice.and_return(unsched_assoc)

    check_presenter = Flapjack::Gateways::API::CheckPresenter.new(check)
    unsched_maint = check_presenter.unscheduled_maintenances(time - (12 * 60 * 60), time)

    unsched_maint.should be_an(Array)
    unsched_maint.should have(4).time_ranges

    # TODO check the data in those hashes
  end

  it "a list of scheduled maintenances for an entity check" do
    all_sched = double('all_sched', :all => scheduled_maintenances)
    no_sched = double('no_sched', :all => [])

    sched_assoc = double('sched_assoc')
    sched_assoc.should_receive(:intersect_range).
      with(time - (12 * 60 * 60), time, :by_score => true).
      and_return(all_sched)
    sched_assoc.should_receive(:intersect_range).
      with(nil, time - (12 * 60 * 60), :by_score => true).and_return(no_sched)
    check.should_receive(:scheduled_maintenances_by_start).twice.and_return(sched_assoc)

    check_presenter = Flapjack::Gateways::API::CheckPresenter.new(check)
    unsched_maint = check_presenter.scheduled_maintenances(time - (12 * 60 * 60), time)

    unsched_maint.should be_an(Array)
    unsched_maint.should have(4).time_ranges

    # TODO check the data in those hashes
  end

  it "returns downtime and percentage for a downtime check" do
    all_states = double('all_states', :all => states)
    no_states = double('no_states', :all => [])

    states_assoc = double('states_assoc')
    states_assoc.should_receive(:intersect_range).
      with(time - (12 * 60 * 60), time, :by_score => true).
      and_return(all_states)
    states_assoc.should_receive(:intersect_range).
      with(nil, time - (12 * 60 * 60), :by_score => true, :limit => 2,
           :order => "desc").and_return(no_states)
    check.should_receive(:states).twice.and_return(states_assoc)

    all_sched = double('all_sched', :all => scheduled_maintenances)
    no_sched = double('no_sched', :all => [])

    sched_assoc = double('sched_assoc')
    sched_assoc.should_receive(:intersect_range).
      with(time - (12 * 60 * 60), time, :by_score => true).
      and_return(all_sched)
    sched_assoc.should_receive(:intersect_range).
      with(nil, time - (12 * 60 * 60), :by_score => true).and_return(no_sched)
    check.should_receive(:scheduled_maintenances_by_start).twice.and_return(sched_assoc)

    check_presenter = Flapjack::Gateways::API::CheckPresenter.new(check)
    downtimes = check_presenter.downtime(time - (12 * 60 * 60), time)

    # 22 minutes, 3 + 8 + 11
    downtimes.should be_a(Hash)
    downtimes[:total_seconds].should == {'critical' => (22 * 60),
      'ok' => ((12 * 60 * 60) - (22 * 60))}
    downtimes[:percentages].should == {'critical' => (((22 * 60) * 100.0) / (12 * 60 * 60)),
      'ok' => ((((12 * 60 * 60) - (22 * 60)) * 100.0) / (12 * 60 *60))}
    downtimes[:downtime].should be_an(Array)
    # the last outage gets split by the intervening maintenance period,
    # but the fully covered one gets removed.
    downtimes[:downtime].should have(4).time_ranges
  end

  it "returns downtime (but no percentage) for an unbounded downtime check" do
    all_states = double('all_states', :all => states)

    states_assoc = double('states_assoc')
    states_assoc.should_receive(:intersect_range).
      with(nil, nil, :by_score => true).
      and_return(all_states)
    check.should_receive(:states).and_return(states_assoc)

    all_sched = double('all_sched', :all => scheduled_maintenances)

    sched_assoc = double('sched_assoc')
    sched_assoc.should_receive(:intersect_range).
      with(nil, nil, :by_score => true).
      and_return(all_sched)
    check.should_receive(:scheduled_maintenances_by_start).and_return(sched_assoc)

    check_presenter = Flapjack::Gateways::API::CheckPresenter.new(check)
    downtimes = check_presenter.downtime(nil, nil)

    # 22 minutes, 3 + 8 + 11
    downtimes.should be_a(Hash)
    downtimes[:total_seconds].should == {'critical' => (22 * 60)}
    downtimes[:percentages].should == {'critical' => nil}
    downtimes[:downtime].should be_an(Array)
    # the last outage gets split by the intervening maintenance period,
    # but the fully covered one gets removed.
    downtimes[:downtime].should have(4).time_ranges
  end

  it "returns downtime and handles an unfinished problem state" do
    current = [double(Flapjack::Data::CheckState, :state => 'critical',
                      :timestamp => time - (4 * 60 * 60),
                      :summary => '', :details => ''),
               double(Flapjack::Data::CheckState, :state => 'ok',
                      :timestamp => time - (4 * 60 * 60) + (5 * 60),
                      :summary => '', :details => ''),
               double(Flapjack::Data::CheckState, :state => 'critical',
                      :timestamp => time - (3 * 60 * 60),
                      :summary => '', :details => '')]

    all_states = double('all_states', :all => current)

    states_assoc = double('states_assoc')
    states_assoc.should_receive(:intersect_range).
      with(nil, nil, :by_score => true).
      and_return(all_states)
    check.should_receive(:states).and_return(states_assoc)

    all_sched = double('all_sched', :all => scheduled_maintenances)

    sched_assoc = double('sched_assoc')
    sched_assoc.should_receive(:intersect_range).
      with(nil, nil, :by_score => true).
      and_return(all_sched)
    check.should_receive(:scheduled_maintenances_by_start).and_return(sched_assoc)

    check_presenter = Flapjack::Gateways::API::CheckPresenter.new(check)
    downtimes = check_presenter.downtime(nil, nil)

    downtimes.should be_a(Hash)
    downtimes[:total_seconds].should == {'critical' => 180}
    downtimes[:percentages].should == {'critical' => nil}
    downtimes[:downtime].should be_an(Array)
    # the last outage gets split by the intervening maintenance period,
    # but the fully covered one gets removed.
    downtimes[:downtime].should have(2).time_ranges
  end

end