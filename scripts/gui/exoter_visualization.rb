#! /usr/bin/env ruby

require 'orocos'
require 'rock/bundle'
require 'orocos/async'
require 'vizkit'
require 'optparse'

hostname = nil
logfile = nil

options = OptionParser.new do |opt|
    opt.banner = <<-EOD
    exoter_visualization [options]  </path/to/model/urdf_file>
    EOD
    opt.on '--host=HOSTNAME', String, 'the host we should contact to find RTT tasks' do |host|
        hostname = host
    end

    opt.on '--log=LOGFILE', String, 'path to the log file' do |log|
        logfile = log
    end

    opt.on '--help', 'this help message' do
        puts opt
        exit 0
    end
end

args = options.parse(ARGV)
model_file = args.shift

if !model_file
    puts "missing URDF model file argument"
    puts options
    exit 1
end

if hostname
    Orocos::CORBA.name_service.ip = hostname
end

# load log files and add the loaded tasks to the Orocos name service
log_replay = Orocos::Log::Replay.open(logfile) unless logfile.nil?

# If log replay track only needed ports
unless logfile.nil?
    log_replay.track(true)
    log_replay.transformer_broadcaster.rename('foo')
end


Orocos::CORBA::max_message_size = 100000000000
Bundles.initialize
Bundles.transformer.load_conf(Bundles.find_file('config', 'transforms_scripts.rb'))

robotVis = Vizkit.default_loader.RobotVisualization
robotVis.modelFile = model_file.dup
robotVis.setPluginName("ExoTer")
Vizkit.vizkit3d_widget.setPluginDataFrame("body", robotVis )

#RigidBodyState of the ground truth
rbsTruth = Vizkit.default_loader.RigidBodyStateVisualization
rbsTruth.setColor(Eigen::Vector3.new(0, 255, 0))#Green rbs
rbsTruth.setPluginName("Reference Pose")
rbsTruth.resetModel(0.4)
Vizkit.vizkit3d_widget.setPluginDataFrame("navigation", rbsTruth)

# Trajectory of the ground truth
truthTrajectory = Vizkit.default_loader.TrajectoryVisualization
truthTrajectory.setColor(Eigen::Vector3.new(0, 255, 0)) #Green line
truthTrajectory.setPluginName("Reference Trajectory")
Vizkit.vizkit3d_widget.setPluginDataFrame("navigation", truthTrajectory)

#RigidBody of the BodyCenter from odometry
odometryRBS = Vizkit.default_loader.RigidBodyStateVisualization
odometryRBS.displayCovariance(true)
odometryRBS.setPluginName("Odometry Pose")
odometryRBS.setColor(Eigen::Vector3.new(255, 0, 0))#Red
odometryRBS.resetModel(0.4)
Vizkit.vizkit3d_widget.setPluginDataFrame("navigation", odometryRBS)

# Odometry robot trajectory
odometryRobotTrajectory = Vizkit.default_loader.TrajectoryVisualization
odometryRobotTrajectory.setColor(Eigen::Vector3.new(255, 0, 0))#Red line
odometryRobotTrajectory.setPluginName("Odometry Trajectory")
Vizkit.vizkit3d_widget.setPluginDataFrame("navigation", odometryRobotTrajectory)


#RigidBody of the BodyCenter from localization
localizationRBS = Vizkit.default_loader.RigidBodyStateVisualization
localizationRBS.displayCovariance(true)
localizationRBS.setPluginName("Localization Pose")
localizationRBS.setColor(Eigen::Vector3.new(0, 0, 0))#Black
localizationRBS.resetModel(0.4)
Vizkit.vizkit3d_widget.setPluginDataFrame("navigation", localizationRBS)

# Odometry robot trajectory
localizationRobotTrajectory = Vizkit.default_loader.TrajectoryVisualization
localizationRobotTrajectory.setColor(Eigen::Vector3.new(0, 0, 0))#Black line
localizationRobotTrajectory.setPluginName("Localization Trajectory")
Vizkit.vizkit3d_widget.setPluginDataFrame("navigation", localizationRobotTrajectory)

# Point cloud visualizer
pointCloud = Vizkit.default_loader.PointcloudVisualization
pointCloud.setKeepOldData(true)
pointCloud.setMaxOldData(1)
pointCloud.setPluginName("ToF Point Cloud")
Vizkit.vizkit3d_widget.setPluginDataFrame("body", pointCloud)

# Point cloud Visual Odometry  visualizer
pointCloudVO = Vizkit.default_loader.PointcloudVisualization
pointCloudVO.setKeepOldData(true)
pointCloudVO.setMaxOldData(1)
pointCloudVO.setPluginName("VO Features")
Vizkit.vizkit3d_widget.setPluginDataFrame("body", pointCloudVO)

#RigidBody of the visual odometry
visualOdometryRBS = Vizkit.default_loader.RigidBodyStateVisualization
visualOdometryRBS.displayCovariance(true)
visualOdometryRBS.setPluginName("Visual Odometry Pose")
visualOdometryRBS.setColor(Eigen::Vector3.new(255, 255, 255))#White
visualOdometryRBS.resetModel(0.2)
Vizkit.vizkit3d_widget.setPluginDataFrame("navigation", visualOdometryRBS)

# Visual Odometry frame trajectory
visualOdometryTrajectory = Vizkit.default_loader.TrajectoryVisualization
visualOdometryTrajectory.setColor(Eigen::Vector3.new(255, 255, 255))#White line
visualOdometryTrajectory.setPluginName("Visual Odometry Trajectory")
Vizkit.vizkit3d_widget.setPluginDataFrame("navigation", visualOdometryTrajectory)

#RigidBody of the Iterative Closest Points
icpRBS = Vizkit.default_loader.RigidBodyStateVisualization
icpRBS.displayCovariance(true)
icpRBS.setPluginName("Iterative Closest Points Pose")
icpRBS.setColor(Eigen::Vector3.new(155, 0, 155))
icpRBS.resetModel(0.2)
Vizkit.vizkit3d_widget.setPluginDataFrame("navigation", icpRBS)

# Iterative Closest Points frame trajectory
icpTrajectory = Vizkit.default_loader.TrajectoryVisualization
icpTrajectory.setColor(Eigen::Vector3.new(155, 155, 155))
icpTrajectory.setPluginName("Iterative Closest Points Trajectory")
Vizkit.vizkit3d_widget.setPluginDataFrame("navigation", icpTrajectory)


#Contact points FL Wheel (RED)
c0FL = Vizkit.default_loader.RigidBodyStateVisualization
c0FL.displayCovariance(true)
c0FL.setPluginName("FLFoot0")
c0FL.setColor(Eigen::Vector3.new(0, 0, 0))
c0FL.resetModel(0.1)
Vizkit.vizkit3d_widget.setPluginDataFrame("body", c0FL)

#Contact points FR Wheel (GREEN)
c0FR = Vizkit.default_loader.RigidBodyStateVisualization
c0FR.setColor(Eigen::Vector3.new(0, 0, 0))
c0FR.setPluginName("FRFoot0")
c0FR.resetModel(0.1)
c0FR.displayCovariance(true)
Vizkit.vizkit3d_widget.setPluginDataFrame("body", c0FR)

#Contact points ML Wheel (GREEN)
c0ML = Vizkit.default_loader.RigidBodyStateVisualization
c0ML.setColor(Eigen::Vector3.new(0, 0, 0))
c0ML.setPluginName("MLFoot0")
c0ML.resetModel(0.1)
c0ML.displayCovariance(true)
Vizkit.vizkit3d_widget.setPluginDataFrame("body", c0ML)

#Contact points MR Wheel (GREEN)
c0MR = Vizkit.default_loader.RigidBodyStateVisualization
c0MR.setColor(Eigen::Vector3.new(0, 0, 0))
c0MR.setPluginName("MRFoot0")
c0MR.resetModel(0.1)
c0MR.displayCovariance(true)
Vizkit.vizkit3d_widget.setPluginDataFrame("body", c0MR)

#Contact points RL Wheel (BLUE)
c0RL = Vizkit.default_loader.RigidBodyStateVisualization
c0RL.setColor(Eigen::Vector3.new(0, 0, 0))
c0RL.setPluginName("RLFoot0")
c0RL.resetModel(0.1)
c0RL.displayCovariance(true)
Vizkit.vizkit3d_widget.setPluginDataFrame("body", c0RL)

#Contact points RR Wheel (WHITE)
c0RR = Vizkit.default_loader.RigidBodyStateVisualization
c0RR.setColor(Eigen::Vector3.new(0, 0, 0))
c0RR.setPluginName("RRFoot0")
c0RR.resetModel(0.1)
c0RR.displayCovariance(true)
Vizkit.vizkit3d_widget.setPluginDataFrame("body", c0RR)



# Joints Dispatcher or Localization FrontEnd
#read_joint_dispatcher = Orocos::Async.proxy 'read_joint_dispatcher'
localization_frontend = Orocos::Async.proxy 'localization_frontend'

#read_joint_dispatcher.on_reachable do
localization_frontend.on_reachable do

    #Joints positions
    #read_joint_dispatcher.port('joints_samples').on_data do |joints,_|
    localization_frontend.port('joints_samples_out').on_data do |joints,_|

        joints.names.push("dummy")
        joints.elements.push(Types::Base::JointState.new(:speed=> 0.00, :position => 0.00))

        joints.each_with_name do |value, name|
            #puts "Value: #{value} with name #{name}"
            if name == "left_passive" then
                joints.names.push("fl_mimic")
                joints.elements.push(Types::Base::JointState.new(:speed=> 0.00, :position => -value.position))
                joints.names.push("ml_mimic")
                joints.elements.push(Types::Base::JointState.new(:speed=> 0.00, :position => -value.position))
            elsif name == "right_passive" then
                joints.names.push("fr_mimic")
                joints.elements.push(Types::Base::JointState.new(:speed=> 0.00, :position => -value.position))
                joints.names.push("mr_mimic")
                joints.elements.push(Types::Base::JointState.new(:speed=> 0.00, :position => -value.position))
            elsif name == "rear_passive" then
                joints.names.push("rr_mimic")
                joints.elements.push(Types::Base::JointState.new(:speed=> 0.00, :position => -value.position))
                joints.names.push("rl_mimic")
                joints.elements.push(Types::Base::JointState.new(:speed=> 0.00, :position => -value.position))
            end
        end
        #joints.each do |value|
        #    puts "Vis Joint Value: #{value.position}"
        #end

        robotVis.updateData(joints)
        #puts "joints #{joints.names}"
    end
end

# Localization Front-End
localization_frontend = Orocos::Async.proxy 'localization_frontend'

localization_frontend.on_reachable do
    #Connect to the ground truth output port (rbs)
    Vizkit.display localization_frontend.port('reference_pose_samples_out'), :widget =>rbsTruth

    #Connect to the ground truth output port (trajectory visualizer)
    localization_frontend.port('reference_pose_samples_out').on_data do |ground_truth,_|
        truthTrajectory.updateTrajectory(ground_truth.position)
    end
end

# Point Cloud with color
#colorize_pointcloud = Orocos::Async.proxy 'colorize_pointcloud'
#
#colorize_pointcloud.on_reachable do
#    # Point Cloud
#    Vizkit.display colorize_pointcloud.port('colored_points'), :widget =>pointCloud
#end
#pituki_pointcloud = Orocos::Async.proxy 'pituki'
#
#pituki_pointcloud.on_reachable do
#    # Point Cloud
#    Vizkit.display pituki_pointcloud.port('point_cloud_samples_out'), :widget =>pointCloud
#end

# JointDispatcher
read_joint_dispatcher = Orocos::Async.proxy 'read_joint_dispatcher'

read_joint_dispatcher.on_reachable do

    #PTU positions
    read_joint_dispatcher.port('ptu_samples').on_data do |ptu,_|

       ptu.names.push("dummy")
       ptu.elements.push(Types::Base::JointState.new(:speed=> 0.00, :position=> 0.00))

       robotVis.updateData(ptu)
       #puts "ptu #{ptu.names}"
    end
end

# Odometry tasks in Asynchronous mode
exoter_odometry = Orocos::Async.proxy 'exoter_odometry'

exoter_odometry.on_reachable do

    #Access to the chains sub_ports
    vector_rbs = exoter_odometry.port('fkchains_rbs_out')
    vector_rbs.wait

    Vizkit.display vector_rbs.sub_port([:rbsChain, 0]), :widget => c0FL
    Vizkit.display vector_rbs.sub_port([:rbsChain, 1]), :widget => c0FR
    Vizkit.display vector_rbs.sub_port([:rbsChain, 2]), :widget => c0ML
    Vizkit.display vector_rbs.sub_port([:rbsChain, 3]), :widget => c0MR
    Vizkit.display vector_rbs.sub_port([:rbsChain, 4]), :widget => c0RL
    Vizkit.display vector_rbs.sub_port([:rbsChain, 5]), :widget => c0RR

    # Robot pose
    Vizkit.display exoter_odometry.port('pose_samples_out'), :widget =>odometryRBS

    # Trajectory
    exoter_odometry.port('pose_samples_out').on_data do |pose_rbs,_|
        odometryRobotTrajectory.updateTrajectory(pose_rbs.position)
    end

end


## TOF Camera in Asynchronous mode
#camera_tof = Orocos::Async.proxy 'camera_tof'
#camera_tof.on_reachable do
# Point cloud
#    Vizkit.display camera_tof.port('pointcloud'), :widget =>pointCloud
#end

leftImage = Vizkit.default_loader.ImageView
rightImage = Vizkit.default_loader.ImageView

localization_frontend.on_reachable do
    Vizkit.display localization_frontend.port('left_frame'), :widget => leftImage
    Vizkit.display localization_frontend.port('right_frame'), :widget => rightImage
end

# Visual Odometry tasks in Asynchronous mode
visual_odometry = Orocos::Async.proxy 'visual_odometry'

visual_odometry.on_reachable do

    # Robot pose
    Vizkit.display visual_odometry.port('pose_samples_out'), :widget =>visualOdometryRBS

    # Trajectory
    visual_odometry.port('pose_samples_out').on_data do |vo_rbs,_|
        visualOdometryTrajectory.updateTrajectory(vo_rbs.position)
    end

    #Point cloud
    Vizkit.display visual_odometry.port('point_cloud_samples_out'), :widget =>pointCloudVO

end

# Iterative Closest Points tasks in Asynchronous mode
icp = Orocos::Async.proxy 'generalized_icp'

icp.on_reachable do

    # Robot pose
    Vizkit.display icp.port('pose_samples_out'), :widget =>icpRBS

    # Trajectory
    icp.port('pose_samples_out').on_data do |icp_rbs,_|
        icpTrajectory.updateTrajectory(icp_rbs.position)
    end

    # Point Cloud
    Vizkit.display icp.port('point_cloud_samples_out'), :widget =>pointCloud

end

# Localization Front-End
localization_backend = Orocos::Async.proxy 'localization_backend'

localization_backend.on_reachable do

    # Robot pose
    Vizkit.display localization_backend.port('pose_samples_out'), :widget =>localizationRBS

    # Trajectory
    localization_backend.port('pose_samples_out').on_data do |localization_rbs,_|
        localizationRobotTrajectory.updateTrajectory(localization_rbs.position)
    end

end



# Enable the GUI when the task is reachable
read_joint_dispatcher.on_reachable {Vizkit.vizkit3d_widget.setEnabled(true)} if logfile.nil?

# Disable the GUI until the task is reachable
read_joint_dispatcher.on_unreachable {Vizkit.vizkit3d_widget.setEnabled(false)} if logfile.nil?

Vizkit.control log_replay unless logfile.nil?
Vizkit.exec


