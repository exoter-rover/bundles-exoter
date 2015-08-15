#! /usr/bin/env ruby

require 'orocos'
require 'orocos/log'
require 'rock/bundle'
require 'vizkit'

include Orocos

if ARGV.size < 1 then
    puts "usage: process_logs_ikf.rb <data_log_directory>"
    exit
end

#Initializes the CORBA communication layer
Bundles.initialize


Orocos::Process.run 'orientation_estimator::IKF' => 'ikf_orientation_estimator' do

    ikf_attitude_task = TaskContext.get 'ikf_orientation_estimator'
    Orocos.conf.apply(ikf_attitude_task, ['default', 'ESTEC', 'stim300_5g'], :override => true)

    # connect the tasks to the logs
    log_replay = Orocos::Log::Replay.open( ARGV[0] )

    #Mapping the inputs ports in the orientation task
    log_replay.imu_stim300.calibrated_sensors.connect_to(ikf_attitude_task.imu_samples, :type => :buffer, :size => 10)
    #log_replay.imu_stim300.inertial_sensors_out.connect_to(ikf_attitude_task.imu_samples, :type => :buffer, :size => 10)

    # log all the output ports
    Orocos.log_all_ports

    ikf_attitude_task.configure
    ikf_attitude_task.start

    # open the log replay widget
    control = Vizkit.control log_replay
    control.speed = 1 #4

    Vizkit.exec

end
