#!/usr/bin/env ruby

require 'rock/bundle'
require 'readline'

include Orocos

## Initialize orocos ##
Bundles.initialize

Orocos::Process.run 'vicon::Task' => 'vicon' do

    # Vicon driver
    puts "Setting up vicon"
    vicon = Orocos.name_service.get 'vicon'
    Orocos.conf.apply(vicon, ['default', 'exoter'], :override => true)
    vicon.configure
    puts "done"

    # Log all ports
    Orocos.log_all_ports

    #Start the tasks
    vicon.start
    
    Readline::readline("Press ENTER to exit\n") do
    end


end
