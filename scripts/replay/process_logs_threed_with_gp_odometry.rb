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
options[:gaussian_process] = "gpy"
options[:reaction_forces] = false

op = OptionParser.new do |opt|
    opt.banner = <<-EOD
    usage: process_logs_threed_with_gp_odometry [options] <data_log_directory>
    EOD

    opt.on "-r", "--reference=none/vicon/gnss", String, 'set the type of reference system available' do |reference|
        options[:reference] = reference
    end

    opt.on "-i", "--imu=old/new/last", String, 'since the imu component changed. Please set the type' do |imu|
        options[:imu] = imu
    end

    opt.on "-f", "--reaction_forces", String, 'connect the reaction forces for the 3D Odometry' do
        options[:reaction_forces] = true
    end

    opt.on "-g", "--gaussian_process=sklearn/gpy", String, 'Type of the Gaussian process.' do |gp|
        options[:gaussian_process] = gp
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
    puts "[INFO] GNSS Ground Truth system available"
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

if options[:gaussian_process].casecmp("sklearn").zero?
    puts "[INFO] Selected Sklearn Gaussian process"
elsif options[:gaussian_process].casecmp("gpy").zero?
    puts "[INFO] Selected GPy Gaussian process"
end

if options[:reaction_forces]
    puts "[INFO] Enhanced 3D Odometry with reaction forces"
else
    puts "[INFO] 3D Odometry without reaction forces enhancement"
end

Bundles.run 'joint_dispatcher::Task' => 'read_joint_dispatcher',
            'ptu_control::Task' => 'ptu_control',
            'localization_frontend::Task' => 'localization_frontend',
            'threed_odometry::Task' => 'exoter_odometry',
            'gp_odometry::SklearnTask' => 'sklearn_gp_odometry',
            'gp_odometry::GpyTask' => 'gpy_gp_odometry',
            :gdb => false,
            :output => nil do

    # Get the task names from control
    read_joint_dispatcher = Orocos.name_service.get 'read_joint_dispatcher'
    ptu_control = Orocos.name_service.get 'ptu_control'

    # Get the task names from odometry
    localization_frontend = Orocos.name_service.get 'localization_frontend'
    exoter_odometry = Orocos.name_service.get 'exoter_odometry'

    if options[:gaussian_process].casecmp("sklearn").zero?
        gp_odometry = Orocos.name_service.get 'sklearn_gp_odometry'
    elsif options[:gaussian_process].casecmp("gpy").zero?
        gp_odometry = Orocos.name_service.get 'gpy_gp_odometry'
    end

    # Set configuration files for control
    Orocos.conf.apply(read_joint_dispatcher, ['reading'], :override => true)
    Orocos.conf.apply(ptu_control, ['default'], :override => true)

    # Set configuration files for odometry
    Orocos.conf.apply(localization_frontend, ['default', 'hamming1hzsampling12hz'], :override => true)
    Orocos.conf.apply(exoter_odometry, ['default', 'bessel50'], :override => true)
    exoter_odometry.urdf_file = Bundles.find_file('data/odometry', 'exoter_odometry_model_complete.urdf')

    if options[:gaussian_process].casecmp("sklearn").zero?
        Orocos.conf.apply(gp_odometry, ['gp_sklearn'], :override => true)
        gp_odometry.gaussian_process_x_axis_file = Bundles.find_file('data/gaussian_processes', 'gp_sklearn_x_delta_pose.data')
        gp_odometry.gaussian_process_y_axis_file = Bundles.find_file('data/gaussian_processes', 'gp_sklearn_y_delta_pose.data')
        gp_odometry.gaussian_process_z_axis_file = Bundles.find_file('data/gaussian_processes', 'gp_sklearn_z_delta_pose.data')
    elsif options[:gaussian_process].casecmp("gpy").zero?
        Orocos.conf.apply(gp_odometry, ['gp_gpy'], :override => true)
        gp_odometry.gaussian_process_file = Bundles.find_file('data/gaussian_processes', 'SparseGP_RBF_xyz_velocities_train_at_500ms_normalized.data')
        #gp_odometry.gaussian_process_file = Bundles.find_file('data/gaussian_processes', 'GP_RBF_xyz_velocities_train_at_1s_normalized.data')
    end

    # logs files
    log_replay = Orocos::Log::Replay.open( logfiles_path )

    #################
    ## TRANSFORMER ##
    #################
    Bundles.transformer.setup(localization_frontend)
    Bundles.transformer.setup(exoter_odometry)

    ###################
    ## LOG THE PORTS ##
    ###################
    Bundles.log_all

    # Configure tasks from control
    read_joint_dispatcher.configure
    ptu_control.configure

    # Configure tasks from odometry
    localization_frontend.configure
    exoter_odometry.configure
    gp_odometry.configure

    ###########################
    ## LOG PORTS CONNECTIONS ##
    ###########################
    log_replay.platform_driver.joints_readings.connect_to(read_joint_dispatcher.joints_readings, :type => :buffer, :size => 200)

    if options[:reference].casecmp("vicon").zero?
        log_replay.vicon.pose_samples.connect_to(localization_frontend.pose_reference_samples, :type => :buffer, :size => 200)
    end

    if options[:reference].casecmp("gnss").zero?
        log_replay.gnss_trimble.pose_samples.connect_to(localization_frontend.pose_reference_samples, :type => :buffer, :size => 200)
    end

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

    #############################
    ## TASKS PORTS CONNECTIONS ##
    #############################

    read_joint_dispatcher.joints_samples.connect_to localization_frontend.joints_samples, :type => :buffer, :size => 200
    read_joint_dispatcher.ptu_samples.connect_to ptu_control.ptu_samples, :type => :buffer, :size => 200
    localization_frontend.joints_samples_out.connect_to exoter_odometry.joints_samples, :type => :buffer, :size => 200
    localization_frontend.orientation_samples_out.connect_to exoter_odometry.orientation_samples, :type => :buffer, :size => 200

    if options[:reaction_forces]
        localization_frontend.weighting_samples_out.connect_to exoter_odometry.weighting_samples, :type => :buffer, :size => 200
    end

    exoter_odometry.delta_pose_samples_out.connect_to gp_odometry.delta_pose_samples, :type => :buffer, :size => 200
    localization_frontend.joints_samples_out.connect_to gp_odometry.joints_samples, :type => :buffer, :size => 200
    localization_frontend.orientation_samples_out.connect_to gp_odometry.orientation_samples, :type => :buffer, :size => 200

    if options[:gaussian_process].casecmp("gpy").zero?
        localization_frontend.inertial_samples_out.connect_to gp_odometry.inertial_samples, :type => :buffer, :size => 200
    end

    # Start tasks from control
    read_joint_dispatcher.start
    ptu_control.start

    # Start tasks from slam
    localization_frontend.start
    exoter_odometry.start
    gp_odometry.start

    # open the log replay widget
    control = Vizkit.control log_replay
    control.speed = 1

    Vizkit.exec
end
