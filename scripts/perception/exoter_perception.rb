#!/usr/bin/env ruby

require 'vizkit'
require 'rock/bundle'
require 'readline'

include Orocos

## Initialize orocos ##
Bundles.initialize

Orocos::Process.run 'exoter_perception' do

    # Camera firewire
    camera_firewire = TaskContext.get 'camera_firewire'
    Orocos.conf.apply(camera_firewire, ['default'], :override => true)
    camera_firewire.configure

    # Camera bb2
    camera_bb2 = TaskContext.get 'camera_bb2'
    Orocos.conf.apply(camera_bb2, ['default'], :override => true)
    camera_bb2.configure

    # Camera tof
    camera_tof = TaskContext.get 'camera_tof'
    Orocos.conf.apply(camera_tof, ['default'], :override => true)
    camera_tof.configure

    # Log all ports
    Orocos.log_all_ports

    # Connect the ports
    camera_firewire.frame.connect_to camera_bb2.frame_in

    # Start the tasks
    camera_firewire.start
    camera_bb2.start
    camera_tof.start

    Readline::readline("Press ENTER to exit\n") do
    end
end
