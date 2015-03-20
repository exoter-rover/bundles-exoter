#!/usr/bin/env ruby

require 'rock/bundle'
require 'readline'
require 'utilrb'

include Orocos

## Initialize orocos ##
Orocos::CORBA::max_message_size = 100000000000
Bundles.initialize

Bundles.transformer.load_conf(Bundles.find_file('config', 'transforms_scripts.rb'))

Orocos::Process.run 'exoter_slam',
                'exoter_proprioceptive' do

    # Localization
    puts "Setting up localization_frontend"
    localization_frontend = Orocos.name_service.get 'localization_frontend'
    Orocos.conf.apply(localization_frontend, ['default', 'bessel50'], :override => true)
    Bundles.transformer.setup(localization_frontend)
    puts "done"

    # Odometry
    puts "Setting up exoter_odometry"
    exoter_odometry = Orocos.name_service.get 'exoter_odometry'
    Orocos.conf.apply(exoter_odometry, ['default', 'bessel50'], :override => true)
    exoter_odometry.urdf_file = Bundles.find_file('data/odometry', 'exoter_odometry_model.urdf')
    Bundles.transformer.setup(exoter_odometry)
    puts "done"

    # STIM300 IMU
    puts "Setting up imu_stim300 imu"
    imu_stim300 = TaskContext.get 'imu_stim300'
    Orocos.conf.apply(imu_stim300,  ['default','ExoTer','ESTEC','stim300_5g'], :override => true)
    puts "done"

    # Transformer Setup

    ## Get the control level task context ##
    puts "Getting exoter_control tasks"
    read_joint_dispatcher = Orocos.name_service.get 'read_joint_dispatcher'
    puts "done"

    #Configure Tasks
    localization_frontend.configure
    exoter_odometry.configure
    imu_stim300.configure

    # Connect the ports
    puts "Connecting ports"
    read_joint_dispatcher.joints_samples.connect_to localization_frontend.joints_samples
    read_joint_dispatcher.ptu_samples.connect_to localization_frontend.ptu_samples
    imu_stim300.orientation_samples_out.connect_to localization_frontend.orientation_samples
    imu_stim300.compensated_sensors_out.connect_to localization_frontend.inertial_samples
    localization_frontend.joints_samples_out.connect_to exoter_odometry.joints_samples
    localization_frontend.orientation_samples_out.connect_to exoter_odometry.orientation_samples
    puts "done"

    # Log all ports
    Orocos.log_all_ports

    #Start the tasks
    localization_frontend.start
    exoter_odometry.start

    Readline::readline("Press ENTER to exit\n") do
    end
end
