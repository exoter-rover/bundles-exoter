#!/usr/bin/env ruby

require 'vizkit'
require 'rock/bundle'
require 'readline'

include Orocos

## Initialize orocos ##
Bundles.initialize

## Transformation for the transformer
Bundles.transformer.load_conf(Bundles.find_file('config', 'transforms_scripts.rb'))

## Execute the task 'platform_driver::Task' ##
Orocos::Process.run 'exoter_exteroceptive' do

    # setup exoter camera_firewire
        puts "[INFO] Camera ON"
        puts "Setting up camera_firewire"
        camera_firewire_mast = Orocos.name_service.get 'camera_firewire_mast'
        Orocos.conf.apply(camera_firewire_mast, ['bb3'], :override => true)
        camera_firewire_mast.configure
        camera_firewire_front = Orocos.name_service.get 'camera_firewire_front'
        Orocos.conf.apply(camera_firewire_front, ['exoter_bb2'], :override => true)
        camera_firewire_front.configure
        camera_firewire_back = Orocos.name_service.get 'camera_firewire_back'
        Orocos.conf.apply(camera_firewire_back, ['hdpr_bb2'], :override => true)
        camera_firewire_back.configure
        puts "done"

        puts "Setting up cameras"
        camera_bb2_front = Orocos.name_service.get 'camera_bb2_front'
        Orocos.conf.apply(camera_bb2_front, ['exoter_bb2'], :override => true)
        camera_bb2_front.configure
        camera_bb2_back = Orocos.name_service.get 'camera_bb2_back'
        Orocos.conf.apply(camera_bb2_back, ['hdpr_bb2'], :override => true)
        camera_bb2_back.configure
        camera_bb3 = Orocos.name_service.get 'camera_bb3'
        Orocos.conf.apply(camera_bb3, ['default'], :override => true)
        camera_bb3.configure

        bb2_trigger_front = Orocos.name_service.get 'camera_trigger_front'
        bb2_trigger_front.configure
        bb2_trigger_back = Orocos.name_service.get 'camera_trigger_back'
        bb2_trigger_back.configure
        bb3_trigger = Orocos.name_service.get 'camera_trigger_mast'
        bb3_trigger.configure
        puts "done"

        puts "Setting up stereo"
        stereo_mast = Orocos.name_service.get 'stereo_mast'
        Orocos.conf.apply(stereo_mast, ['bb3_left_right'], :override => true)
        stereo_mast.configure
        stereo_front = Orocos.name_service.get 'stereo_front'
        Orocos.conf.apply(stereo_front, ['exoter_bb2'], :override => true)
        stereo_front.configure
        stereo_back = Orocos.name_service.get 'stereo_back'
        Orocos.conf.apply(stereo_back, ['hdpr_bb2'], :override => true)
        stereo_back.configure
        puts "done"

    # Connect ports
    puts "Connecting ports"

    camera_firewire_front.frame.connect_to bb2_trigger_front.frame_in
    bb2_trigger_front.frame_out.connect_to camera_bb2_front.frame_in
    camera_bb2_front.left_frame.connect_to stereo_front.left_frame
    camera_bb2_front.right_frame.connect_to stereo_front.right_frame

    camera_firewire_back.frame.connect_to bb2_trigger_back.frame_in
    bb2_trigger_back.frame_out.connect_to camera_bb2_back.frame_in
    camera_bb2_back.left_frame.connect_to stereo_back.left_frame
    camera_bb2_back.right_frame.connect_to stereo_back.right_frame

    camera_firewire_mast.frame.connect_to bb3_trigger.frame_in
    bb3_trigger.frame_out.connect_to camera_bb3.frame_in
    camera_bb3.left_frame.connect_to stereo_mast.left_frame
    camera_bb3.right_frame.connect_to stereo_mast.right_frame

    puts "done"

    # Start the tasks
    camera_firewire_mast.start
    camera_firewire_front.start
    camera_firewire_back.start
    camera_bb3.start
    camera_bb2_front.start
    camera_bb2_back.start
    bb3_trigger.start
    bb2_trigger_front.start
    bb2_trigger_back.start
    stereo_mast.start
    stereo_front.start
    stereo_back.start

    puts "Started"

    writer_front = bb2_trigger_front.trigger.writer
    writer_back = bb2_trigger_back.trigger.writer
    writer_mast = bb3_trigger.trigger.writer
    while true
        sleep 10
        puts "Triggered"
        writer_front.write(true)
        writer_back.write(true)
        writer_mast.write(true)
    end

    Readline::readline("Press ENTER to exit\n") do
    end
end
