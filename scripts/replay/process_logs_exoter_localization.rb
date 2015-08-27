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
options[:odometry] = 'none'
options[:reaction_forces] = false
options[:visual] = 'none'
options[:gp] = false

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

    opt.on "-o", "--odometry=task/log", String, 'select Odometry from a running task or from the log files ' do |odometry|
        options[:odometry] = odometry
    end

    opt.on "-f", "--reaction_forces", String, 'connect the reaction forces for the 3D Odometry' do
        options[:reaction_forces] = true
    end

    opt.on "-v", "--visual=task/log", String, 'select visual stereo task running task or from log files' do |visual|
        options[:visual] = visual
    end

    opt.on "-g", "--gaussian_processes", String, 'estimate Odometry uncertainty using Gaussian processes' do
        options[:gp] = true
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

if options[:odometry].casecmp("task").zero?
    puts "[INFO] Odometry task running"
elsif options[:odometry].casecmp("log").zero?
    puts "[INFO] Odometry from log files"
else
    puts "[INFO] No Odometry selected"
    exit 1
end

if options[:reaction_forces]
    puts "[INFO] Enhanced 3D Odometry with reaction forces"
else
    puts "[INFO] 3D Odometry without reaction forces enhancement"
end

if options[:visual].casecmp("task").zero?
    puts "[INFO] Visual task running"
elsif options[:visual].casecmp("log").zero?
    puts "[INFO] Visual information from log files"
else
    puts "[INFO] No Visual selected"
    exit 1
end

if options[:gp]
    puts "[INFO] Gaussian processes to estimate uncertainty"
else
    puts "[INFO] No gaussian processes to estimate uncertainty"
end

Bundles.run 'exoter_control',
            'exoter_localization',
            :gdb => false do

    # Get the task names from control
    read_joint_dispatcher = Orocos.name_service.get 'read_joint_dispatcher'
    ptu_control = Orocos.name_service.get 'ptu_control'

    # Get the task names from odometry
    localization_frontend = Orocos.name_service.get 'localization_frontend'
    exoter_odometry = Orocos.name_service.get 'exoter_odometry'
    gp_odometry = Orocos.name_service.get 'gp_odometry'

    # Get the task names from localization
    msc_localization = Orocos.name_service.get 'msc_localization'
    visual_stereo = Orocos.name_service.get 'visual_stereo'

    # Set configuration files for control
    Orocos.conf.apply(read_joint_dispatcher, ['reading'], :override => true)
    Orocos.conf.apply(ptu_control, ['default'], :override => true)

    # Set configuration files for odometry
    Orocos.conf.apply(localization_frontend, ['default', 'hamming1hzsampling12hz'], :override => true)
    Orocos.conf.apply(exoter_odometry, ['default', 'bessel50'], :override => true)
    exoter_odometry.urdf_file = Bundles.find_file('data/odometry', 'exoter_odometry_model_complete.urdf')

    if options[:gp]
        Orocos.conf.apply(gp_odometry, ['gp_sklearn'], :override => true)
        gp_odometry.gaussian_process_x_axis_file = Bundles.find_file('data/gaussian_processes', 'gp_sklearn_x_delta_pose.data')
        gp_odometry.gaussian_process_y_axis_file = Bundles.find_file('data/gaussian_processes', 'gp_sklearn_y_delta_pose.data')
        gp_odometry.gaussian_process_z_axis_file = Bundles.find_file('data/gaussian_processes', 'gp_sklearn_z_delta_pose.data')
    end

    # Set configuration files for localization
    Orocos.conf.apply(msc_localization, ['default', 'bumblebee_stereo_noise'], :override => true)
    Orocos.conf.apply(visual_stereo, ['default', 'bumblebee'], :override => true)

    # logs files
    log_replay = Orocos::Log::Replay.open( logfiles_path )

    #################
    ## TRANSFORMER ##
    #################
    if options[:odometry].casecmp("task").zero?
        Bundles.transformer.setup(localization_frontend)
    end

    Bundles.transformer.setup(msc_localization)

    if options[:visual].casecmp("task").zero?
        Bundles.transformer.setup(visual_stereo)
    end


    ###################
    ## LOG THE PORTS ##
    ###################
    Bundles.log_all

    # Configure tasks from control
    read_joint_dispatcher.configure
    ptu_control.configure
    localization_frontend.configure

    if options[:odometry].casecmp("task").zero?
        # Configure tasks from odometry
        exoter_odometry.configure
    end

    if options[:gp]
        gp_odometry.configure
    end

    # Configure tasks from localization
    msc_localization.configure

    if options[:visual].casecmp("task").zero?
        visual_stereo.configure
    end

    ###########################
    ## LOG PORTS CONNECTIONS ##
    ###########################

    # Platform driver to localization front-end
    log_replay.platform_driver.joints_readings.connect_to(read_joint_dispatcher.joints_readings, :type => :buffer, :size => 200)

    if options[:reference].casecmp("vicon").zero?
        log_replay.vicon.pose_samples.connect_to(localization_frontend.pose_reference_samples, :type => :buffer, :size => 200)
    end

    if options[:reference].casecmp("gnss").zero?
        log_replay.gnss_trimble.pose_samples.connect_to(localization_frontend.pose_reference_samples, :type => :buffer, :size => 200)
    end


    if options[:odometry].casecmp("task").zero?

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

    end

    #############################
    ## TASKS PORTS CONNECTIONS ##
    #############################
    read_joint_dispatcher.joints_samples.connect_to localization_frontend.joints_samples,  :type => :buffer, :size => 1000
    read_joint_dispatcher.ptu_samples.connect_to ptu_control.ptu_samples,  :type => :buffer, :size => 1000

    if options[:odometry].casecmp("task").zero?
        localization_frontend.joints_samples_out.connect_to exoter_odometry.joints_samples,  :type => :buffer, :size => 1000
        localization_frontend.orientation_samples_out.connect_to exoter_odometry.orientation_samples,  :type => :buffer, :size => 1000

        if options[:reaction_forces]
            localization_frontend.weighting_samples_out.connect_to exoter_odometry.weighting_samples, :type => :buffer, :size => 1000
        end

        if options[:gp]
            exoter_odometry.delta_pose_samples_out.connect_to gp_odometry.delta_pose_samples,  :type => :buffer, :size => 200
            localization_frontend.joints_samples_out.connect_to gp_odometry.joints_samples, :type => :buffer, :size => 200
            localization_frontend.orientation_samples_out.connect_to gp_odometry.orientation_samples, :type => :buffer, :size => 200
            gp_odometry.delta_pose_samples_out.connect_to msc_localization.delta_pose_samples,  :type => :buffer, :size => 1000
        else
            exoter_odometry.delta_pose_samples_out.connect_to msc_localization.delta_pose_samples,  :type => :buffer, :size => 1000
        end

    elsif options[:odometry].casecmp("log").zero?
        # Localization odometry poses
        log_replay.exoter_odometry.delta_pose_samples_out.connect_to(msc_localization.delta_pose_samples, :type => :buffer, :size => 1000)
    end

    if options[:visual].casecmp("task").zero?
        # Camera images for the visual task
        log_replay.camera_bb2.left_frame.connect_to visual_stereo.left_frame, :type => :buffer, :size => 200
        log_replay.camera_bb2.right_frame.connect_to visual_stereo.right_frame, :type => :buffer, :size => 200

        # Exteroceptive samples to the localization
        visual_stereo.features_samples_out.connect_to msc_localization.visual_features_samples, :type => :buffer, :size => 1000

    elsif options[:visual].casecmp("log").zero?
        # Exteroceptive samples to the localization
        log_replay.visual_stereo.features_samples_out.connect_to(msc_localization.visual_features_samples, :type => :buffer, :size => 1000)
    end

    ###########
    ## START ##
    ###########
    # Start tasks for control
    read_joint_dispatcher.start
    ptu_control.start
    localization_frontend.start

    if options[:odometry].casecmp("task").zero?
        # Start tasks for odometry
        exoter_odometry.start
    end

    if options[:gp]
        gp_odometry.start
    end

    # Start tasks for localization
    msc_localization.start

    if options[:visual].casecmp("task").zero?
        # Start tasks for visual
        visual_stereo.start
    end


    # open the log replay widget
    control = Vizkit.control log_replay
    control.speed = 1

    Vizkit.exec
end

