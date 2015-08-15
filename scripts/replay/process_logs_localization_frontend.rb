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
options[:tof] = "none"
options[:camera] = "none"

op = OptionParser.new do |opt|
    opt.banner = <<-EOD
    usage: process_logs_localization_frontend.rb [options] <data_log_directory>
    EOD

    opt.on "-r", "--reference=none/vicon/gnss", String, 'set the type of reference system available' do |reference|
        options[:reference] = reference
    end

    opt.on "-i", "--imu=old/new", String, 'since the imu component changed. Please set the type' do |imu|
        options[:imu] = imu
    end

    opt.on "-t", "--tof=none/sr4000", String, 'TOF camera is available' do |tof|
        options[:tof] = tof
    end

    opt.on "-c", "--camera=none/bb2", String, 'RGB BB2 camera is not available' do |camera|
        options[:camera] = camera
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

Bundles.run 'exoter_localization',
            :gdb => false do

    # Get the task names from perception
    localization_frontend = Orocos.name_service.get 'localization_frontend'

    # Set configuration files for slam
    Orocos.conf.apply(localization_frontend, ['default', 'hamming1hzsampling12hz'], :override => true)
    if options[:reference].casecmp("vicon").zero?
        localization_frontend.pose_reference_samples_period = 0.01 # Vicon is normally at 100Hz
    end
    if options[:reference].casecmp("gnss").zero?
        localization_frontend.pose_reference_samples_period = 0.1 # GNSS/GPS is normally at 10Hz
    end

    # logs files
    log_replay = Orocos::Log::Replay.open( logfiles_path )
    #log_replay.use_sample_time = true
    #log_replay.transformer_broadcaster.rename("old_transformer_broadcaster")

    #################
    ## TRANSFORMER ##
    #################
    Bundles.transformer.setup(localization_frontend)

    ###################
    ## LOG THE PORTS ##
    ###################
    Bundles.log_all

    # Configure tasks from perception
    localization_frontend.configure

    ###########################
    ## LOG PORTS CONNECTIONS ##
    ###########################
    log_replay.read_joint_dispatcher.joints_samples.connect_to(localization_frontend.joints_samples, :type => :buffer, :size => 200)

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

    if options[:tof].casecmp("mounted").zero?
        log_replay.camera_tof.pointcloud.connect_to(localization_frontend.point_cloud_samples, :type => :buffer, :size => 200)
    end

    if options[:camera].casecmp("bb2").zero?
        log_replay.camera_bb2.left_frame.connect_to(localization_frontend.left_frame, :type => :buffer, :size => 200)
        log_replay.camera_bb2.right_frame.connect_to(localization_frontend.right_frame, :type => :buffer, :size => 200)
    end

    ###########
    ## START ##
    ###########

    # Start tasks from slam
    localization_frontend.start

    # open the log replay widget
    control = Vizkit.control log_replay
    control.speed = 1

    Vizkit.exec
end
