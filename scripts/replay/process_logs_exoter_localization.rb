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

Bundles.run 'exoter_slam',
            :gdb => false do

    # Get the task names from slam
    localization_dispatcher = Orocos.name_service.get 'localization_dispatcher'
    localization_backend = Orocos.name_service.get 'localization_backend'

    # Set configuration files for slam backend
    Orocos.conf.apply(localization_dispatcher, ['default'], :override => true)
    Orocos.conf.apply(localization_backend, ['default'], :override => true)

    # logs files
    log_replay = Orocos::Log::Replay.open( logfiles_path )

    #################
    ## TRANSFORMER ##
    #################
    Bundles.transformer.setup(localization_backend)

    ###################
    ## LOG THE PORTS ##
    ###################
    Bundles.log_all

    # Configure tasks from slam
    localization_dispatcher.configure
    localization_backend.configure

    ###########################
    ## LOG PORTS CONNECTIONS ##
    ###########################
    log_replay.visual_odometry.delta_pose_samples_out.connect_to(localization_dispatcher.vodo_delta_pose, :type => :buffer, :size => 200)
    log_replay.visual_odometry.point_cloud_samples_out.connect_to(localization_dispatcher.vodo_points, :type => :buffer, :size => 200)
    log_replay.visual_odometry.point_cloud_uncertainty_out.connect_to(localization_dispatcher.vodo_covariance, :type => :buffer, :size => 200)
    log_replay.visual_odometry.point_cloud_indexes_out.connect_to(localization_dispatcher.vodo_index, :type => :buffer, :size => 200)
    log_replay.visual_odometry.delta_pose_jacobians_k_out.connect_to(localization_dispatcher.vodo_jacobian_k, :type => :buffer, :size => 200)
    log_replay.visual_odometry.delta_pose_jacobians_k_m_out.connect_to(localization_dispatcher.vodo_jacobian_k_m, :type => :buffer, :size => 200)

    # Localization odometry poses
    log_replay.exoter_odometry.pose_samples_out.connect_to(localization_backend.pose_samples, :type => :buffer, :size => 200)

    #############################
    ## TASKS PORTS CONNECTIONS ##
    #############################

    # Exteroceptive samples from dispatcher to back-end
    localization_dispatcher.vodo_samples_out.connect_to(localization_backend.vodo_samples, :type => :buffer, :size => 200)

    ###########
    ## START ##
    ###########
    localization_dispatcher.start
    localization_backend.start

    # open the log replay widget
    control = Vizkit.control log_replay
    control.speed = 1

    Vizkit.exec
end

