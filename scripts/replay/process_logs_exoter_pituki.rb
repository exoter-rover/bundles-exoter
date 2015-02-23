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
    usage: process_logs_exoter_pituki.rb [options] <data_log_directory>
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
Bundles.transformer.load_conf(Bundles.find_file('config', 'transforms_scripts_ground_truth.rb'))

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
            'exoter_odometry',
            'exoter_perception',
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

    # Get the task names from slam pituki
    pituki = Orocos.name_service.get 'pituki'


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

    Orocos.conf.apply(pituki, ['default'], :override => true)

    # logs files
    log_replay = Orocos::Log::Replay.open( logfiles_path )

    #################
    ## TRANSFORMER ##
    #################
    Bundles.transformer.setup(localization_frontend)
    Bundles.transformer.setup(exoter_odometry)
    Bundles.transformer.setup(colorize_pointcloud)
    Bundles.transformer.setup(pituki)

    ###################
    ## LOG THE PORTS ##
    ###################
    #Bundles.log_all

    # Configure tasks from control
    read_joint_dispatcher.configure
    ptu_control.configure

    # Configure tasks from perception
    colorize_pointcloud.configure
    localization_frontend.configure

    # Configure tasks from odometry
    exoter_odometry.configure

    # Configure tasks from slam pituki
    pituki.configure

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

    # Pituki
    colorize_pointcloud.colored_points.connect_to pituki.point_cloud_samples

    ###########
    ## START ##
    ###########

    # Start tasks from control
    read_joint_dispatcher.start
    ptu_control.start

    # Start tasks from perception
    colorize_pointcloud.start
    localization_frontend.start

    # Start tasks from odometry
    exoter_odometry.start

    # Start tasks from slam pituki
    pituki.start

    # open the log replay widget
    control = Vizkit.control log_replay
    control.speed = 1

    Vizkit.exec
end

