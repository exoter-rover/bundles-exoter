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

Orocos::Process.run 'exoter_control', 'exoter_groundtruth', 'exoter_slam', 'exoter_proprioceptive', 'exoter_exteroceptive', 'exoter_localization' do
    ## SETUP ##

    # setup vicon or gps, referred to as pos_component
    if ARGV[0] == "gps"
        puts "Setting up GPS"
        gps = Orocos.name_service.get 'gnss_trimble'
        Orocos.conf.apply(gps, ['exoter', 'Netherlands', 'DECOS'], :override => true)
        gps.configure
        puts "done"
        puts "Setting up GPS_Heading"
        gps_heading = Orocos.name_service.get 'gps_heading'
        Orocos.conf.apply(gps_heading, ['default'], :override => true)
        gps_heading.configure
        puts "done"
        use_gps = true
        use_visio = false
    elsif ARGV[0] == "visio"
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

        # setup visual odometry
        puts "Setting up visual odometry"
        visual_odometry = Orocos.name_service.get 'viso2'
        Orocos.conf.apply(visual_odometry, ['bumblebee'], :override => true)
        Bundles.transformer.setup(visual_odometry)
        visual_odometry.configure

        #viso2_with_imu = TaskContext.get 'viso2_with_imu'
        #Orocos.conf.apply(viso2_with_imu, ['hdpr_autonomy'], :override => true)
        #Bundles.transformer.setup(viso2_with_imu)
        #viso2_with_imu.configure
        puts "done"
        use_gps = false
        use_visio = true
    else
        puts "Setting up vicon"
        vicon = Orocos.name_service.get 'vicon'
        Orocos.conf.apply(vicon, ['default', 'exoter'], :override => true)
        vicon.configure
        puts "done"
        use_gps = false
        use_visio = false
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

    if use_gps
    #if true
        # DECOS
        ares_planner.elevationFile = "/home/exoter/rock_master/planning/orogen/path_planning/terrainData/decos/decos_elevationMap.txt"
        ares_planner.costFile =      "/home/exoter/rock_master/planning/orogen/path_planning/terrainData/decos/decos_localCostMap2.txt"
        ares_planner.globalCostFile ="/home/exoter/rock_master/planning/orogen/path_planning/terrainData/decos/decos_globalCostMap2.txt"
        ares_planner.riskFile =      "/home/exoter/rock_master/planning/orogen/path_planning/terrainData/decos/decos_localRiskMap.txt"
        ares_planner.soilsFile =     "/home/exoter/rock_master/planning/orogen/path_planning/terrainData/decos/soilList.txt"
        ares_planner.local_res = 0.0625
        ares_planner.crop_local = true
    else
        # PRL
        ares_planner.elevationFile = "/home/exoter/rock_master/planning/orogen/path_planning/terrainData/prl/prl_elevationMap.txt"
        ares_planner.costFile =      "/home/exoter/rock_master/planning/orogen/path_planning/terrainData/prl/prl_costMapLander.txt"
        ares_planner.globalCostFile ="/home/exoter/rock_master/planning/orogen/path_planning/terrainData/prl/prl_globalCostMap.txt"
        ares_planner.riskFile =      "/home/exoter/rock_master/planning/orogen/path_planning/terrainData/prl/prl_riskMap.txt"
        ares_planner.soilsFile =     "/home/exoter/rock_master/planning/orogen/path_planning/terrainData/prl/soilList.txt"
        ares_planner.local_res = 0.05
        ares_planner.crop_local = false
    end
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

    # setup imu
    puts "Setting up imu_stim300"
    imu = Orocos.name_service.get 'imu_stim300'
    Orocos.conf.apply(imu, ['default', 'exoter', 'ESTEC', 'stim300_5g'], :override => true)
    imu.configure
    puts "done"

    # setup command_arbitrer
    puts "Setting up command arbiter"
    arbiter = Orocos.name_service.get 'command_arbiter'
    Orocos.conf.apply(arbiter, ['default'], :override => true)
    arbiter.configure
    puts "done"

    # setup goal generator
    #puts "Setting up goal_generator"
    #goal = Orocos.name_service.get 'goal_set'
    #Orocos.conf.apply(goal, ['default'], :override => true)
    #goal.configure
    #puts "done"


    ## LOGGERS ##
    Orocos.log_all_configuration

    logger_groundtruth = Orocos.name_service.get 'exoter_groundtruth_Logger'
    logger_groundtruth.file = "groundtruth.log"
    if use_gps
        logger_groundtruth.log(gps_heading.pose_samples_out)
    elsif use_visio
# PUT HERE THE LOGGER!!!!!
    else
        logger_groundtruth.log(vicon.pose_samples)
    end

    logger_slam = Orocos.name_service.get 'exoter_slam_Logger'
    logger_slam.file = "slam.log"
    logger_slam.log(ares_planner.trajectory)
    logger_slam.log(ares_planner.locomotionMode)
    logger_slam.log(ares_planner.local_map)
    logger_slam.log(ares_planner.global_map)

    logger_control = Orocos.name_service.get 'exoter_control_Logger'
    logger_control.file = "control.log"
    logger_control.log(platform_driver.joints_readings)
    logger_control.log(waypoint_navigation.motion_command)

    logger_proprioceptive = Orocos.name_service.get 'exoter_proprioceptive_Logger'
    logger_proprioceptive.file = "proprioceptive.log"
    logger_proprioceptive.log(imu.compensated_sensors_out)
    logger_proprioceptive.log(imu.inertial_sensors_out)
    logger_proprioceptive.log(imu.orientation_samples_out)


    ## PORT CONNECTIONS ##
    # Read: Output.connect_to Input

    puts "Connecting ports"

    joystick.raw_command.connect_to                       motion_translator.raw_command
    motion_translator.ptu_command.connect_to              ptu_control.ptu_joints_commands
    ptu_control.ptu_commands_out.connect_to               command_joint_dispatcher.ptu_commands

    joystick.raw_command.connect_to                       arbiter.raw_command
    motion_translator.motion_command.connect_to           arbiter.joystick_motion_command
    waypoint_navigation.motion_command.connect_to         arbiter.follower_motion_command
    waypoint_navigation.current_segment.connect_to        ares_planner.current_segment
    arbiter.motion_command.connect_to                     locomotion_switcher.motion_command
    arbiter.locomotion_mode.connect_to                    locomotion_switcher.locomotionMode_override

    if use_gps
        gps.pose_samples.connect_to                       gps_heading.gps_pose_samples
        imu.orientation_samples_out.connect_to            gps_heading.imu_pose_samples
        arbiter.motion_command.connect_to                 gps_heading.motion_command
        gps.raw_data.connect_to                           gps_heading.gps_raw_data
        gps_heading.pose_samples_out.connect_to           waypoint_navigation.pose
        gps_heading.pose_samples_out.connect_to           ares_planner.pose
    elsif use_visio
        camera_firewire.frame.connect_to                  camera_bb2.frame_in
        camera_bb2.left_frame.connect_to                  stereo.left_frame
        camera_bb2.right_frame.connect_to                 stereo.right_frame
    else
        vicon.pose_samples.connect_to                     waypoint_navigation.pose
        vicon.pose_samples.connect_to                     ares_planner.pose
    end

    ares_planner.trajectory.connect_to                    waypoint_navigation.trajectory
    ares_planner.locomotionMode.connect_to                locomotion_switcher.locomotionMode
   # waypoint_navigation.motion_command.connect_to         locomotion_switcher.motion_command # removed for using the command arbiter

    locomotion_switcher.joints_commands.connect_to        command_joint_dispatcher.joints_commands
    locomotion_switcher.kill_switch.connect_to            wheel_walking_control.kill_switch
    locomotion_switcher.resetDepJoints.connect_to         wheel_walking_control.resetDepJoints
    locomotion_switcher.lc_motion_command.connect_to      locomotion_control.motion_command

    locomotion_control.joints_commands.connect_to         locomotion_switcher.lc_joints_commands
    wheel_walking_control.joint_commands.connect_to       locomotion_switcher.ww_joints_commands

    command_joint_dispatcher.motors_commands.connect_to   platform_driver.joints_commands

    platform_driver.joints_readings.connect_to            read_joint_dispatcher.joints_readings

    read_joint_dispatcher.motors_samples.connect_to       locomotion_control.joints_readings
    read_joint_dispatcher.motors_samples.connect_to       locomotion_switcher.motors_readings
    read_joint_dispatcher.joints_samples.connect_to       wheel_walking_control.joint_readings
    read_joint_dispatcher.ptu_samples.connect_to          ptu_control.ptu_samples

    puts "done"

    ## START TASKS ##
    if use_gps
        gps.start
        gps_heading.start
    elsif use_visio
        camera_firewire.start
        camera_bb2.start
        stereo.start
    else
        vicon.start
    end
    ares_planner.start
    platform_driver.start
    read_joint_dispatcher.start
    command_joint_dispatcher.start
    ptu_control.start
    locomotion_control.start
    wheel_walking_control.start
    joystick.start
    arbiter.start
    motion_translator.start
    locomotion_switcher.start
    imu.start

    if use_gps
        # Race condition with internal gps_heading states. This check is here to only trigger the 
        # trajectoryGen when the pose has been properly initialised. Otherwise the trajectory is set wrong.
        puts "Move rover forward to initialise the gps_heading component"
        while gps_heading.ready == false
            sleep 1
        end
        puts "GPS heading calibration done"
    end

    # Trigger the trojectory generation, waypoint_navigation must be running at this point
    waypoint_navigation.start

    # Start loggers
    logger_groundtruth.start
    logger_slam.start
    logger_control.start
    logger_proprioceptive.start

    Readline::readline("Press ENTER to send goal pose to planner\n")

    #goal.start
    goal_writer = ares_planner.goalWaypoint.writer
#    goal = goal_writer.new_sample
    goal = Types::Base::Waypoint.new()
    if use_gps
        goal.position[0] = 85.00
        goal.position[1] = 80.00
    else
        goal.position[0] = 6.00
        goal.position[1] = 3.00
    end
    goal.position[2] = 0.00
    goal.heading = 0.00
    goal_writer.write(goal)

    Readline::readline("Press ENTER to exit\n")

end
