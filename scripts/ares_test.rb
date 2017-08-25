#!/usr/bin/env ruby
#
# Invoke as follows to use GPS instead of Vicon position data:
# ruby ares_test.rb gps

require 'vizkit'
require 'rock/bundle'
require 'readline'

include Orocos

## Initialize orocos ##
Bundles.initialize

Orocos::Process.run 'exoter_control', 'exoter_groundtruth', 'exoter_slam' do
    ## SETUP ##

    # setup vicon or gps, referred to as pos_component
    if ARGV[0] == "gps"
        puts "Setting up GPS"
        pos_component = Orocos.name_service.get 'gps'
        Orocos.conf.apply(pos_component, ['exoter', 'Netherlands', 'DECOS'], :override => true) #TODO
        pos_component.configure
        puts "done"
    else
        puts "Setting up vicon"
        pos_component = Orocos.name_service.get 'vicon'
        Orocos.conf.apply(pos_component, ['default', 'exoter'], :override => true)
        pos_component.configure
        puts "done"
    end

    # setup waypoint_navigation
    puts "Setting up waypoint_navigation"
    waypoint_navigation = Orocos.name_service.get 'waypoint_navigation'
    Orocos.conf.apply(waypoint_navigation, ['default'], :override => true)
    waypoint_navigation.configure
    puts "done"

    # setup path_planning
    puts "Setting up path_planning: ares_planner"
    ares_planner = Orocos.name_service.get 'ares_planner'
    #path_planning.elevationFile = "../terrainData/prl/prl_elevationMap.txt"
    #path_planning.costFile = "../terrainData/prl/prl_costMapLander.txt"
    #path_planning.globalCostFile = "../terrainData/prl/prl_globalCostMap2.txt"
    #path_planning.riskFile = "../terrainData/prl/prl_riskMap.txt"
    #path_planning.soilsFile = "../terrainData/prl/soilList.txt"
    ares_planner.elevationFile = "/home/exoter/rock_master/planning/orogen/path_planning/terrainData/prl/prl_elevationMap.txt"
    ares_planner.costFile = "/home/exoter/rock_master/planning/orogen/path_planning/terrainData/prl/prl_costMapLander.txt"
    ares_planner.globalCostFile = "/home/exoter/rock_master/planning/orogen/path_planning/terrainData/prl/prl_globalCostMap2.txt"
    ares_planner.riskFile = "/home/exoter/rock_master/planning/orogen/path_planning/terrainData/prl/prl_riskMap.txt"
    ares_planner.soilsFile = "/home/exoter/rock_master/planning/orogen/path_planning/terrainData/prl/soilList.txt"
    ares_planner.configure
    puts "done"

    # setup platform_driver
    puts "Setting up platform_driver"
    platform_driver = Orocos.name_service.get 'platform_driver'
    Orocos.conf.apply(platform_driver, ['default'], :override => true)
    platform_driver.configure
    puts "done"

    # setup read_joint_dispatcher
    puts "Setting up reading joint_dispatcher"
    read_joint_dispatcher = Orocos.name_service.get 'read_joint_dispatcher'
    Orocos.conf.apply(read_joint_dispatcher, ['reading'], :override => true)
    read_joint_dispatcher.configure
    puts "done"

    # setup command_joint_dispatcher
    puts "Setting up commanding joint_dispatcher"
    command_joint_dispatcher = Orocos.name_service.get 'command_joint_dispatcher'
    Orocos.conf.apply(command_joint_dispatcher, ['commanding'], :override => true)
    command_joint_dispatcher.configure
    puts "done"

    # setup ptu_control
    puts "Setting up ptu_control"
    ptu_control = Orocos.name_service.get 'ptu_control'
    Orocos.conf.apply(ptu_control, ['default'], :override => true)
    ptu_control.configure
    puts "done"

    # setup locomotion_control
    puts "Setting up locomotion_control"
    locomotion_control = Orocos.name_service.get 'locomotion_control'
    Orocos.conf.apply(locomotion_control, ['default'], :override => true)
    locomotion_control.configure
    puts "done"

    # setup wheel_walking_control
    puts "Setting up wheel_walking_control"
    wheel_walking_control = Orocos.name_service.get 'wheel_walking_control'
    Orocos.conf.apply(wheel_walking_control, ['default'], :override => true)
    wheel_walking_control.configure
    puts "done"

    # setup locomotion_switcher
    puts "Setting up locomotion_switcher"
    locomotion_switcher = Orocos.name_service.get 'locomotion_switcher'
    locomotion_switcher.configure
    puts "done"

    # setup joystick
    puts "Setting up joystick"
    joystick = Orocos.name_service.get 'joystick'
    Orocos.conf.apply(joystick, ['default', 'logitech_gamepad'], :override => true)
    joystick.configure
    puts "done"

    # setup motion_translator
    puts "Setting up motion_translator"
    motion_translator = Orocos.name_service.get 'motion_translator'
    Orocos.conf.apply(motion_translator, ['default'], :override => true)
    motion_translator.configure
    puts "done"


    ## PORT CONNECTIONS ##
    # Read: Output.connect_to Input

    puts "Connecting ports"
    #Orocos.log_all_ports

    pos_component.pose_samples.connect_to                 ares_planner.pose
    pos_component.pose_samples.connect_to                 waypoint_navigation.pose

    ares_planner.trajectory.connect_to                    waypoint_navigation.trajectory
    ares_planner.locomotionMode.connect_to                locomotion_switcher.locomotionMode

    waypoint_navigation.motion_command.connect_to         locomotion_switcher.motion_command

    platform_driver.joints_readings.connect_to            read_joint_dispatcher.joints_readings

    read_joint_dispatcher.motors_samples.connect_to       locomotion_control.joints_readings
    read_joint_dispatcher.motors_samples.connect_to       locomotion_switcher.motors_readings
    read_joint_dispatcher.joints_samples.connect_to       wheel_walking_control.joint_readings
    read_joint_dispatcher.ptu_samples.connect_to          ptu_control.ptu_samples

    command_joint_dispatcher.motors_commands.connect_to   platform_driver.joints_commands

    ptu_control.ptu_commands_out.connect_to               command_joint_dispatcher.ptu_commands

    locomotion_control.joints_commands.connect_to         locomotion_switcher.lc_joints_commands

    wheel_walking_control.joint_commands.connect_to       locomotion_switcher.ww_joints_commands

    locomotion_switcher.joints_commands.connect_to        command_joint_dispatcher.joints_commands
    locomotion_switcher.ww_joystick_command.connect_to    wheel_walking_control.joystick_commands
    locomotion_switcher.kill_switch.connect_to            wheel_walking_control.kill_switch
    locomotion_switcher.resetDepJoints.connect_to         wheel_walking_control.resetDepJoints
    locomotion_switcher.lc_motion_command.connect_to      locomotion_control.motion_command

    joystick.raw_command.connect_to                       motion_translator.raw_command

    motion_translator.ptu_command.connect_to              ptu_control.ptu_joints_commands

    puts "done"

    ## START TASKS ##
    pos_component.start
    ares_planner.start
    waypoint_navigation.start
    platform_driver.start
    read_joint_dispatcher.start
    command_joint_dispatcher.start
    ptu_control.start
    locomotion_control.start
    wheel_walking_control.start
    locomotion_switcher.start
    joystick.start
    motion_translator.start


    Readline::readline("Press ENTER to exit\n")

end
