#!/usr/bin/env ruby

require 'vizkit'
require 'rock/bundle'
require 'readline'

include Orocos

## Initialize orocos ##
Bundles.initialize

Orocos::Process.run 'exoter_exteroceptive' do

    # Camera firewire
    camera_firewire = TaskContext.get 'camera_firewire_front'
    Orocos.conf.apply(camera_firewire, ['exoter_bb2'], :override => true)
    camera_firewire.configure

    # Camera trigger
    camera_trigger = Orocos.name_service.get 'camera_trigger_front'
    camera_trigger.configure

    # Camera bb2
    camera_bb2 = TaskContext.get 'camera_bb2_front'
    Orocos.conf.apply(camera_bb2, ['exoter_bb2'], :override => true)
    camera_bb2.configure

    # Stereo
    stereo = TaskContext.get 'stereo_front'
    Orocos.conf.apply(stereo, ['exoter_bb2'], :override => true)
    stereo.configure

    # Dem generation
    dem_generation = Orocos.name_service.get 'dem_generation_front'
    Orocos.conf.apply(dem_generation, ['exoter_bb2'], :override => true)
    dem_generation.configure

    # Camera tof
    #camera_tof = TaskContext.get 'camera_tof'
    #Orocos.conf.apply(camera_tof, ['default'], :override => true)
    #camera_tof.configure

    # Log all ports
    Orocos.log_all_ports

    # Connect the ports
    camera_firewire.frame.connect_to camera_trigger.frame_in
    camera_trigger.frame_out.connect_to camera_bb2.frame_in
    camera_bb2.left_frame.connect_to stereo.left_frame
    camera_bb2.right_frame.connect_to stereo.right_frame
    stereo.distance_frame.connect_to dem_generation.distance_frame
    stereo.left_frame_sync.connect_to dem_generation.left_frame_rect


    # Start the tasks
    camera_firewire.start
    camera_trigger.start
    camera_bb2.start
    stereo.start
    dem_generation.start
    #camera_tof.start
    
    trigger = camera_trigger.trigger.writer
    i=1
    while i<2
        sleep(2)
        trigger.write(true)
        puts "loop"
        i=i+1
        sleep(5)
    end

    Readline::readline("Press ENTER to exit\n") do
    end
end
