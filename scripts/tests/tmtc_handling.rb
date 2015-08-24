#!/usr/bin/env ruby

require 'vizkit'
require 'rock/bundle'
require 'readline'

include Orocos

options = {}
options[:camera] = "no"
options[:logging] = "nominal"

OptionParser.new do |opt|
    opt.banner = <<-EOD
    usage: tmtc_handling.rb [options] 
    EOD

    opt.on '-c or --camera=no/yes', String, 'set the camera on or off' do |camera|
        options[:camera] = camera
    end

    opt.on '-l or --logging=none/minimum/nominal/all', String, 'set the type of log files you want. Nominal as default' do |logging|
        options[:logging] = logging
    end

    opt.on '--help', 'this help message' do
        puts opt
       exit 0
    end
end.parse!(ARGV)

## Initialize orocos ##
Bundles.initialize

## Transformation for the transformer
Bundles.transformer.load_conf(Bundles.find_file('config', 'transforms_scripts.rb'))

## Execute the task 'platform_driver::Task' ##
Orocos::Process.run 'exoter_control', 'exoter_proprioceptive', 'exoter_groundtruth', 'exoter_tmtchandling' do

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

    # setup exoter ptu_control
    puts "Setting up ptu_control"
    ptu_control = Orocos.name_service.get 'ptu_control'
    Orocos.conf.apply(ptu_control, ['default'], :override => true)
    ptu_control.configure
    puts "done"
    
    if options[:camera].casecmp("yes").zero?
        puts "[INFO] Camera ON"
        # setup exoter camera_firewire
        puts "Setting up camera_firewire"
        camera_firewire = Orocos.name_service.get 'camera_firewire'
        Orocos.conf.apply(camera_firewire, ['default'], :override => true)
        camera_firewire.configure
        puts "done"
    else
        puts "[INFO] Camera OFF"
    end

    # setup exoter wheel_walking_control
    puts "Setting up locomotion_control"
    locomotion_control = Orocos.name_service.get 'locomotion_control'
    Orocos.conf.apply(locomotion_control, ['default'], :override => true)
    locomotion_control.configure
    puts "done"

    # setup art
    puts "Setting up vicon"
    vicon = Orocos.name_service.get 'vicon'
    Orocos.conf.apply(vicon, ['default', 'exoter'], :override => true)
    vicon.configure
    puts "done"

    # setup exoter_odometry
    puts "Setting up imu_stim300"
    imu_stim300 = Orocos.name_service.get 'imu_stim300'
    Orocos.conf.apply(imu_stim300, ['default', 'exoter','ESTEC','stim300_5g'], :override => true)
    imu_stim300.configure
    puts "done"
    
    # setup telemetry_telecommand
    puts "Setting up telemetry_telecommand"
    telemetry_telecommand = Orocos.name_service.get 'telemetry_telecommand'
    Orocos.conf.apply(telemetry_telecommand, ['default'], :override => true)
    telemetry_telecommand.configure
    puts "done"

    # Log all ports
    Orocos.log_all_ports

    # Connect ports
    puts "Connecting ports"

    # Connect ports: platform_driver to read_joint_dispatcher
    platform_driver.joints_readings.connect_to read_joint_dispatcher.joints_readings

    # Connect ports: read_joint_dispatcher to wheel_walking_control
    read_joint_dispatcher.joints_samples.connect_to locomotion_control.joints_readings

    # Connect ports: wheel_walking_control to command_joint_dispatcher
    locomotion_control.joints_commands.connect_to command_joint_dispatcher.joints_commands

    # Connect ports: command_joint_dispatcher to platform_driver
    command_joint_dispatcher.motors_commands.connect_to platform_driver.joints_commands

    # Connect ports: read_joint_dispatcher to ptu_control
    read_joint_dispatcher.ptu_samples.connect_to ptu_control.ptu_samples

    # Connect ports: ptu_control to command_joint_dispatcher
    ptu_control.ptu_commands_out.connect_to command_joint_dispatcher.ptu_commands

    # Connect ports: ptu_control to command_joint_dispatcher
    telemetry_telecommand.locomotion_command.connect_to locomotion_control.motion_command

    puts "done"


    # Start the tasks
    platform_driver.start
    read_joint_dispatcher.start
    command_joint_dispatcher.start
    locomotion_control.start
    ptu_control.start
    #imu_stim300.start
    #vicon.start
    telemetry_telecommand.start
    if options[:camera].casecmp("yes").zero?
        camera_firewire.start
    end

    Readline::readline("Press ENTER to exit\n") do
    end
end
