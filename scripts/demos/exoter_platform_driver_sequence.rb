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
Orocos::Process.run 'exoter_control',
                    'locomotion_demo::Task' => 'demo_sequence' do

    ## Get the task context ##
    platform_driver = Orocos.name_service.get 'platform_driver'
    read_joint_dispatcher = Orocos.name_service.get 'read_joint_dispatcher'
    command_joint_dispatcher = Orocos.name_service.get 'command_joint_dispatcher'
    control = Orocos.name_service.get 'locomotion_control'
    sequence = Orocos.name_service.get 'demo_sequence'

    # Platform driver
    Orocos.conf.apply(platform_driver, ['default'], :override => true)
    platform_driver.configure

    # Joints Dispatcher
    Orocos.conf.apply(read_joint_dispatcher, ['reading'], :override => true)
    read_joint_dispatcher.configure

    # Joints Dispatcher
    Orocos.conf.apply(command_joint_dispatcher, ['commanding'], :override => true)
    command_joint_dispatcher.configure

    # Locomotion control
    Orocos.conf.apply(control, ['default'], :override => true)
    control.configure

    # Sequence of commands
    Orocos.conf.apply(sequence, ['default'], :override => true)
    sequence.configure

    # Log all ports
    Orocos.log_all_ports

    # Connect ports
    platform_driver.joints_readings.connect_to read_joint_dispatcher.joints_readings
    read_joint_dispatcher.motors_samples.connect_to control.joints_readings
    control.joints_commands.connect_to command_joint_dispatcher.joints_commands
    command_joint_dispatcher.motors_commands.connect_to platform_driver.joints_commands
    sequence.motion_command.connect_to control.motion_command

    ## Start the tasks ##
    platform_driver.start
    read_joint_dispatcher.start
    command_joint_dispatcher.start
    control.start
    sequence.start

    ptu_joints_writer = command_joint_dispatcher.ptu_commands.writer
    ptu_joints = ptu_joints_writer.new_sample
    ptu_joints.names = ["MAST_PAN", "MAST_TILT"]
    ptu_joints.elements = [Types::Base::JointState.new(:speed => NaN, :position => 0.00),
            Types::Base::JointState.new(:speed => NaN, :position => 0.00)]
    ptu_joints_writer.write(ptu_joints)


    #reader = platform_driver.motorReadings.reader

    #while true
    #    if p = reader.read_new
    #        puts "#{p}"
    #    end
    #    if v = reader.read_new
    #        puts "#{v}"
    #    end  
    #    sleep 0.1
    #end
    Readline::readline("Press ENTER to exit\n") do
    end
end
