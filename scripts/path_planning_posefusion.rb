#!/usr/bin/env ruby

require 'vizkit'
require 'rock/bundle'
require 'readline'

include Orocos

## Initialize orocos ##
Bundles.initialize

Orocos::Process.run 'exoter_control', 'exoter_groundtruth', 'exoter_proprioceptive', 'exoter_slam' do

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

    # setup vicon
    puts "Setting up vicon"
    vicon = Orocos.name_service.get 'vicon'
    Orocos.conf.apply(vicon, ['default', 'exoter'], :override => true)
    vicon.configure
    puts "done"
    
    # setup imu_stim300 
    puts "Setting up imu_stim300"
    imu_stim300 = Orocos.name_service.get 'imu_stim300'
    Orocos.conf.apply(imu_stim300, ['default', 'exoter','ESTEC','stim300_5g'], :override => true)
    imu_stim300.configure
    puts "done"

    # setup joystick
    puts "Setting up joystick"
    joystick = Orocos.name_service.get 'joystick'
    Orocos.conf.apply(joystick, ['default'], :override => true)
    begin
        joystick.configure
    rescue
        abort("Cannot configure the joystick, is the dongle connected?")
    end
    puts "done"

    # setup motion_translator
    puts "Setting up motion_translator"
    motion_translator = Orocos.name_service.get 'motion_translator'
    Orocos.conf.apply(motion_translator, ['default'], :override => true)
    motion_translator.configure
    puts "done"

    # setup waypoint_navigation 
    puts "Setting up waypoint_navigation"
    waypoint_navigation = Orocos.name_service.get 'waypoint_navigation'
    Orocos.conf.apply(waypoint_navigation, ['default'], :override => true)
    #waypoint_navigation.apply_conf_file("config/orogen/waypoint_navigation::Task.yml",["exoter"])
    waypoint_navigation.configure
    puts "done"

    # setup command arbiter
    puts "Setting up command arbiter"
    command_arbiter = Orocos.name_service.get 'command_arbiter'
    Orocos.conf.apply(command_arbiter, ['default'], :override => true)
    command_arbiter.configure
    puts "done"


    # setup motion_planning_libraries
    puts "Setting up the motion_planning_libraries"
    planner = Orocos.name_service.get 'path_planner' 
    planner.traversability_map_id = "trav_map"
    planner.planning_time_sec = 20.0
    planner.config do |p|
        p.mPlanningLibType = :LIB_SBPL
        p.mEnvType = :ENV_XY
        p.mPlanner = :ANYTIME_DSTAR
        p.mFootprintLengthMinMax.first = 0.70
        p.mFootprintLengthMinMax.second = 0.70
        p.mFootprintWidthMinMax.first  = 0.70
        p.mFootprintWidthMinMax.second = 0.70
        p.mMaxAllowedSampleDist = -1
        p.mNumFootprintClasses  = 10
        p.mTimeToAdaptFootprint = 10
        p.mAdaptFootprintPenalty = 2
        p.mSearchUntilFirstSolution = false
        p.mReplanDuringEachUpdate = true
        p.mNumIntermediatePoints  = 8
        p.mNumPrimPartition = 2

        # EO2
        p.mSpeeds.mSpeedForward         = 0.05
        p.mSpeeds.mSpeedBackward        = 0.05
        p.mSpeeds.mSpeedLateral         = 0.0
        p.mSpeeds.mSpeedTurn            = 0.083
        p.mSpeeds.mSpeedPointTurn       = 0.083
        p.mSpeeds.mMultiplierForward    = 1
        p.mSpeeds.mMultiplierBackward   = 500
        p.mSpeeds.mMultiplierLateral    = 500
        p.mSpeeds.mMultiplierTurn       = 5 
        p.mSpeeds.mMultiplierPointTurn  = 2

        # SBPL specific configuration
        p.mSBPLEnvFile = ""
        p.mSBPLMotionPrimitivesFile = ""
        p.mSBPLForwardSearch = false # ADPlanner throws 'g-values are non-decreasing' if true
    end
    planner.configure
    puts "done"

    # setup the traversability explorer
    puts "Setting up the traversability explorer"
    trav = Orocos.name_service.get 'traversability'
    trav.traversability_map_id = "trav_map"
    trav.traversability_map_scalex =  0.03
    trav.traversability_map_scaley =  0.03
    trav.filename = "/home/exoter/rock/planning/orogen/traversability_explorer/data/costMap2016.txt"
    trav.robot_fov_a = 2.5
    trav.robot_fov_b = 3.5
    trav.robot_fov_l = 3.0
    trav.configure
    puts "done"

    # setup goal generator 
    puts "Setting up goal generator"
    goal = Orocos.name_service.get 'goal_set'
    Orocos.conf.apply(goal, ['default','prl'], :override => true)
    goal.goal_index = 6
    goal.configure
    puts "done"

    # setup trajectory resampling 
    puts "Setting up trajectory resampling"
    refiner = Orocos.name_service.get 'trajectory_refiner'
    refiner.configure
    puts "done"

    # setup pose estimation 
    puts "Setting up pose estimation"
    pose_est = Orocos.name_service.get 'pose_est'
    pose_est.configure
    puts "done"
    # Log all ports
    Orocos.log_all_ports

    puts "Connecting ports"
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

    # Connect ports: joystick to motion_translator
    joystick.raw_command.connect_to motion_translator.raw_command

    # Connect ports: joystick to command_arbiter
    joystick.raw_command.connect_to command_arbiter.raw_command

    # Connect ports: joystick to goal
    joystick.raw_command.connect_to goal.raw_command

    # Connect ports: motion_translator to locomotion_control
    motion_translator.motion_command.connect_to command_arbiter.joystick_motion_command

    # Connect ports: waypoint_navigation to command_arbiter 
    waypoint_navigation.motion_command.connect_to command_arbiter.follower_motion_command

    # Connect ports: command_arbiter to locomotion_control
    command_arbiter.motion_command.connect_to locomotion_control.motion_command

    # Connect ports: traversability explorer to	planner
    trav.traversability_map.connect_to	planner.traversability_map

    # Connect ports: planner 		to	trajectory refiner
    planner.waypoints.connect_to                refiner.waypoints_in

    # Connect ports: trajectory refiner to 	waypoint_navigation
    refiner.waypoints_out.connect_to            waypoint_navigation.trajectory

    # CHANGELOG: Vicon connected to pose fusion component only
    # Connect ports: Vicon 		to 	simple pose / pose_est
    vicon.pose_samples.connect_to               pose_est.gps_pose
    imu_stim300.orientation_samples_out.connect_to pose_est.imu_pose

    # Connect ports: pose_est 		to 	traversability explorer
    pose_est.pose.connect_to                    trav.robot_pose        

    # Connect ports: pose_est 		to 	path planner
    pose_est.pose.connect_to                    planner.start_pose_samples

    # Connect ports: pose_est           to      waypoint_navigation
    pose_est.pose.connect_to                    waypoint_navigation.pose

    # Connect ports: Goal Generator	to 	path planner
    goal.goal_pose.connect_to                   planner.goal_pose_samples

    # Connect ports: Goal Generator	to 	trajectory refiner
    goal.goal_pose.connect_to                   refiner.goal_pose

    puts "done"

    # Start the tasks
    platform_driver.start
    read_joint_dispatcher.start
    command_joint_dispatcher.start
    locomotion_control.start
    ptu_control.start
    vicon.start
    imu_stim300.start
    joystick.start
    waypoint_navigation.start
    command_arbiter.start
    refiner.start
    planner.start
    motion_translator.start
    trav.start
    goal.start
    pose_est.start

   #Readline::readline("Press ENTER to generate the trajectory.")
   #goal.trigger

    Readline::readline("Press ENTER to exit\n") do
    end

end
