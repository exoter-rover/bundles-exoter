#!/usr/bin/env ruby

require 'orocos'
require 'orocos/log'
require 'rock/bundle'
require 'vizkit'
require 'utilrb'
require 'optparse'

include Orocos

options = {}
options[:reference] = "none"
options[:imu] = "new"
options[:camera_bb2] = 'none'

op = OptionParser.new do |opt|
    opt.banner = <<-EOD
    usage: process_logs_ground_truth_pituki [options] <data_log_directory>
    EOD

    opt.on "-r", "--reference=none/vicon/gnss", String, 'set the type of reference system available' do |reference|
        options[:reference] = reference
    end

    opt.on "-i", "--imu=old/new/last", String, 'since the imu component changed. Please set the type' do |imu|
        options[:imu] = imu
    end

    opt.on "-c", "--camera_bb2=task/log", String, 'set the type of camera_bb2: task to run the task log for taking the images from an existing log' do |camera|
        options[:camera_bb2] = camera
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
    puts "[INFO] GNSS Ground Truth system available"
else
    puts "[INFO] No Ground Truth system available"
end

if options[:imu].casecmp("old").zero?
    puts "[INFO] Old type of IMU samples in logs"
else
    puts "[INFO] New type of IMU samples in logs"
end

if options[:camera_bb2].casecmp("task").zero?
    puts "[INFO] Running task camera_bb2"
elsif options[:camera_bb2].casecmp("log").zero?
    puts "[INFO] camera_bb2 taken from logs"
else
    puts "[INFO] Please specify camera_bb2! EXIT"
    exit 1
end

Bundles.run 'exoter_control',
            'localization_frontend::Task' => 'localization_frontend',
            'stereo::Task' => 'stereo',
            'camera_bb2::Task' => 'camera_bb2',
            'pituki::Task' => 'stereo_filtered',
            :gdb => false,
            :output => nil do

    # Get the task names from control
    read_joint_dispatcher = Orocos.name_service.get 'read_joint_dispatcher'
    ptu_control = Orocos.name_service.get 'ptu_control'

    # Get the task names from odometry
    localization_frontend = Orocos.name_service.get 'localization_frontend'

    # Get the task names from camera_bb2
    camera_bb2 = TaskContext.get 'camera_bb2'

    # Get the task names from stereo
    stereo = TaskContext.get 'stereo'

    # Get the task names from pituki
    stereo_filtered = TaskContext.get 'stereo_filtered'

    # Set configuration files for control
    Orocos.conf.apply(read_joint_dispatcher, ['reading'], :override => true)
    Orocos.conf.apply(ptu_control, ['default'], :override => true)

    # Set configuration files for odometry
    Orocos.conf.apply(localization_frontend, ['default', 'hamming1hzsampling12hz'], :override => true)
    localization_frontend.urdf_file = Bundles.find_file('data/odometry', 'exoter_odometry_model_complete.urdf')

    # Set configuration files for camera_bb2
    Orocos.conf.apply(camera_bb2, ['default'], :override => true)

    # Set configuration files for stereo
    Orocos.conf.apply(stereo, ['bumblebee'], :override => true)

    # Set configuration files for pituki
    Orocos.conf.apply(stereo_filtered, ['default', 'exoter_bb2', 'statistical', 'arl_map'], :override => true)

    # logs files
    log_replay = Orocos::Log::Replay.open( logfiles_path )

    #################
    ## TRANSFORMER ##
    #################
    Bundles.transformer.setup(localization_frontend)
    Bundles.transformer.setup(stereo_filtered)

    ###################
    ## LOG THE PORTS ##
    ###################
    #Bundles.log_all
    #stereo_filtered.log_all_ports

    # Configure tasks from control
    read_joint_dispatcher.configure
    ptu_control.configure

    # Configure tasks from odometry
    localization_frontend.configure

    if options[:camera_bb2].casecmp("task").zero?
        stereo.image_rectified = false
        camera_bb2.undistort = false
        camera_bb2.configure
    end
    stereo.configure
    stereo_filtered.configure


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

    if options[:imu].casecmp("last").zero?
        log_replay.imu_stim300.orientation_samples_out.connect_to(localization_frontend.orientation_samples, :type => :buffer, :size => 200)
        log_replay.imu_stim300.compensated_sensors_out.connect_to(localization_frontend.inertial_samples, :type => :buffer, :size => 200)
    end

    if options[:reference].casecmp("vicon").zero?
        log_replay.vicon.pose_samples.connect_to(localization_frontend.pose_reference_samples, :type => :buffer, :size => 200)
    end

    if options[:reference].casecmp("gnss").zero?
        log_replay.gnss_trimble.pose_samples.connect_to(localization_frontend.pose_reference_samples, :type => :buffer, :size => 200)
    end

    if options[:camera_bb2].casecmp("task").zero?
        log_replay.camera_firewire.frame.connect_to(camera_bb2.frame_in, :type => :buffer, :size => 200)

        # task
        camera_bb2.left_frame.connect_to(stereo.left_frame, :type => :buffer, :size => 200)
        camera_bb2.right_frame.connect_to(stereo.right_frame, :type => :buffer, :size => 200)
    elsif options[:camera_bb2].casecmp("log").zero?
        # logs files
        log_replay.camera_bb2.left_frame.connect_to(stereo.left_frame, :type => :buffer, :size => 200)
        log_replay.camera_bb2.right_frame.connect_to(stereo.right_frame, :type => :buffer, :size => 200)
    end

    #############################
    ## TASKS PORTS CONNECTIONS ##
    #############################

    read_joint_dispatcher.joints_samples.connect_to localization_frontend.joints_samples, :type => :buffer, :size => 200
    read_joint_dispatcher.ptu_samples.connect_to ptu_control.ptu_samples, :type => :buffer, :size => 200

    #Stereo dense output to pi
    stereo.point_cloud.connect_to stereo_filtered.point_cloud_samples, :type => :buffer, :size => 200

    # Start tasks from control
    read_joint_dispatcher.start
    ptu_control.start

    # Start tasks from slam
    localization_frontend.start

    # Start tasks for camera_bb2 and stereo
    if options[:camera_bb2].casecmp("task").zero?
        camera_bb2.start
    end
    stereo.start
    stereo_filtered.start

    # open the log replay widget
    control = Vizkit.control log_replay
    control.speed = 1

    Vizkit.exec
end
