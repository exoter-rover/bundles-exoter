#!/usr/bin/env ruby

require 'rock/bundle'
require 'readline'

include Orocos

## Initialize orocos ##
Bundles.initialize

Orocos::Process.run 'exoter_proprioceptive' do

    #STIM300 imu
    imu_stim300 = TaskContext.get 'imu_stim300'
    Orocos.conf.apply(imu_stim300,  ['default','ExoTer','ESTEC','stim300_5g'], :override => true)
    imu_stim300.configure

    # Log all ports
    Orocos.log_all_ports

    # Start the tasks
    imu_stim300.start

    Readline::readline ("Press ENTER to exit\n") do
    end
end
