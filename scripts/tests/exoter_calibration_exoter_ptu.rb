#!/usr/bin/env ruby

require 'rock/bundle'
require 'readline'

include Orocos

## Initialize orocos ##
Bundles.initialize

Orocos::Process.run 'vicon::Task' => 'vicon_exoter_ptu' do

    #STIM300 imu
    puts "Setting up vicon for the exoter ptu"
    vicon_exoter_ptu = Orocos.name_service.get 'vicon_exoter_ptu'
    Orocos.conf.apply(vicon_exoter_ptu,  ['default','exoter_ptu'], :override => true)
    vicon_exoter_ptu.configure
    puts "done"

    # Log all ports
    Orocos.log_all_ports

    #Start the tasks
    vicon_exoter_ptu.start

    Readline::readline("Press ENTER to exit\n") do
    end


end
