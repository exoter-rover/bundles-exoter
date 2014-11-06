#!/usr/bin/env ruby

require 'orocos'
require 'orocos/log'
require 'rock/bundle'
require 'vizkit'
require 'utilrb'

include Orocos

if ARGV.size < 1 then
    puts "usage: process_logs_icp.rb <data_log_directory>"
    exit
end


Orocos::CORBA::max_message_size = 100000000000
Bundles.initialize

Orocos::Process.run 'icp::GIcp' => 'icp', :valgrind => false do

    # get the task
    STDERR.print "setting up icp..."
    icp = Orocos.name_service.get 'icp'
    Orocos.conf.apply(icp, ['default'], :override => true )
    icp.point_cloud_height = 7870
    icp.point_cloud_width = 1
    STDERR.puts "done"

    # logs files
    log_replay = Orocos::Log::Replay.open( ARGV[0] )

    # Log port connections
    log_replay.ply_logs.point_cloud_samples_out.connect_to(icp.point_cloud_source, :type => :buffer, :size => 200)

    # Configure and Run the task
    icp.configure

    icp.start

    # open the log replay widget
    control = Vizkit.control log_replay
    control.speed = 1 #4

    Vizkit.exec


end

