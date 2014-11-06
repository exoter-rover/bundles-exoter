#! /usr/bin/env ruby

require 'orocos'
require 'orocos/async'
require 'vizkit'
require 'optparse'

hostname = nil
logfile = nil

options = OptionParser.new do |opt|
    opt.banner = <<-EOD
    exoter_gui_calibration [options]  </path/to/model/urdf_file>
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

Orocos::CORBA::max_message_size = 100000000000
Orocos.initialize

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

#RigidBody of the BodyCenter from odometry
odometryRBS = Vizkit.default_loader.RigidBodyStateVisualization
odometryRBS.displayCovariance(true)
odometryRBS.setPluginName("Odometry Pose")
odometryRBS.setColor(Eigen::Vector3.new(255, 0, 0))#Red
odometryRBS.resetModel(0.4)
Vizkit.vizkit3d_widget.setPluginDataFrame("navigation", odometryRBS)

#RigidBodyState of the Chessboard
rbsChessBoard = Vizkit.default_loader.RigidBodyStateVisualization
rbsChessBoard.setColor(Eigen::Vector3.new(0, 255, 0))#Red rbs
rbsChessBoard.setPluginName("Chessboard Pose")
rbsChessBoard.resetModel(0.4)
Vizkit.vizkit3d_widget.setPluginDataFrame("world", rbsChessBoard)

#RigidBodyState of the TOF camera
rbsExoterPtu = Vizkit.default_loader.RigidBodyStateVisualization
rbsExoterPtu.setColor(Eigen::Vector3.new(0, 255, 0))#Red rbs
rbsExoterPtu.setPluginName("TOF Pose")
rbsExoterPtu.resetModel(0.4)
Vizkit.vizkit3d_widget.setPluginDataFrame("world", rbsExoterPtu)

# Point cloud visualizer
pointCloud = Vizkit.default_loader.PointcloudVisualization
pointCloud.setKeepOldData(true)
pointCloud.setMaxOldData(1)
Vizkit.vizkit3d_widget.setPluginDataFrame("body", pointCloud)

# load log files and add the loaded tasks to the Orocos name service
log_replay = Orocos::Log::Replay.open(logfile) unless logfile.nil?

# Localization Front-End
localization_frontend = Orocos::Async.proxy 'localization_frontend'

localization_frontend.on_reachable do

    #Joints positions
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

    #Connect to the ground truth output port (rbs)
    Vizkit.display localization_frontend.port('reference_pose_samples_out'), :widget =>rbsTruth

end


# Point Cloud with color
colorize_pointcloud = Orocos::Async.proxy 'colorize_pointcloud'

colorize_pointcloud.on_reachable do
    # Point Cloud
    Vizkit.display colorize_pointcloud.port('colored_points'), :widget =>pointCloud
end

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

    # Robot pose
    Vizkit.display exoter_odometry.port('pose_samples_out'), :widget =>odometryRBS

end


# Vicon ChessBoard tasks in Asynchronous mode
vicon_chessboard = Orocos::Async.proxy 'vicon_chessboard'

vicon_chessboard.on_reachable do

    # Robot pose
    Vizkit.display vicon_chessboard.port('pose_samples'), :widget =>rbsChessBoard

end

# Vicon ExoTeR PTU tasks in Asynchronous mode
vicon_exoter_ptu = Orocos::Async.proxy 'vicon_exoter_ptu'

vicon_exoter_ptu.on_reachable do

    # Robot pose
    Vizkit.display vicon_exoter_ptu.port('pose_samples'), :widget =>rbsExoterPtu

end

# Transformer Broadcaster
transformer_broadcaster = Orocos::Async.proxy 'transformer_broadcaster'

Vizkit.control log_replay unless logfile.nil?
Vizkit.exec


