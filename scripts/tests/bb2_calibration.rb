#!/usr/bin/env ruby

require 'vizkit'
require 'rock/bundle'
require 'readline'

include Orocos


## Initialize orocos ##
Bundles.initialize

## Execute the task 'platform_driver::Task' ##
Orocos::Process.run 'exoter_tmtchandling', 'exoter_exteroceptive' do

    
    # setup exoter camera_firewire
    puts "Setting up camera_firewire"
    camera_firewire_loc_cam_rear = Orocos.name_service.get 'camera_firewire_loc_cam_rear'
    Orocos.conf.apply(camera_firewire_loc_cam_rear, ['default','loc_cam_rear'], :override => true)
    camera_firewire_loc_cam_rear.configure
    puts "done"
    puts "Setting up camera_bb2"
    camera_bb2_loc_cam_rear = Orocos.name_service.get 'camera_bb2_loc_cam_rear'
    Orocos.conf.apply(camera_bb2_loc_cam_rear, ['loc_cam_rear'], :override => true)
    camera_bb2_loc_cam_rear.configure
    puts "done"
    stereo_loc_cam_rear = Orocos.name_service.get 'stereo_loc_cam_rear'
    Orocos.conf.apply(stereo_loc_cam_rear, ['locCam'], :override => true)
    stereo_loc_cam_rear.configure
    puts "done"
    puts "Setting up pointcloud"
    pointcloud_loc_cam_rear = Orocos.name_service.get 'pointcloud_loc_cam_rear'
    Orocos.conf.apply(pointcloud_loc_cam_rear, ['loc_cam_rear'], :override => true)
    pointcloud_loc_cam_rear.configure
    puts "done"
        
    # setup telemetry_telecommand
    puts "Setting up telemetry_telecommand"
    telemetry_telecommand = Orocos.name_service.get 'telemetry_telecommand'
    Orocos.conf.apply(telemetry_telecommand, ['default'], :override => true)
    telemetry_telecommand.configure
    puts "done"

    # Log all ports
    Orocos.log_all_ports(:exclude_ports => ['camera_firewire_loc_cam_rear.frame'])

    # Connect ports
    puts "Connecting ports"

    # Connect ports: camera_firewire to camera_bb2
    camera_firewire_loc_cam_rear.frame.connect_to camera_bb2_loc_cam_rear.frame_in
    camera_bb2_loc_cam_rear.left_frame.connect_to stereo_loc_cam_rear.left_frame
    camera_bb2_loc_cam_rear.right_frame.connect_to stereo_loc_cam_rear.right_frame
    
    telemetry_telecommand.loccam_rear_store_image_filename.connect_to camera_bb2_loc_cam_rear.store_image_filename

    stereo_loc_cam_rear.distance_frame.connect_to pointcloud_loc_cam_rear.frame
    stereo_loc_cam_rear.disparity_frame.connect_to pointcloud_loc_cam_rear.disparity_frame
    camera_bb2_loc_cam_rear.left_frame.connect_to pointcloud_loc_cam_rear.color_frame
    puts "done"

    # Start the tasks
    telemetry_telecommand.start
    camera_firewire_loc_cam_rear.start
    camera_bb2_loc_cam_rear.start
    stereo_loc_cam_rear.start
    pointcloud_loc_cam_rear.start

    Readline::readline("Press ENTER to exit\n") do
    end
end
