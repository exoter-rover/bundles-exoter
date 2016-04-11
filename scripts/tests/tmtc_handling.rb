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
Orocos::Process.run 'exoter_control', 'exoter_proprioceptive', 'exoter_groundtruth', 'exoter_tmtchandling', 'exoter_exteroceptive' , 'exoter_localization' do

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

    # setup exoter camera_firewire
    if options[:camera].casecmp("yes").zero?
        puts "[INFO] Camera ON"
        puts "Setting up camera_firewire"
        camera_firewire_pan_cam_left = Orocos.name_service.get 'camera_firewire_pan_cam_left'
        Orocos.conf.apply(camera_firewire_pan_cam_left, ['default','pan_cam_left'], :override => true)
        camera_firewire_pan_cam_left.configure
        camera_firewire_pan_cam_right = Orocos.name_service.get 'camera_firewire_pan_cam_right'
        Orocos.conf.apply(camera_firewire_pan_cam_right, ['default','pan_cam_right'], :override => true)
        camera_firewire_pan_cam_right.configure
        camera_firewire_loc_cam_front = Orocos.name_service.get 'camera_firewire_loc_cam_front'
        Orocos.conf.apply(camera_firewire_loc_cam_front, ['default','loc_cam_front'], :override => true)
        camera_firewire_loc_cam_front.configure
        camera_firewire_loc_cam_rear = Orocos.name_service.get 'camera_firewire_loc_cam_rear'
        Orocos.conf.apply(camera_firewire_loc_cam_rear, ['default','loc_cam_rear'], :override => true)
        camera_firewire_loc_cam_rear.configure
        puts "done"
        puts "Setting up camera_bb2"
        camera_bb2_loc_cam_front = Orocos.name_service.get 'camera_bb2_loc_cam_front'
        Orocos.conf.apply(camera_bb2_loc_cam_front, ['loc_cam_front'], :override => true)
        camera_bb2_loc_cam_front.configure
        camera_bb2_loc_cam_rear = Orocos.name_service.get 'camera_bb2_loc_cam_rear'
        Orocos.conf.apply(camera_bb2_loc_cam_rear, ['loc_cam_rear'], :override => true)
        camera_bb2_loc_cam_rear.configure
        puts "done"
        puts "Setting up stereo"
        stereo_pan_cam = Orocos.name_service.get 'stereo_pan_cam'
        Orocos.conf.apply(stereo_pan_cam, ['panCam'], :override => true)
        stereo_pan_cam.configure
        stereo_loc_cam_front = Orocos.name_service.get 'stereo_loc_cam_front'
        Orocos.conf.apply(stereo_loc_cam_front, ['default'], :override => true)
        stereo_loc_cam_front.configure
        stereo_loc_cam_rear = Orocos.name_service.get 'stereo_loc_cam_rear'
        Orocos.conf.apply(stereo_loc_cam_rear, ['locCam'], :override => true)
        stereo_loc_cam_rear.configure
        puts "done"
        puts "Setting up pointcloud"
        pointcloud_pan_cam = Orocos.name_service.get 'pointcloud_pan_cam'
        Orocos.conf.apply(pointcloud_pan_cam, ['default'], :override => true)
        pointcloud_pan_cam.configure
        pointcloud_loc_cam_front = Orocos.name_service.get 'pointcloud_loc_cam_front'
        Orocos.conf.apply(pointcloud_loc_cam_front, ['default'], :override => true)
        pointcloud_loc_cam_front.configure
        pointcloud_loc_cam_rear = Orocos.name_service.get 'pointcloud_loc_cam_rear'
        Orocos.conf.apply(pointcloud_loc_cam_rear, ['default'], :override => true)
        pointcloud_loc_cam_rear.configure
        puts "done"
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

    # setup exoter_odometry

    # Localization
    puts "Setting up localization_frontend"
    localization_frontend = Orocos.name_service.get 'localization_frontend'
    Orocos.conf.apply(localization_frontend, ['default', 'hamming1hzsampling12hz'], :override => true)
    localization_frontend.urdf_file = Bundles.find_file('data/odometry', 'exoter_odometry_model_complete.urdf')
    Bundles.transformer.setup(localization_frontend)
    localization_frontend.configure
    puts "done"

    # ExoTeR Threed Odometry
    puts "Setting up exoter threed_odometry"
    exoter_odometry = Orocos.name_service.get 'exoter_odometry'
    Orocos.conf.apply(exoter_odometry, ['default', 'bessel50'], :override => true)
    exoter_odometry.urdf_file = Bundles.find_file('data/odometry', 'exoter_odometry_model_complete.urdf')
    Bundles.transformer.setup(exoter_odometry)
    exoter_odometry.configure
    puts "done"

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
    telemetry_telecommand.configure
    puts "done"

    # Log all ports
    Orocos.log_all_ports(:exclude_ports => ['camera_firewire_pan_cam.frame','camera_firewire_loc_cam.frame'])

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

    if options[:reference].casecmp("vicon").zero?
        # Connect ports: vicon to telemetry_telecommand
        vicon.pose_samples.connect_to telemetry_telecommand.current_pose
    elsif options[:reference].casecmp("gnss").zero?
        # Connect ports: gnss to telemetry_telecommand
        gnss.pose_samples.connect_to telemetry_telecommand.current_pose
    elsif options[:reference].casecmp("none").zero?
        # Connect ports: gnss to telemetry_telecommand
        exoter_odometry.pose_samples_out.connect_to telemetry_telecommand.current_pose
    end

    puts "Connecting localization ports"
    read_joint_dispatcher.joints_samples.connect_to localization_frontend.joints_samples
    #read_joint_dispatcher.ptu_samples.connect_to localization_frontend.ptu_samples
    imu_stim300.orientation_samples_out.connect_to localization_frontend.orientation_samples
    imu_stim300.compensated_sensors_out.connect_to localization_frontend.inertial_samples
    localization_frontend.joints_samples_out.connect_to exoter_odometry.joints_samples
    localization_frontend.orientation_samples_out.connect_to exoter_odometry.orientation_samples
    localization_frontend.weighting_samples_out.connect_to exoter_odometry.weighting_samples, :type => :buffer, :size => 200
    puts "done"

    puts "Connecting TM/TC ports"
    # Connect ports: ptu_control to telemetry_telecommand
    ptu_control.ptu_samples_out.connect_to telemetry_telecommand.current_ptu
    imu_stim300.orientation_samples_out.connect_to telemetry_telecommand.current_imu
    locomotion_control.bema_joints.connect_to telemetry_telecommand.current_bema
    telemetry_telecommand.bema_command.connect_to locomotion_control.bema_command
    telemetry_telecommand.walking_command.connect_to locomotion_control.walking_command


    if options[:camera].casecmp("yes").zero?
        # Connect ports: camera_firewire to camera_bb2
        camera_firewire_loc_cam_front.frame.connect_to camera_bb2_loc_cam_front.frame_in
        camera_firewire_loc_cam_rear.frame.connect_to camera_bb2_loc_cam_rear.frame_in
        camera_bb2_loc_cam_front.left_frame.connect_to stereo_loc_cam_front.left_frame
        camera_bb2_loc_cam_front.right_frame.connect_to stereo_loc_cam_front.right_frame
        camera_bb2_loc_cam_rear.left_frame.connect_to stereo_loc_cam_rear.left_frame
        camera_bb2_loc_cam_rear.right_frame.connect_to stereo_loc_cam_rear.right_frame
        camera_firewire_pan_cam_left.frame.connect_to stereo_pan_cam.left_frame
        camera_firewire_pan_cam_right.frame.connect_to stereo_pan_cam.right_frame
        
        telemetry_telecommand.pancam_store_image_filename.connect_to camera_bb2_loc_cam_front.store_image_filename
        telemetry_telecommand.loccam_store_image_filename.connect_to camera_bb2_loc_cam_rear.store_image_filename

        stereo_pan_cam.distance_frame.connect_to pointcloud_pan_cam.frame
        stereo_pan_cam.disparity_frame.connect_to pointcloud_pan_cam.disparity_frame
        camera_firewire_pan_cam_left.frame.connect_to pointcloud_pan_cam.color_frame
        stereo_loc_cam_front.distance_frame.connect_to pointcloud_loc_cam_front.frame
        stereo_loc_cam_front.disparity_frame.connect_to pointcloud_loc_cam_front.disparity_frame
        camera_bb2_loc_cam_front.left_frame.connect_to pointcloud_loc_cam_front.color_frame
        stereo_loc_cam_rear.distance_frame.connect_to pointcloud_loc_cam_rear.frame
        stereo_loc_cam_rear.disparity_frame.connect_to pointcloud_loc_cam_rear.disparity_frame
        camera_bb2_loc_cam_rear.left_frame.connect_to pointcloud_loc_cam_rear.color_frame
    end
    puts "done"

    # Start the tasks
    platform_driver.start
    read_joint_dispatcher.start
    command_joint_dispatcher.start
    locomotion_control.start
    ptu_control.start
    localization_frontend.start
    exoter_odometry.start
    imu_stim300.start
    telemetry_telecommand.start
    if options[:camera].casecmp("yes").zero?
        camera_firewire_pan_cam_left.start
        camera_firewire_pan_cam_right.start
        camera_firewire_loc_cam_front.start
        camera_firewire_loc_cam_rear.start
        camera_bb2_loc_cam_front.start
        camera_bb2_loc_cam_rear.start
        stereo_pan_cam.start
        stereo_loc_cam_front.start
        stereo_loc_cam_rear.start
        pointcloud_pan_cam.start
        pointcloud_loc_cam_front.start
        pointcloud_loc_cam_rear.start
    end
    if options[:reference].casecmp("vicon").zero?
        vicon.start
    elsif options[:reference].casecmp("gnss").zero?
        gnss.start
    end

    Readline::readline("Press ENTER to exit\n") do
    end
end
