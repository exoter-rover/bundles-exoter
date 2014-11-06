#! /usr/bin/env ruby

require 'orocos'
require 'orocos/log'
require 'rock/bundle'
require 'vizkit'
require 'utilrb'


include Orocos

if ARGV.size < 1 then 
    puts "usage: process_logs_stitching.rb <data_log_directory>"
    exit
end

Orocos::CORBA::max_message_size = 100000000000
Bundles.initialize
Bundles.transformer.load_conf(Bundles.find_file('config', 'transforms_scripts.rb'))

Orocos::Process.run 'projection::VirtualView' => 'stitching' do

    ## Get the task context ##
    STDERR.print "setting up stitching"
    stitching = TaskContext.get 'stitching'
    Orocos.conf.apply(stitching, ['camera_bb2'], :override => true)
    Bundles.transformer.setup(stitching)
    stitching.configure
    STDERR.puts "done"

    # logs files
    log_replay = Orocos::Log::Replay.open( ARGV[0] )
    #log_replay.transformer_broadcaster.rename("old_transformer_broadcaster")

    # log port connections
    log_replay.camera_bb2.left_frame.connect_to(stitching.cam1, :type => :buffer, :size => 200)
    log_replay.camera_bb2.right_frame.connect_to(stitching.cam2, :type => :buffer, :size => 200)


    stitching.start

    # open the log replay widget
    control = Vizkit.control log_replay
    control.speed = 1

    Vizkit.exec


end
