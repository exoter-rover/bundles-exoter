#!/usr/bin/env ruby

require 'rock/bundle'
require 'readline'
require 'utilrb'

include Orocos

## Initialize orocos ##
Orocos::CORBA::max_message_size = 100000000000
Bundles.initialize

Bundles.transformer.load_conf(Bundles.find_file('config', 'transforms_scripts.rb'))

Orocos::Process.run 'exoter_control',
                'exoter_localization',
                'exoter_proprioceptive' do

    # setup platform_driver
    puts "Setting up platform_driver"
    platform_driver = Orocos.name_service.get 'platform_driver'
    Orocos.conf.apply(platform_driver, ['default'], :override => true)
    platform_driver.configure
    puts "done"

    # setup read dispatcher
    puts "Setting up reading joint_dispatcher"
    read_joint_dispatcher = Orocos.name_service.get 'read_joint_dispatcher'
    Orocos.conf.apply(read_joint_dispatcher, ['reading'], :override => true)
    read_joint_dispatcher.configure
    puts "done"

    # setup the commanding dispatcher
    puts "Setting up commanding joint_dispatcher"
    command_joint_dispatcher = Orocos.name_service.get 'command_joint_dispatcher'
    Orocos.conf.apply(command_joint_dispatcher, ['commanding'], :override => true)
    command_joint_dispatcher.configure
    puts "done"

    # setup exoter locomotion_control
    puts "Setting up locomotion_control"
    locomotion_control = Orocos.name_service.get 'locomotion_control'
    Orocos.conf.apply(locomotion_control, ['default'], :override => true)
    locomotion_control.configure
    puts "done"

    # setup exoter ptu_control
    puts "Setting up ptu_control"
    ptu_control = Orocos.name_service.get 'ptu_control'
    Orocos.conf.apply(ptu_control, ['default'], :override => true)
    ptu_control.configure
    puts "done"


    # Localization
    puts "Setting up localization_frontend"
    localization_frontend = Orocos.name_service.get 'localization_frontend'
    Orocos.conf.apply(localization_frontend, ['default', 'bessel50'], :override => true)
    localization_frontend.urdf_file = Bundles.find_file('data/odometry', 'exoter_odometry_model_complete.urdf')
    Bundles.transformer.setup(localization_frontend)
    localization_frontend.configure
    puts "done"

    # ExoTeR Threed Odometry
    puts "Setting up exoter threed_odometry"
    exoter_odometry = Orocos.name_service.get 'exoter_odometry'
    Orocos.conf.apply(exoter_odometry, ['default', 'bessel50'], :override => true)
    exoter_odometry.urdf_file = Bundles.find_file('data/odometry', 'exoter_odometry_model_complete.urdf')
    Bundles.transformer.setup(exoter_odometry)
    exoter_odometry.configure
    puts "done"

    # STIM300 IMU
    puts "Setting up imu_stim300 imu"
    imu_stim300 = TaskContext.get 'imu_stim300'
    Orocos.conf.apply(imu_stim300,  ['default','ExoTer','ESTEC','stim300_5g'], :override => true)
    imu_stim300.configure
    puts "done"

    # Transformer Setup

    puts "Connecting control ports"
    # Connect ports: platform_driver to read_joint_dispatcher
    platform_driver.joints_readings.connect_to read_joint_dispatcher.joints_readings

    # Connect ports: read_joint_dispatcher to locomotion_control
    read_joint_dispatcher.motors_samples.connect_to locomotion_control.joints_readings

    # Connect ports: locomotion_control to command_joint_dispatcher
    locomotion_control.joints_commands.connect_to command_joint_dispatcher.joints_commands

    # Connect ports: command_joint_dispatcher to platform_driver
    command_joint_dispatcher.motors_commands.connect_to platform_driver.joints_commands

    # Connect ports: read_joint_dispatcher to ptu_control
    read_joint_dispatcher.ptu_samples.connect_to ptu_control.ptu_samples

    # Connect ports: ptu_control to command_joint_dispatcher
    ptu_control.ptu_commands_out.connect_to command_joint_dispatcher.ptu_commands
    puts "done"

    # Connect the ports
    puts "Connecting localization ports"
    read_joint_dispatcher.joints_samples.connect_to localization_frontend.joints_samples
    read_joint_dispatcher.ptu_samples.connect_to localization_frontend.ptu_samples
    imu_stim300.orientation_samples_out.connect_to localization_frontend.orientation_samples
    imu_stim300.compensated_sensors_out.connect_to localization_frontend.inertial_samples
    localization_frontend.joints_samples_out.connect_to exoter_odometry.joints_samples
    localization_frontend.orientation_samples_out.connect_to exoter_odometry.orientation_samples
    localization_frontend.weighting_samples_out.connect_to exoter_odometry.weighting_samples, :type => :buffer, :size => 200
    puts "done"

    # Log all ports
    Orocos.log_all_ports

    #Start the tasks
    platform_driver.start
    read_joint_dispatcher.start
    command_joint_dispatcher.start
    locomotion_control.start
    ptu_control.start

    localization_frontend.start
    exoter_odometry.start
    imu_stim300.start

    Readline::readline("Press ENTER to exit\n") do

    end
end
