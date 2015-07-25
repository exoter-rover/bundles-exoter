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
options[:alone] = false

op = OptionParser.new do |opt|
    opt.banner = <<-EOD
    usage: process_logs_exoter_localization.rb [options] <data_log_directory>
    EOD

    opt.on "-r", "--reference=none/vicon/gnss", String, 'set the type of reference system available' do |reference|
        options[:reference] = reference
    end

    opt.on "-i", "--imu=old/new/last/ikf", String, 'chose imu component version or ikf orientation component. Please set the type' do |imu|
        options[:imu] = imu
    end

    opt.on "--alone", String, 'set alone in case you only want to execute the localization tasks' do
        options[:alone] = true
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
    puts "[INFO] Old type of IMU samples from logs"
elsif options[:imu].casecmp("new").zero?
    puts "[INFO] New type of IMU samples from logs"
elsif options[:imu].casecmp("last").zero?
    puts "[INFO] Last type of IMU samples from logs"
else
    puts "[INFO] IKF orientation from logs"
end

Bundles.run 'exoter_control',
            'exoter_perception',
            'exoter_localization',
            :gdb => false do

    # Get the task names from control
    read_joint_dispatcher = Orocos.name_service.get 'read_joint_dispatcher'
    ptu_control = Orocos.name_service.get 'ptu_control'

    # Get the task names from odometry
    localization_frontend = Orocos.name_service.get 'localization_frontend'
    exoter_odometry = Orocos.name_service.get 'exoter_odometry'

    # Get the task names from localization
    msc_localization = Orocos.name_service.get 'msc_localization'

    # Set configuration files for control
    Orocos.conf.apply(read_joint_dispatcher, ['reading'], :override => true)
    Orocos.conf.apply(ptu_control, ['default'], :override => true)

    # Set configuration files for odometry
    Orocos.conf.apply(localization_frontend, ['default', 'hamming1hzsampling12hz'], :override => true)
    Orocos.conf.apply(exoter_odometry, ['default', 'bessel50'], :override => true)
    exoter_odometry.urdf_file = Bundles.find_file('data/odometry', 'exoter_odometry_model_complete.urdf')

    # Set configuration files for localization
    Orocos.conf.apply(msc_localization, ['default'], :override => true)

    # logs files
    log_replay = Orocos::Log::Replay.open( logfiles_path )

    #################
    ## TRANSFORMER ##
    #################
    if options[:alone] == false
        Bundles.transformer.setup(localization_frontend)
    end
    Bundles.transformer.setup(msc_localization)

    ###################
    ## LOG THE PORTS ##
    ###################
    Bundles.log_all

    if options[:alone] == false
        # Configure tasks from control
        read_joint_dispatcher.configure
        ptu_control.configure

        # Configure tasks from odometry
        localization_frontend.configure
        exoter_odometry.configure
    end

    # Configure tasks from localization
    msc_localization.configure

    ###########################
    ## LOG PORTS CONNECTIONS ##
    ###########################
    if options[:alone] == false

        # Platform driver to localization front-end
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

        if options[:imu].casecmp("ikf").zero?
            log_replay.ikf_orientation_estimator.orientation_samples_out.connect_to(localization_frontend.orientation_samples, :type => :buffer, :size => 200)
            log_replay.imu_stim300.calibrated_sensors.connect_to(localization_frontend.inertial_samples, :type => :buffer, :size => 200)
        end

        if options[:reference].casecmp("vicon").zero?
            log_replay.vicon.pose_samples.connect_to(localization_frontend.pose_reference_samples, :type => :buffer, :size => 200)
        end

        if options[:reference].casecmp("gnss").zero?
            log_replay.gnss_trimble.pose_samples.connect_to(localization_frontend.pose_reference_samples, :type => :buffer, :size => 200)
        end
    else
        # Localization odometry poses
        log_replay.exoter_odometry.delta_pose_samples_out.connect_to(msc_localization.delta_pose_samples, :type => :buffer, :size => 200)
    end

    #############################
    ## TASKS PORTS CONNECTIONS ##
    #############################
    if options[:alone] == false
        read_joint_dispatcher.joints_samples.connect_to localization_frontend.joints_samples
        read_joint_dispatcher.ptu_samples.connect_to ptu_control.ptu_samples
        localization_frontend.joints_samples_out.connect_to exoter_odometry.joints_samples
        localization_frontend.orientation_samples_out.connect_to exoter_odometry.orientation_samples
        exoter_odometry.delta_pose_samples_out.connect_to msc_localization.delta_pose_samples
    end

    # Exteroceptive samples from dispatcher to back-end
    log_replay.visual_stereo.features_samples_out.connect_to(msc_localization.visual_features_samples, :type => :buffer, :size => 200)

    ###########
    ## START ##
    ###########
    if options[:alone] == false

        # Start tasks for control
        read_joint_dispatcher.start
        ptu_control.start

        # Start tasks for odometry
        localization_frontend.start
        exoter_odometry.start
    end

    # Start tasks for localization
    msc_localization.start

    # open the log replay widget
    control = Vizkit.control log_replay
    control.speed = 1

    Vizkit.exec
end

