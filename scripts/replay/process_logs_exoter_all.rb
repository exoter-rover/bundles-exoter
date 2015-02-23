#!/usr/bin/env ruby

require 'orocos'
require 'orocos/log'
require 'rock/bundle'
require 'vizkit'
require 'utilrb'
require 'readline'

include Orocos

options = {}
options[:reference] = "none"
options[:imu] = "new"

op = OptionParser.new do |opt|
    opt.banner = <<-EOD
    usage: process_logs_exoter_all.rb [options] <data_log_directory>
    EOD

    opt.on "-r", "--reference=none/vicon/gnss", String, 'set the type of reference system available' do |reference|
        options[:reference] = reference
    end

    opt.on "-i", "--imu=old/new", String, 'since the imu component changed. Please set the type' do |imu|
        options[:imu] = imu
    end


    opt.on '--help', 'this help message' do
        puts opt
       exit 0
    end
end

args = op.parse(ARGV)
logfiles_path = args.shift

if !logfiles_path
    puts "missing path to log files"
    puts options
    exit 1
end

Orocos::CORBA::max_message_size = 100000000000
Bundles.initialize
Bundles.transformer.load_conf(Bundles.find_file('config', 'transforms_scripts.rb'))

# Configuration values
if options[:reference].casecmp("vicon").zero?
    puts "[INFO] Vicon Ground Truth system available"
elsif options[:reference].casecmp("gnss").zero?
    puts "[INFOR] GNSS Ground Truth system available"
else
    puts "[INFO] No Ground Truth system available"
end

if options[:imu].casecmp("old").zero?
    puts "[INFO] Old type of IMU samples in logs"
else
    puts "[INFO] New type of IMU samples in logs"
end

Bundles.run 'exoter_control',
            'exoter_perception',
            'exoter_odometry',
            'exoter_exteroceptive',
            'exoter_slam',
            :gdb => false do

    # Get the task names from control
    read_joint_dispatcher = Orocos.name_service.get 'read_joint_dispatcher'
    ptu_control = Orocos.name_service.get 'ptu_control'

    # Get the task names from perception
    colorize_pointcloud = Orocos.name_service.get 'colorize_pointcloud'
    localization_frontend = Orocos.name_service.get 'localization_frontend'

    # Get the task names from odometry
    exoter_odometry = Orocos.name_service.get 'exoter_odometry'

    # Get the task names from exteroceptive
    visual_odometry = Orocos.name_service.get 'visual_odometry'
    icp = Orocos.name_service.get 'generalized_icp'

    # Get the task names from slam
    localization_dispatcher = Orocos.name_service.get 'localization_dispatcher'
    localization_backend = Orocos.name_service.get 'localization_backend'

    # Set configuration files for control
    Orocos.conf.apply(read_joint_dispatcher, ['reading'], :override => true)
    Orocos.conf.apply(ptu_control, ['default'], :override => true)

    # Set configuration files for perception
    Orocos.conf.apply(colorize_pointcloud, ['default'], :override => true)

    # Set configuration files for slam
    Orocos.conf.apply(localization_frontend, ['default', 'hamming1hzsampling12hz'], :override => true)
    if options[:reference].casecmp("vicon").zero?
        localization_frontend.pose_reference_samples_period = 0.01 # Vicon is normally at 100Hz
    end
    if options[:reference].casecmp("gnss").zero?
        localization_frontend.pose_reference_samples_period = 0.1 # GNSS/GPS is normally at 10Hz
    end

    Orocos.conf.apply(exoter_odometry, ['default', 'bessel50'], :override => true)
    exoter_odometry.urdf_file = Bundles.find_file('data/odometry', 'exoter_odometry_model.urdf')
    Orocos.conf.apply(visual_odometry, ['default', 'bumblebee'], :override => true)
    Orocos.conf.apply(icp, ['default', 'bilateral','pass','radius'], :override => true )

    # Set configuration files for slam backend
    Orocos.conf.apply(localization_dispatcher, ['default'], :override => true)
    Orocos.conf.apply(localization_backend, ['default'], :override => true)


    # logs files
    log_replay = Orocos::Log::Replay.open( logfiles_path )
    #log_replay.use_sample_time = true
    #log_replay.transformer_broadcaster.rename("old_transformer_broadcaster")

    #################
    ## TRANSFORMER ##
    #################
    Bundles.transformer.setup(localization_frontend)
    Bundles.transformer.setup(exoter_odometry)
    Bundles.transformer.setup(colorize_pointcloud)
    Bundles.transformer.setup(visual_odometry)
    Bundles.transformer.setup(localization_backend)

    ###################
    ## LOG THE PORTS ##
    ###################
    Bundles.log_all

    # Example for other log files
    #transformer = Orocos.name_service.get "transformer_broadcaster"
    #transformer.log_all_ports
    #localization_frontend.log_all_ports(:exclude_ports => "point_cloud_samples_out")
    #camera_bb2.log_all_ports(:exclude_ports => "left_frame")

    # Configure tasks from control
    read_joint_dispatcher.configure
    ptu_control.configure

    # Configure tasks from perception
    colorize_pointcloud.configure
    localization_frontend.configure

    # Configure tasks from odometry
    exoter_odometry.configure

    # Configure tasks from exteroceptive
    visual_odometry.configure
    icp.configure

    # Configure tasks from slam
    localization_dispatcher.configure
    localization_backend.configure

    ###########################
    ## LOG PORTS CONNECTIONS ##
    ###########################
    log_replay.platform_driver.joints_readings.connect_to(read_joint_dispatcher.joints_readings, :type => :buffer, :size => 200)

    if options[:imu].casecmp("old").zero?
        log_replay.stim300.orientation_samples_out.connect_to(localization_frontend.orientation_samples, :type => :buffer, :size => 200)
        log_replay.stim300.calibrated_sensors.connect_to(localization_frontend.inertial_samples, :type => :buffer, :size => 200)
    end

    if options[:imu].casecmp("new").zero?
        log_replay.imu_stim300.orientation_samples_out.connect_to(localization_frontend.orientation_samples, :type => :buffer, :size => 200)
        log_replay.imu_stim300.calibrated_sensors.connect_to(localization_frontend.inertial_samples, :type => :buffer, :size => 200)
    end


    if options[:reference].casecmp("vicon").zero?
        log_replay.vicon.pose_samples.connect_to(localization_frontend.pose_reference_samples, :type => :buffer, :size => 200)
    end

    if options[:reference].casecmp("gnss").zero?
        log_replay.gnss_trimble.pose_samples.connect_to(localization_frontend.pose_reference_samples, :type => :buffer, :size => 200)
    end

    log_replay.camera_tof.pointcloud.connect_to(localization_frontend.point_cloud_samples, :type => :buffer, :size => 200)
    log_replay.camera_bb2.left_frame.connect_to(localization_frontend.left_frame, :type => :buffer, :size => 200)
    log_replay.camera_bb2.right_frame.connect_to(localization_frontend.right_frame, :type => :buffer, :size => 200)
    log_replay.camera_bb2.left_frame.connect_to(colorize_pointcloud.camera, :type => :buffer, :size => 200)

    #############################
    ## TASKS PORTS CONNECTIONS ##
    #############################

    # Localization Front-End
    read_joint_dispatcher.joints_samples.connect_to localization_frontend.joints_samples
    read_joint_dispatcher.ptu_samples.connect_to ptu_control.ptu_samples

    # ExoTeR Wheel Odometry
    localization_frontend.joints_samples_out.connect_to exoter_odometry.joints_samples
    localization_frontend.orientation_samples_out.connect_to exoter_odometry.orientation_samples

    # Point Clouds
    localization_frontend.point_cloud_samples_out.connect_to colorize_pointcloud.points

    # Visual odometry
    localization_frontend.left_frame_out.connect_to visual_odometry.left_frame
    localization_frontend.right_frame_out.connect_to visual_odometry.right_frame

    # Iterative Closest Points
    localization_frontend.point_cloud_samples_out.connect_to icp.point_cloud_source

    # Localization exteroceptive samples
    visual_odometry.delta_pose_samples_out.connect_to localization_dispatcher.vodo_delta_pose
    visual_odometry.point_cloud_samples_out.connect_to localization_dispatcher.vodo_points
    visual_odometry.point_cloud_uncertainty_out.connect_to localization_dispatcher.vodo_covariance
    visual_odometry.delta_pose_jacobians_k_out.connect_to localization_dispatcher.vodo_jacobian_k
    visual_odometry.delta_pose_jacobians_k_m_out.connect_to localization_dispatcher.vodo_jacobian_k_m

    # Exteroceptive samples from dispatcher to back-end
    localization_dispatcher.vodo_samples_out.connect_to localization_backend.vodo_samples

    # Localization odometry poses
    exoter_odometry.pose_samples_out.connect_to localization_backend.pose_samples

    ###########
    ## START ##
    ###########

    # Start tasks from control
    read_joint_dispatcher.start
    ptu_control.start

    # Start tasks from perception
    #colorize_pointcloud.start

    # Start tasks from slam
    localization_frontend.start
    exoter_odometry.start
    #localization_dispatcher.start
    #localization_backend.start

    #print "Waiting localization frontend is in state #{localization_frontend.state}"
    #while localization_frontend.state != :RUNNING do
    #    log_replay.step
    #end
    #puts " => #{localization_frontend.state}"

    visual_odometry.start
    #icp.start

    # open the log replay widget
    control = Vizkit.control log_replay
    control.speed = 1

    Vizkit.exec
end
