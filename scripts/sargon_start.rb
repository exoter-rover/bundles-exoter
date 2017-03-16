#!/usr/bin/env ruby

#require 'vizkit'
require 'rock/bundle'
require 'readline'

include Orocos

options = {}
options[:joystick] = "no"
options[:camera] = "no"
options[:logging] = "none"
options[:scripted] = "no"
scripting = 0

OptionParser.new do |opt|
    opt.banner = <<-EOD
    usage: sargon_start.rb [options] 
    EOD

    opt.on '-j or --joystick=yes/no', String, 'specify if a joystick is present and shall be used' do |joystick|
        options[:joystick] = joystick
    end

    opt.on '-c or --camera=yes/no', String, 'set the camera on or off' do |camera|
        options[:camera] = camera
    end

    opt.on '-l or --logging=none/all', String, 'set the log files you want. None as default' do |logging|
        options[:logging] = logging
    end

    opt.on '-s', String, 'Specifies that the file is launched from within a script and enter termination should be ignored' do 
        scripting = 1
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

Orocos::Process.run 'sargon_setup' do

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

    if options[:joystick].casecmp("yes").zero?
        # setup motion_translator
        puts "Setting up motion_translator"
        motion_translator = Orocos.name_service.get 'motion_translator'
        Orocos.conf.apply(motion_translator, ['default'], :override => true)
        motion_translator.configure
        puts "done"

        # setup joystick
        puts "Setting up joystick"
        joystick = Orocos.name_service.get 'joystick'
        Orocos.conf.apply(joystick, ['default'], :override => true)
        joystick.configure
        puts "done"
    else
        puts "No joystick"
    end

    # Localization
    puts "Setting up localization_frontend"
    localization_frontend = Orocos.name_service.get 'localization_frontend'
    Orocos.conf.apply(localization_frontend, ['default', 'hamming1hzsampling12hz'], :override => true)
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

    # setup imu_stim300 
    puts "Setting up imu_stim300"
    imu_stim300 = Orocos.name_service.get 'imu_stim300'
    Orocos.conf.apply(imu_stim300, ['default', 'exoter','ESTEC','stim300_5g'], :override => true)
    imu_stim300.configure
    puts "done"

    # setup camera (optional)
    if options[:camera].casecmp("yes").zero?
        puts "Setting up camera_firewire"
        camera_firewire = Orocos.name_service.get 'camera_firewire_front'
        Orocos.conf.apply(camera_firewire, ['exoter_bb2'], :override => true)
        camera_firewire.configure
        puts "done"
        puts "Setting up camera_bb2"
        camera_bb2 = Orocos.name_service.get 'camera_bb2_front'
        Orocos.conf.apply(camera_bb2, ['exoter_bb2'], :override => true)
        camera_bb2.configure
        puts "done"
    else
        puts "No cameras"
    end

    # Log all ports
    if options[:logging].casecmp("all").zero?
        puts "Logging all ports"
        Orocos.log_all
    else
        puts "NO Logging"
    end

    puts "Connecting ports"
    # Connect ports: platform_driver to read_joint_dispatcher
    platform_driver.joints_readings.connect_to read_joint_dispatcher.joints_readings

    # Connect ports: read_joint_dispatcher to locomotion_control
    read_joint_dispatcher.motors_samples.connect_to locomotion_control.joints_readings

    if options[:joystick].casecmp("yes").zero?
        # Connect ports: joystick to motion_translator
        joystick.raw_command.connect_to motion_translator.raw_command

        # Connect ports: motion_translator to locomotion_control
        motion_translator.motion_command.connect_to locomotion_control.motion_command
    end

    # Connect ports: locomotion_control to command_joint_dispatcher
    locomotion_control.joints_commands.connect_to command_joint_dispatcher.joints_commands

    # Connect ports: command_joint_dispatcher to platform_driver
    command_joint_dispatcher.motors_commands.connect_to platform_driver.joints_commands

    # Connect camera ports
    if options[:camera].casecmp("yes").zero?
        camera_firewire.frame.connect_to camera_bb2.frame_in
    end
    # Connect ports: ptu_control to command_joint_dispatcher
    ptu_control.ptu_commands_out.connect_to command_joint_dispatcher.ptu_commands

    puts "Connecting localization ports"
    read_joint_dispatcher.joints_samples.connect_to localization_frontend.joints_samples, :type => :buffer, :size => 10
    imu_stim300.orientation_samples_out.connect_to localization_frontend.orientation_samples, :type => :buffer, :size => 10
    imu_stim300.compensated_sensors_out.connect_to localization_frontend.inertial_samples, :type => :buffer, :size => 10
    localization_frontend.joints_samples_out.connect_to exoter_odometry.joints_samples, :type => :buffer, :size => 10
    localization_frontend.orientation_samples_out.connect_to exoter_odometry.orientation_samples, :type => :buffer, :size => 10
    localization_frontend.weighting_samples_out.connect_to exoter_odometry.weighting_samples, :type => :buffer, :size => 10
    puts "done"

    # Start the tasks
    platform_driver.start
    read_joint_dispatcher.start
    command_joint_dispatcher.start
    locomotion_control.start
    ptu_control.start
    if options[:joystick].casecmp("yes").zero?
        motion_translator.start
        joystick.start
    end
    localization_frontend.start
    exoter_odometry.start
    imu_stim300.start

    if options[:camera].casecmp("yes").zero?
        camera_bb2.start
        camera_firewire.start
    end

    if scripting == 1
        while true do
            sleep 10
        end
    else
        Readline::readline("Press ENTER to exit\n") do
        end
    end
end

