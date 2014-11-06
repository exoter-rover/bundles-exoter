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
Orocos::Process.run 'platform_driver::Task' => 'platform_driver',
            'egress_control::Task' => 'egress_control',
            'joint_dispatcher::Task' => 'joint_dispatcher'do

    ## Get the task context ##
    platform_driver = Orocos.name_service.get 'platform_driver'
    dispatcher = Orocos.name_service.get 'joint_dispatcher'
    egress = Orocos.name_service.get 'egress_control'
    joystick = Orocos.name_service.get 'joystick'

    # Platform driver
    Orocos.conf.apply(platform_driver, ['default'])
    platform_driver.configure

    # Joints Dispatcher
    Orocos.conf.apply(dispatcher, ['default'])
    dispatcher.configure

    # Wheel Walking
    Orocos.conf.apply(egress, ['default'])
    egress.configure

    # Log all ports
    Orocos.log_all_ports

    # Connect ports
    #platform_driver.joints_readings.connect_to dispatcher.driver_readings
    #dispatcher.motors_samples.connect_to egress.joints_readings
    joystick.raw_command.connect_to egress.joystick_commands
    platform_driver.joints_readings.connect_to egress.joint_readings
    egress.joint_commands.connect_to platform_driver.joints_commands

    ## Start the tasks ##
    platform_driver.start
    dispatcher.start
    egress.start

    Readline::readline("Press ENTER to exit\n") do
    end
end
