#!/usr/bin/env ruby

require 'vizkit'
require 'rock/bundle'
require 'readline'

include Orocos

options = {}
options[:camera] = "no"
options[:logging] = "nominal"
options[:reference] = "none"

OptionParser.new do |opt|
    opt.banner = <<-EOD
    usage: tmtc_handling.rb [options] 
    EOD

    opt.on '-r or --reference=none/vicon/gnss', String, 'set the type of reference system available' do |reference|
        options[:reference] = reference
    end

    opt.on '-c or --camera=no/yes', String, 'set the camera on or off' do |camera|
        options[:camera] = camera
    end

    opt.on '-l or --logging=none/minimum/nominal/all', String, 'set the type of log files you want. Nominal as default' do |logging|
        options[:logging] = logging
    end

    opt.on '--help', 'this help message' do
        puts opt
       exit 0
    end
end.parse!(ARGV)

## Initialize orocos ##
Bundles.initialize

## Transformation for the transformer
Bundles.transformer.load_conf(Bundles.find_file('config', 'transforms_scripts.rb'))

## Execute the task 'platform_driver::Task' ##
Orocos::Process.run 'exoter_control', 'exoter_proprioceptive', 'exoter_groundtruth', 'exoter_tmtchandling', 'exoter_exteroceptive' do

    # setup platform_driver
    puts "Setting up platform_driver"
    platform_driver = Orocos.name_service.get 'platform_driver'
    Orocos.conf.apply(platform_driver, ['default'], :override => true)
    platform_driver.configure
    puts "done"

    # setup read dispatcher
    puts "Setting up reading joint_dispatcher"
    read_joint_dispatcher = Orocos.name_service.get 'read_joint_dispatcher'
    Orocos.conf.apply(read_joint_dispatcher, ['reading'], :override => true)
    read_joint_dispatcher.configure
    puts "done"

    # setup the commanding dispatcher
    puts "Setting up commanding joint_dispatcher"
    command_joint_dispatcher = Orocos.name_service.get 'command_joint_dispatcher'
    Orocos.conf.apply(command_joint_dispatcher, ['commanding'], :override => true)
    command_joint_dispatcher.configure
    puts "done"
    
    # setup exoter locomotion_control
    puts "Setting up locomotion_control"
    locomotion_control = Orocos.name_service.get 'locomotion_control'
    Orocos.conf.apply(locomotion_control, ['default'], :override => true)
    locomotion_control.configure
    puts "done"

    # setup exoter ptu_control
    puts "Setting up ptu_control"
    ptu_control = Orocos.name_service.get 'ptu_control'
    Orocos.conf.apply(ptu_control, ['default'], :override => true)
    ptu_control.configure
    puts "done"
    
    # setup waypoint_navigation 
    puts "Setting up waypoint_navigation"
    waypoint_navigation = Orocos.name_service.get 'waypoint_navigation'
    Orocos.conf.apply(waypoint_navigation, ['default','exoter'], :override => true)
    waypoint_navigation.configure
    puts "done"

    # setup exoter camera_firewire
    if options[:camera].casecmp("yes").zero?
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
        puts "Setting up camera_bb2"
        camera_bb2_front = Orocos.name_service.get 'camera_bb2_front'
        Orocos.conf.apply(camera_bb2_front, ['exoter_bb2'], :override => true)
        camera_bb2_front.configure
        camera_bb2_back = Orocos.name_service.get 'camera_bb2_back'
        Orocos.conf.apply(camera_bb2_back, ['hdpr_bb2'], :override => true)
        camera_bb2_back.configure
        camera_bb3 = Orocos.name_service.get 'camera_bb3'
        Orocos.conf.apply(camera_bb3, ['default'], :override => true)
        camera_bb3.configure
        camera_trigger_front = Orocos.name_service.get 'camera_trigger_front'
        camera_trigger_front.configure
        camera_trigger_back = Orocos.name_service.get 'camera_trigger_back'
        camera_trigger_back.configure
        camera_trigger_mast = Orocos.name_service.get 'camera_trigger_mast'
        camera_trigger_mast.configure
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
        puts "Setting up dem_generation"
        dem_generation_mast = Orocos.name_service.get 'dem_generation_mast'
        Orocos.conf.apply(dem_generation_mast, ['bb3'], :override => true)
        dem_generation_mast.configure
        dem_generation_front = Orocos.name_service.get 'dem_generation_front'
        Orocos.conf.apply(dem_generation_front, ['exoter_bb2'], :override => true)
        dem_generation_front.configure
        dem_generation_back = Orocos.name_service.get 'dem_generation_back'
        Orocos.conf.apply(dem_generation_back, ['hdpr_bb2'], :override => true)
        dem_generation_back.configure
        puts "done"
#        puts "Setting up pointcloud"
#        pointcloud_pan_cam = Orocos.name_service.get 'pointcloud_pan_cam'
#        Orocos.conf.apply(pointcloud_pan_cam, ['pan_cam'], :override => true)
#        pointcloud_pan_cam.configure
#        pointcloud_loc_cam_front = Orocos.name_service.get 'pointcloud_loc_cam_front'
#        Orocos.conf.apply(pointcloud_loc_cam_front, ['loc_cam_front'], :override => true)
#        pointcloud_loc_cam_front.configure
#        pointcloud_loc_cam_rear = Orocos.name_service.get 'pointcloud_loc_cam_rear'
#        Orocos.conf.apply(pointcloud_loc_cam_rear, ['loc_cam_rear'], :override => true)
#        pointcloud_loc_cam_rear.configure
#        puts "done"
    else
        puts "[INFO] Camera OFF"
    end

    # setup ground_truth
    if options[:reference].casecmp("vicon").zero?
        puts "[INFO] Vicon Ground Truth system available"
        puts "Setting up vicon"
        vicon = Orocos.name_service.get 'vicon'
        Orocos.conf.apply(vicon, ['default', 'exoter'], :override => true)
        vicon.configure
        puts "done"
    elsif options[:reference].casecmp("gnss").zero?
        puts "[INFO] GNSS Ground Truth system available"
        puts "Setting up GNSS"
        gnss = Orocos.name_service.get 'gnss_trimble'
        Orocos.conf.apply(gnss, ['exoter','Netherlands','ESTEC'], :override => true)
        gnss.configure
        puts "done"
    else
        puts "[INFO] No Ground Truth system available"
    end

    # setup pose_merge
    puts "Setting up pose_merge"
    pose_merge = TaskContext.get 'pose_merge'
    pose_merge.configure
    puts "done"

    # setup exoter_odometry

    # Localization
#    puts "Setting up localization_frontend"
#    localization_frontend = Orocos.name_service.get 'localization_frontend'
#    Orocos.conf.apply(localization_frontend, ['default', 'hamming1hzsampling12hz'], :override => true)
#    localization_frontend.urdf_file = Bundles.find_file('data/odometry', 'exoter_odometry_model_complete.urdf')
#    Bundles.transformer.setup(localization_frontend)
#    localization_frontend.configure
#    puts "done"

    # ExoTeR Threed Odometry
#    puts "Setting up exoter threed_odometry"
#    exoter_odometry = Orocos.name_service.get 'exoter_odometry'
#    Orocos.conf.apply(exoter_odometry, ['default', 'bessel50'], :override => true)
#    exoter_odometry.urdf_file = Bundles.find_file('data/odometry', 'exoter_odometry_model_complete.urdf')
#    Bundles.transformer.setup(exoter_odometry)
#    exoter_odometry.configure
#    puts "done"

    # STIM300 IMU
    puts "Setting up imu_stim300"
    imu_stim300 = TaskContext.get 'imu_stim300'
    Orocos.conf.apply(imu_stim300,  ['default','exoter','ESTEC','stim300_5g'], :override => true)
    imu_stim300.configure
    puts "done"

    # setup telemetry_telecommand
    puts "Setting up telemetry_telecommand"
    telemetry_telecommand = Orocos.name_service.get 'telemetry_telecommand'
    Orocos.conf.apply(telemetry_telecommand, ['default'], :override => true)
    Bundles.transformer.setup(telemetry_telecommand)
    telemetry_telecommand.configure
    puts "done"

    # Connect ports
    puts "Connecting ports"

    # Connect ports: platform_driver to read_joint_dispatcher
    platform_driver.joints_readings.connect_to read_joint_dispatcher.joints_readings

    # Connect ports: read_joint_dispatcher to wheel_walking_control
    read_joint_dispatcher.motors_samples.connect_to locomotion_control.joints_readings

    # Connect ports: wheel_walking_control to command_joint_dispatcher
    locomotion_control.joints_commands.connect_to command_joint_dispatcher.joints_commands

    # Connect ports: command_joint_dispatcher to platform_driver
    command_joint_dispatcher.motors_commands.connect_to platform_driver.joints_commands

    # Connect ports: read_joint_dispatcher to ptu_control
    read_joint_dispatcher.ptu_samples.connect_to ptu_control.ptu_samples

    # Connect ports: ptu_control to command_joint_dispatcher
    ptu_control.ptu_commands_out.connect_to command_joint_dispatcher.ptu_commands

    # Connect ports: telemetry_telecommand to locomotion_control
    telemetry_telecommand.locomotion_command.connect_to locomotion_control.motion_command

    # Connect ports: telemetry_telecommand to ptu_control
    telemetry_telecommand.ptu_command.connect_to ptu_control.ptu_joints_commands

    # Connect ports: telemetry_telecommand to waypoint_navigation
    telemetry_telecommand.trajectory.connect_to waypoint_navigation.trajectory

    # Connect ports: waypoint_navigation to locomotion_control 
    waypoint_navigation.motion_command.connect_to locomotion_control.motion_command

    # Connect ports: telemetry_telecommand to waypoint_navigation
    waypoint_navigation.trajectory_status.connect_to telemetry_telecommand.trajectory_status

    if options[:reference].casecmp("vicon").zero?
        # Connect ports: vicon to telemetry_telecommand
        vicon.pose_samples.connect_to pose_merge.gps_pose
        imu_stim300.orientation_samples_out.connect_to pose_merge.imu_pose
        pose_merge.pose.connect_to telemetry_telecommand.current_pose
	# Connect ports: vicon to waypoint_navigation
	pose_merge.pose.connect_to waypoint_navigation.pose
    elsif options[:reference].casecmp("gnss").zero?
        # Connect ports: gnss to telemetry_telecommand
        gnss.pose_samples.connect_to telemetry_telecommand.current_pose
    elsif options[:reference].casecmp("none").zero?
        # Connect ports: gnss to telemetry_telecommand
        #exoter_odometry.pose_samples_out.connect_to telemetry_telecommand.current_pose
    end

    #puts "Connecting localization ports"
    #read_joint_dispatcher.joints_samples.connect_to localization_frontend.joints_samples
    ##read_joint_dispatcher.ptu_samples.connect_to localization_frontend.ptu_samples
    #imu_stim300.orientation_samples_out.connect_to localization_frontend.orientation_samples
    #imu_stim300.compensated_sensors_out.connect_to localization_frontend.inertial_samples
    #localization_frontend.joints_samples_out.connect_to exoter_odometry.joints_samples
    #localization_frontend.orientation_samples_out.connect_to exoter_odometry.orientation_samples
    #localization_frontend.weighting_samples_out.connect_to exoter_odometry.weighting_samples, :type => :buffer, :size => 200
    #puts "done"

    puts "Connecting TM/TC ports"
    # Connect ports: ptu_control to telemetry_telecommand
    ptu_control.ptu_samples_out.connect_to telemetry_telecommand.current_ptu
    #imu_stim300.orientation_samples_out.connect_to telemetry_telecommand.current_imu
    locomotion_control.bema_joints.connect_to telemetry_telecommand.current_bema
    telemetry_telecommand.bema_command.connect_to locomotion_control.bema_command
    telemetry_telecommand.walking_command_front.connect_to locomotion_control.walking_command_front
    telemetry_telecommand.walking_command_rear.connect_to locomotion_control.walking_command_rear


    if options[:camera].casecmp("yes").zero?
        # Connect ports: camera_firewire to camera_bb2
#        camera_firewire_front.frame.connect_to camera_bb2_front.frame_in
        camera_firewire_front.frame.connect_to camera_trigger_front.frame_in
        camera_trigger_front.frame_out.connect_to camera_bb2_front.frame_in
        camera_bb2_front.left_frame.connect_to stereo_front.left_frame
        camera_bb2_front.right_frame.connect_to stereo_front.right_frame
#        camera_firewire_back.frame.connect_to camera_bb2_back.frame_in
        camera_firewire_back.frame.connect_to camera_trigger_back.frame_in
        camera_trigger_back.frame_out.connect_to camera_bb2_back.frame_in
        camera_bb2_back.left_frame.connect_to stereo_back.left_frame
        camera_bb2_back.right_frame.connect_to stereo_back.right_frame
#        camera_firewire_mast.frame.connect_to camera_bb3.frame_in
        camera_firewire_mast.frame.connect_to camera_trigger_mast.frame_in
        camera_trigger_mast.frame_out.connect_to camera_bb3.frame_in
        camera_bb3.left_frame.connect_to stereo_mast.left_frame
        camera_bb3.right_frame.connect_to stereo_mast.right_frame
        stereo_mast.distance_frame.connect_to dem_generation_mast.distance_frame
        stereo_mast.left_frame_sync.connect_to dem_generation_mast.left_frame_rect
        #camera_bb3.left_frame.connect_to dem_generation_mast.left_frame_rect
        stereo_front.distance_frame.connect_to dem_generation_front.distance_frame
        stereo_front.left_frame_sync.connect_to dem_generation_front.left_frame_rect
        #camera_bb2_front.left_frame.connect_to dem_generation_front.left_frame_rect
        stereo_back.distance_frame.connect_to dem_generation_back.distance_frame
        stereo_back.left_frame_sync.connect_to dem_generation_back.left_frame_rect
        #camera_bb2_back.left_frame.connect_to dem_generation_back.left_frame_rect

        dem_generation_mast.image_left_path.connect_to telemetry_telecommand.image_mast_filename
        dem_generation_front.image_left_path.connect_to telemetry_telecommand.image_front_left_filename
        dem_generation_back.image_left_path.connect_to telemetry_telecommand.image_back_left_filename
        dem_generation_front.image_right_path.connect_to telemetry_telecommand.image_front_right_filename
        dem_generation_back.image_right_path.connect_to telemetry_telecommand.image_back_right_filename
        dem_generation_mast.mesh_path.connect_to telemetry_telecommand.dem_mast_filename
        dem_generation_front.mesh_path.connect_to telemetry_telecommand.dem_front_filename
        dem_generation_back.mesh_path.connect_to telemetry_telecommand.dem_back_filename
        dem_generation_mast.distance_frame_path.connect_to telemetry_telecommand.dist_mast_filename
        dem_generation_front.distance_frame_path.connect_to telemetry_telecommand.dist_front_filename
        dem_generation_back.distance_frame_path.connect_to telemetry_telecommand.dist_back_filename
        telemetry_telecommand.camera_mast_process_image_trigger.connect_to camera_trigger_mast.trigger
#        telemetry_telecommand.camera_front_process_image_trigger.connect_to camera_bb2_front.store_image_filename
        telemetry_telecommand.camera_front_process_image_trigger.connect_to camera_trigger_front.trigger
#        telemetry_telecommand.camera_back_process_image_trigger.connect_to camera_bb2_back.store_image_filename
        telemetry_telecommand.camera_back_process_image_trigger.connect_to camera_trigger_back.trigger

        #stereo_pan_cam.distance_frame.connect_to pointcloud_pan_cam.frame
        #stereo_pan_cam.disparity_frame.connect_to pointcloud_pan_cam.disparity_frame
        #camera_bb2_pan_cam_left.left_frame.connect_to pointcloud_pan_cam.color_frame
        #stereo_loc_cam_front.distance_frame.connect_to pointcloud_loc_cam_front.frame
        #stereo_loc_cam_front.disparity_frame.connect_to pointcloud_loc_cam_front.disparity_frame
        #camera_bb2_loc_cam_front.left_frame.connect_to pointcloud_loc_cam_front.color_frame
        #stereo_loc_cam_rear.distance_frame.connect_to pointcloud_loc_cam_rear.frame
        #stereo_loc_cam_rear.disparity_frame.connect_to pointcloud_loc_cam_rear.disparity_frame
        #camera_bb2_loc_cam_rear.left_frame.connect_to pointcloud_loc_cam_rear.color_frame
    end
    puts "done"

    # Start the tasks
    platform_driver.start
    read_joint_dispatcher.start
    command_joint_dispatcher.start
    locomotion_control.start
    ptu_control.start
    waypoint_navigation.start
    #localization_frontend.start
    #exoter_odometry.start
    imu_stim300.start
    pose_merge.start
    telemetry_telecommand.start
    if options[:camera].casecmp("yes").zero?
        camera_firewire_mast.start
        camera_firewire_front.start
        camera_firewire_back.start
        camera_bb3.start
        camera_bb2_front.start
        camera_bb2_back.start
	camera_trigger_mast.start
	camera_trigger_front.start
	camera_trigger_back.start
        stereo_mast.start
        stereo_front.start
        stereo_back.start
        dem_generation_mast.start
        dem_generation_front.start
        dem_generation_back.start
#        pointcloud_pan_cam.start
#        pointcloud_loc_cam_front.start
#        pointcloud_loc_cam_rear.start
    end
    if options[:reference].casecmp("vicon").zero?
        vicon.start
    elsif options[:reference].casecmp("gnss").zero?
        gnss.start
    end

    Readline::readline("Press ENTER to exit\n") do
    end
end
