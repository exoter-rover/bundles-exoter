#!/usr/bin/env ruby

require 'orocos'
require 'orocos/log'
require 'rock/bundle'
require 'vizkit'
require 'utilrb'
require 'readline'
require 'optparse'

include Orocos

options = {}
options[:reference] = "none"
options[:imu] = "new"
options[:camera_bb2] = 'none'
options[:odometry] = 'none'
options[:reaction_forces] = false
options[:gaussian_process] = "none"
options[:point_cloud] = "none"
options[:test] = 'none'
options[:threshold] = 'none'

op = OptionParser.new do |opt|
    opt.banner = <<-EOD
    usage: proces_logs_orb_slam2 [options] <data_log_directory>
    EOD

    opt.on "-r", "--reference=none/vicon/gnss", String, 'set the type of reference system available' do |reference|
        options[:reference] = reference
    end

    opt.on "-i", "--imu=old/new/last/ikf", String, 'chose imu component version or ikf orientation component. Please set the type' do |imu|
        options[:imu] = imu
    end

    opt.on "-c", "--camera_bb2=task/log", String, 'set the type of camera_bb2: task to run the task log for taking the images from an existing log' do |camera|
        options[:camera_bb2] = camera
    end

    opt.on "-o", "--odometry=none/task/log", String, 'select Odometry from a running task or from the log files ' do |odometry|
        options[:odometry] = odometry
    end

    opt.on "-f", "--reaction_forces", String, 'connect the reaction forces for the 3D Odometry' do
        options[:reaction_forces] = true
    end

    opt.on "-g", "--gaussian_process=none/sklearn/gpy", String, 'Type of the Gaussian process.' do |gp|
        options[:gaussian_process] = gp
    end

    opt.on "--point_cloud=none/stereo/tof", String, 'Log point cloud to use for dense map reconstruction.' do |point_cloud|
        options[:point_cloud] = point_cloud
    end

    opt.on "-t", "--test=arl_20141027-2034/arl_20150515-1752/decos_20140911-1805", String, 'set the type: GP model to load and ARL map or Decos terrain' do |test|
        options[:test] = test
    end

    opt.on "-h", "--gp_threshold=10_6cm_s/25_6cm_s/50_6cm_s/100_6cm_s/100_10cm_s/50_10cm_s/25_10cm_s/10_10cm_s", String, 'GP Odometry error threshold' do |threshold|
        options[:threshold] = threshold
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
Bundles::initialize
Bundles::transformer::load_conf(Bundles::find_file('config', 'transforms_scripts_orb_slam2.rb'))

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

if options[:camera_bb2].casecmp("task").zero?
    puts "[INFO] Running task camera_bb2"
elsif options[:camera_bb2].casecmp("log").zero?
    puts "[INFO] camera_bb2 taken from logs"
else
    puts "[INFO] Please specify camera_bb2! EXIT"
    exit 1
end


if options[:odometry].casecmp("task").zero?
    puts "[INFO] Odometry task running"
elsif options[:odometry].casecmp("log").zero?
    puts "[INFO] Odometry from log files"
elsif options[:odometry].casecmp("none").zero?
    puts "[INFO] No Odometry selected!"
else
    puts "[INFO] Please specify odometry! EXIT"
    exit 1
end

if options[:gaussian_process].casecmp("sklearn").zero?
    puts "[INFO] Selected Sklearn Gaussian process"
elsif options[:gaussian_process].casecmp("gpy").zero?
    puts "[INFO] Selected GPy Gaussian process"
else
    puts "[INFO] NO Gaussian process selected"
end

if options[:reaction_forces]
    puts "[INFO] Enhanced 3D Odometry with reaction forces"
else
    puts "[INFO] 3D Odometry without reaction forces enhancement"
end

if options[:point_cloud].casecmp("stereo").zero?
    puts "[INFO] Selected Stereo point clouds logs"
elsif options[:point_cloud].casecmp("tof").zero?
    puts "[INFO] Selected TOF point cloud logs"
else
    puts "[INFO] NO point clouds selected"
end

if options[:test].casecmp("arl_20141027-2034").zero?
    puts "[INFO] ARL 20141027-2034 GP model, terrain boundaries and resolution selected"
elsif options[:test].casecmp("arl_20150515-1752").zero?
    puts "[INFO] ARL 20150515-1752 GP model, terrain boundaries and resolution selected"
elsif options[:test].casecmp("decos_20140911-1805").zero?
    puts "[INFO] Decos 20140911-1805 GP model, terrain boundaries and resolution selected"
else
    puts "[INFO] Please specify test! EXIT"
    exit 1
end

if options[:threshold].casecmp("none").zero?
    puts "[INFO] Please specify Odometry error threshold! EXIT"
    exit 1
end

Bundles::run 'joint_dispatcher::Task' => 'read_joint_dispatcher',
            'ptu_control::Task' => 'ptu_control',
            'localization_frontend::Task' => 'localization_frontend',
            'threed_odometry::Task' => 'exoter_odometry',
            'gp_odometry::SklearnTask' => 'sklearn_gp_odometry',
            'gp_odometry::GpyTask' => 'gpy_gp_odometry',
            'orb_slam2::Task' => 'orb_slam2',
            'camera_bb2::Task' => 'camera_bb2',
            #:gdb => ['orb_slam2'],
            :output => nil do

    ## Get the task context ##
    STDERR.print "setting up read_joint_dispatcher..."
    read_joint_dispatcher = Orocos.name_service.get 'read_joint_dispatcher'
    Orocos.conf.apply(read_joint_dispatcher, ['reading'], :override => true)
    STDERR.puts "done"

    ## Get the task context ##
    STDERR.print "setting up ptu_control..."
    ptu_control = Orocos.name_service.get 'ptu_control'
    Orocos.conf.apply(ptu_control, ['default'], :override => true)
    STDERR.puts "done"

    ## Get the task context ##
    STDERR.print "setting up localization_frontend..."
    localization_frontend = Orocos.name_service.get 'localization_frontend'
    Orocos.conf.apply(localization_frontend, ['default', 'hamming1hzsampling12hz'], :override => true)
    if options[:reference].casecmp("vicon").zero?
        localization_frontend.pose_reference_samples_period = 0.01 # Vicon is normally at 100Hz
    end
    if options[:reference].casecmp("gnss").zero?
        localization_frontend.pose_reference_samples_period = 0.1 # GNSS/GPS is normally at 10Hz
    end
    STDERR.puts "done"

    if options[:camera_bb2].casecmp("task").zero?
        camera_bb2 = Orocos.name_service.get 'camera_bb2'
        Orocos.conf.apply(camera_bb2, ['default'], :override => true)
    end
    ## Get the task context ##
    STDERR.print "setting up exoter_odometry..."
    exoter_odometry = Orocos.name_service.get 'exoter_odometry'
    Orocos.conf.apply(exoter_odometry, ['default', 'bessel50'], :override => true)
    exoter_odometry.urdf_file = Bundles.find_file('data/odometry', 'exoter_odometry_model_complete.urdf')

    STDERR.puts "done"

    if options[:gaussian_process].casecmp("sklearn").zero?
        STDERR.print "setting up Sklearn gp_odometry..."
        gp_odometry = Orocos.name_service.get 'sklearn_gp_odometry'
        Orocos.conf.apply(gp_odometry, ['gp_sklearn'], :override => true)
        gp_odometry.gaussian_process_x_axis_file = Bundles.find_file('data/gaussian_processes', 'gp_sklearn_x_delta_pose.data')
        gp_odometry.gaussian_process_y_axis_file = Bundles.find_file('data/gaussian_processes', 'gp_sklearn_y_delta_pose.data')
        gp_odometry.gaussian_process_z_axis_file = Bundles.find_file('data/gaussian_processes', 'gp_sklearn_z_delta_pose.data')
        STDERR.puts "done"
    elsif options[:gaussian_process].casecmp("gpy").zero?
        STDERR.print "setting up GPy gp_odometry..."
        gp_odometry = Orocos.name_service.get 'gpy_gp_odometry'
        Orocos.conf.apply(gp_odometry, ['gp_gpy'], :override => true)
        #gp_odometry.gaussian_process_file = Bundles.find_file('data/gaussian_processes', 'SparseGP_RBF_xyz_velocities_train_at_500ms_normalized.data')
        if options[:test].casecmp("arl_20141027-2034").zero?
            gp_odometry.gaussian_process_file = Bundles.find_file('data/gaussian_processes', 'SparseGP_RBF_NL_xyz_velocities_train_at_1s_normalized_exoter_odometry_arl_residuals_20141027-2034.data')
        elsif options[:test].casecmp("arl_20150515-1752").zero?
            gp_odometry.gaussian_process_file = Bundles.find_file('data/gaussian_processes', 'SparseGP_RBF_NL_xyz_velocities_train_at_1s_normalized_exoter_odometry_arl_residuals_20150515-1752.data')
        elsif options[:test].casecmp("decos_20140911-1805").zero?
            gp_odometry.gaussian_process_file = Bundles.find_file('data/gaussian_processes', 'SparseGP_RBF_NL_xyz_velocities_train_at_1s_normalized_exoter_odometry_decos_residuals_20140911-1805_complete.data')
        end
        STDERR.puts "done"
    end

    ## Get the task context ##
    STDERR.print "setting up orb_slam2.."
    orb_slam2 = TaskContext.get 'orb_slam2'
    if options[:test].casecmp("arl_20141027-2034").zero? or options[:test].casecmp("arl_20150515-1752").zero?
        if options[:threshold].casecmp("10_6cm_s").zero?
            Orocos.conf.apply(orb_slam2, ['default', 'bumblebee', 'arl_map', '10_6cm_s'], :override => true)
        elsif options[:threshold].casecmp("25_6cm_s").zero?
            Orocos.conf.apply(orb_slam2, ['default', 'bumblebee', 'arl_map', '25_6cm_s'], :override => true)
        elsif options[:threshold].casecmp("50_6cm_s").zero?
            Orocos.conf.apply(orb_slam2, ['default', 'bumblebee', 'arl_map', '50_6cm_s'], :override => true)
        elsif options[:threshold].casecmp("100_6cm_s").zero?
            Orocos.conf.apply(orb_slam2, ['default', 'bumblebee', 'arl_map', '100_6cm_s'], :override => true)
        end
    elsif options[:test].casecmp("decos_20140911-1805").zero?
        if options[:threshold].casecmp("10_10cm_s").zero?
            Orocos.conf.apply(orb_slam2, ['default', 'bumblebee', 'decos_map', '10_10cm_s'], :override => true)
        elsif options[:threshold].casecmp("25_10cm_s").zero?
            Orocos.conf.apply(orb_slam2, ['default', 'bumblebee', 'decos_map', '25_10cm_s'], :override => true)
        elsif options[:threshold].casecmp("50_10cm_s").zero?
            Orocos.conf.apply(orb_slam2, ['default', 'bumblebee', 'decos_map', '50_10cm_s'], :override => true)
        elsif options[:threshold].casecmp("100_10cm_s").zero?
            Orocos.conf.apply(orb_slam2, ['default', 'bumblebee', 'decos_map', '100_10cm_s'], :override => true)
        end
    end

    if options[:point_cloud].casecmp("stereo").zero?
        orb_slam2.point_cloud_samples_period = 5.0
    elsif  options[:point_cloud].casecmp("tof").zero?
        orb_slam2.point_cloud_samples_period = 0.2
    end
    STDERR.puts "done"

    # logs files
    log_replay = Orocos::Log::Replay.open( logfiles_path )

    #################
    ## TRANSFORMER ##
    #################
    Bundles::transformer::setup(localization_frontend)
    Bundles::transformer::setup(orb_slam2)
    if options[:odometry].casecmp("task").zero?
        Bundles.transformer.setup(exoter_odometry)
    end

    ###################
    ## LOG THE PORTS ##
    ###################
    Bundles::log_all
    #localization_frontend.log_all_ports
    #orb_slam2.log_all_ports

    ###############
    ## CONFIGURE ##
    ###############
    read_joint_dispatcher.configure
    ptu_control.configure
    localization_frontend.configure

    if options[:camera_bb2].casecmp("task").zero?
        camera_bb2.configure
    end

    if options[:odometry].casecmp("task").zero?
        # Configure tasks from odometry
        exoter_odometry.configure
    end

    if options[:gaussian_process].casecmp("none").nonzero?
        gp_odometry.configure
    end

    orb_slam2.configure

    ###########################
    ## LOG PORTS CONNECTIONS ##
    ###########################
    log_replay.platform_driver.joints_readings.connect_to(read_joint_dispatcher.joints_readings, :type => :buffer, :size => 100)

    if options[:reference].casecmp("vicon").zero?
        log_replay.vicon.pose_samples.connect_to(localization_frontend.pose_reference_samples, :type => :buffer, :size => 100)
    end

    if options[:reference].casecmp("gnss").zero?
        log_replay.gnss_trimble.pose_samples.connect_to(localization_frontend.pose_reference_samples, :type => :buffer, :size => 100)
    end

    # Localization front-end port connections
    if options[:imu].casecmp("old").zero?
        log_replay.stim300.orientation_samples_out.connect_to(localization_frontend.orientation_samples, :type => :buffer, :size => 100)
        log_replay.stim300.calibrated_sensors.connect_to(localization_frontend.inertial_samples, :type => :buffer, :size => 100)
    end

    if options[:imu].casecmp("new").zero?
        log_replay.imu_stim300.orientation_samples_out.connect_to(localization_frontend.orientation_samples, :type => :buffer, :size => 100)
        log_replay.imu_stim300.calibrated_sensors.connect_to(localization_frontend.inertial_samples, :type => :buffer, :size => 100)
    end

    if options[:imu].casecmp("last").zero?
        log_replay.imu_stim300.orientation_samples_out.connect_to(localization_frontend.orientation_samples, :type => :buffer, :size => 100)
        log_replay.imu_stim300.compensated_sensors_out.connect_to(localization_frontend.inertial_samples, :type => :buffer, :size => 100)
    end

    if options[:imu].casecmp("ikf").zero?
        log_replay.ikf_orientation_estimator.orientation_samples_out.connect_to(localization_frontend.orientation_samples, :type => :buffer, :size => 100)
        log_replay.imu_stim300.calibrated_sensors.connect_to(localization_frontend.inertial_samples, :type => :buffer, :size => 100)
    end

    if options[:point_cloud].casecmp("stereo").zero?
        log_replay.stereo_filtered.point_cloud_samples_out.connect_to orb_slam2.point_cloud_samples, :type => :buffer, :size => 5
    elsif  options[:point_cloud].casecmp("tof").zero?
        log_replay.colorize_pointcloud.colored_points.connect_to orb_slam2.point_cloud_samples, :type => :buffer, :size => 5
    end

    if options[:camera_bb2].casecmp("task").zero?
        log_replay.camera_firewire.frame.connect_to camera_bb2.frame_in, :type => :buffer, :size => 5

        camera_bb2.left_frame.connect_to orb_slam2.left_frame, :type => :buffer, :size => 5
        camera_bb2.right_frame.connect_to orb_slam2.right_frame, :type => :buffer, :size => 5
    elsif options[:camera_bb2].casecmp("log").zero?
        log_replay.camera_bb2.left_frame.connect_to orb_slam2.left_frame, :type => :buffer, :size => 5
        log_replay.camera_bb2.right_frame.connect_to orb_slam2.right_frame, :type => :buffer, :size => 5
    end

    #############################
    ## TASKS PORTS CONNECTIONS ##
    #############################

    read_joint_dispatcher.joints_samples.connect_to localization_frontend.joints_samples
    read_joint_dispatcher.ptu_samples.connect_to ptu_control.ptu_samples

    if options[:odometry].casecmp("task").zero?
        localization_frontend.joints_samples_out.connect_to exoter_odometry.joints_samples,  :type => :buffer, :size => 100
        localization_frontend.orientation_samples_out.connect_to exoter_odometry.orientation_samples,  :type => :buffer, :size => 100

        if options[:reaction_forces]
            localization_frontend.weighting_samples_out.connect_to exoter_odometry.weighting_samples, :type => :buffer, :size => 100
        end

        if options[:gaussian_process].casecmp("none").nonzero?
            exoter_odometry.delta_pose_samples_out.connect_to gp_odometry.delta_pose_samples,  :type => :buffer, :size => 100
            localization_frontend.joints_samples_out.connect_to gp_odometry.joints_samples, :type => :buffer, :size => 100
            localization_frontend.orientation_samples_out.connect_to gp_odometry.orientation_samples, :type => :buffer, :size => 100
            gp_odometry.delta_pose_samples_out.connect_to orb_slam2.delta_pose_samples,  :type => :buffer, :size => 100
        else
            # SLAM odometry poses
            exoter_odometry.delta_pose_samples_out.connect_to orb_slam2.delta_pose_samples,  :type => :buffer, :size => 100
        end

    elsif options[:odometry].casecmp("log").zero?
        if options[:gaussian_process].casecmp("none").nonzero?
            log_replay.exoter_odometry.delta_pose_samples_out.connect_to(gp_odometry.delta_pose_samples, :type => :buffer, :size => 100)
            localization_frontend.joints_samples_out.connect_to gp_odometry.joints_samples, :type => :buffer, :size => 100
            localization_frontend.orientation_samples_out.connect_to gp_odometry.orientation_samples, :type => :buffer, :size => 100
            gp_odometry.delta_pose_samples_out.connect_to orb_slam2.delta_pose_samples,  :type => :buffer, :size => 100
        else
            # SLAM odometry poses
            log_replay.exoter_odometry.delta_pose_samples_out.connect_to(orb_slam2.delta_pose_samples, :type => :buffer, :size => 100)
        end
    end

    if options[:gaussian_process].casecmp("gpy").zero?
        localization_frontend.inertial_samples_out.connect_to gp_odometry.inertial_samples, :type => :buffer, :size => 100
    end

    ###########
    ## START ##
    ###########
    read_joint_dispatcher.start
    ptu_control.start
    localization_frontend.start

    if options[:camera_bb2].casecmp("task").zero?
        camera_bb2.start
    end

    if options[:odometry].casecmp("task").zero?
        # Start tasks for odometry
        exoter_odometry.start
    end

    if options[:gaussian_process].casecmp("none").nonzero?
        gp_odometry.start
    end

    orb_slam2.start

    # open the log replay widget
    control = Vizkit.control log_replay
    control.speed = 1

    Vizkit.exec

end
