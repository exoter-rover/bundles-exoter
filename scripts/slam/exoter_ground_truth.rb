#!/usr/bin/env ruby

require 'rock/bundle'
require 'readline'

include Orocos

## Initialize orocos ##
Bundles.initialize

Orocos::Process.run 'exoter_groundtruth' do

    ## Get the task context ##
    vicon = Orocos.name_service.get 'vicon'

    # Vicon driver
    Orocos.conf.apply(vicon, ['default', 'exoter'], :override => true)
    vicon.configure

    # Log all ports
    Orocos.log_all_ports

    #Start the tasks
    vicon.start

    Readline::readline("Press ENTER to exit\n") do
    end
end
