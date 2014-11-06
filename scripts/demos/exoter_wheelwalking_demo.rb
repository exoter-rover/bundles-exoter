#!/usr/bin/env ruby

require 'vizkit'
require 'rock/bundle'
require 'readline'

include Orocos

## Initialize orocos ##
Bundles.initialize

## Transformation for the transformer
Bundles.transformer.load_conf(Bundles.find_file('config', 'transforms_scripts.rb'))

## Execute the task 'platform_driver::Task' ##
Orocos::Process.run 'exoter_control', 'wheel_walking_test::Task' => 'wheel_walking_test' do

    ## Get the task context ##
    platform_driver = Orocos.name_service.get 'platform_driver'
    read_joint_dispatcher = Orocos.name_service.get 'read_joint_dispatcher'
    command_joint_dispatcher = Orocos.name_service.get 'command_joint_dispatcher'
    wheel_walking = Orocos.name_service.get 'wheel_walking_test'

    # Platform driver
    Orocos.conf.apply(platform_driver, ['default'], :override => true)
    platform_driver.configure

    # Joints Dispatcher
    Orocos.conf.apply(read_joint_dispatcher, ['reading'], :override => true)
    read_joint_dispatcher.configure

    # setup the commanding dispatcher
    Orocos.conf.apply(command_joint_dispatcher, ['commanding'], :override => true)
    command_joint_dispatcher.configure

    # Wheel Walking
    Orocos.conf.apply(wheel_walking, ['default'], :override => true)
    wheel_walking.configure

    # Log all ports
    Orocos.log_all_ports

    # Connect ports
    platform_driver.joints_readings.connect_to read_joint_dispatcher.joints_readings
    read_joint_dispatcher.motors_samples.connect_to wheel_walking.joints_readings
    wheel_walking.joints_commands.connect_to command_joint_dispatcher.joints_commands
    command_joint_dispatcher.motors_commands.connect_to platform_driver.joints_commands

    ## Start the tasks ##
    platform_driver.start
    read_joint_dispatcher.start
    command_joint_dispatcher.start
    wheel_walking.start

    Readline::readline("Press ENTER to exit\n") do
    end
end
