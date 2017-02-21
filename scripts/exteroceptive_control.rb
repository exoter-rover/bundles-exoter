#!/usr/bin/env ruby

require 'vizkit'
require 'rock/bundle'
require 'readline'

include Orocos

options = {}
options[:reference] = "none"
options[:logging] = "nominal"
options[:scripted] = "no"
scripting = 0

OptionParser.new do |opt|
    opt.banner = <<-EOD
    usage: exoter_start_all.rb [options] 
    EOD

    opt.on '-r or --reference=none/vicon/gnss', String, 'set the type of reference system available' do |reference|
        options[:reference] = reference
    end

    opt.on '-l or --logging=none/minimum/nominal/all', String, 'set the type of log files you want. Nominal as default' do |logging|
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

Orocos::Process.run 'exoter_control', 'exoter_groundtruth', 'exoter_exteroceptive', 'exoter_proprioceptive' do

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

    if options[:reference].casecmp("vicon").zero?
        puts "[INFO] Vicon Ground Truth system available"
        # setup exoter ptu_control
        puts "Setting up vicon"
        vicon = Orocos.name_service.get 'vicon'
        Orocos.conf.apply(vicon, ['default', 'exoter'], :override => true)
        vicon.configure
        puts "done"
    else
        puts "[INFO] No Ground Truth system available"
    end

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

    # setup tof mesa
    puts "Setting up tofcamera_mesasr"
    tof = Orocos.name_service.get 'camera_tof'
    Orocos.conf.apply(tof, ['default'], :override => true)
    tof.configure
    puts "done"

    # setup camera_firewire
    puts "Setting up camera_firewire"
    camera_firewire = Orocos.name_service.get 'camera_firewire'
    Orocos.conf.apply(camera_firewire, ['default'], :override => true)
    camera_firewire.configure
    puts "done"

    # setup camera_bb2
    puts "Setting up camera_bb2"
    camera_bb2 = TaskContext.get 'camera_bb2'
    Orocos.conf.apply(camera_bb2, ['default'], :override => true)
    camera_bb2.configure
    puts "done"

    # setup stereo
    puts "Setting up stereo"
    stereo = TaskContext.get 'stereo_loc_cam_front'
    Orocos.conf.apply(stereo, ['exoter_bb2'], :override => true)
    stereo.configure
    puts "done"

    # setup imu_stim300
    puts "Setting up imu_stim300"
    imu = TaskContext.get 'imu_stim300'
    Orocos.conf.apply(imu, ['default', 'exoter','ESTEC','stim300_5g'], :override => true)
    imu.configure
    puts "done"

    # Log all ports
    Orocos.log_all_ports

    puts "Connecting ports"
    # Connect ports: platform_driver to read_joint_dispatcher
    platform_driver.joints_readings.connect_to read_joint_dispatcher.joints_readings

    # Connect ports: read_joint_dispatcher to locomotion_control
    read_joint_dispatcher.motors_samples.connect_to locomotion_control.joints_readings

    # Connect ports: joystick to motion_translator
    joystick.raw_command.connect_to motion_translator.raw_command

    # Connect ports: motion_translator to locomotion_control
    motion_translator.motion_command.connect_to locomotion_control.motion_command

    # Connect ports: locomotion_control to command_joint_dispatcher
    locomotion_control.joints_commands.connect_to command_joint_dispatcher.joints_commands

    # Connect ports: command_joint_dispatcher to platform_driver
    command_joint_dispatcher.motors_commands.connect_to platform_driver.joints_commands

    # Connect ports: read_joint_dispatcher to ptu_control
    read_joint_dispatcher.ptu_samples.connect_to ptu_control.ptu_samples

    # Connect ports: ptu_control to command_joint_dispatcher
    ptu_control.ptu_commands_out.connect_to command_joint_dispatcher.ptu_commands

    # Connect ports: camera_firewire to stereo
    camera_firewire.frame.connect_to camera_bb2.frame_in
    camera_bb2.left_frame.connect_to stereo.left_frame
    camera_bb2.right_frame.connect_to stereo.right_frame

    puts "done"

    # Start the tasks
    platform_driver.start
    read_joint_dispatcher.start
    command_joint_dispatcher.start
    locomotion_control.start
    ptu_control.start
    motion_translator.start
    joystick.start
    if options[:reference].casecmp("vicon").zero?
        vicon.start
    end
    camera_firewire.start
    camera_bb2.start
    stereo.start
    tof.start
    imu.start

    if scripting == 1
	while 1 do
		sleep 10
	end
    
    else
    	Readline::readline("Press ENTER to exit\n") do
    	end
    end


end

