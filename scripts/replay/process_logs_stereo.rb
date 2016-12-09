#!/usr/bin/env ruby

require 'orocos'
require 'orocos/log'
require 'rock/bundle'
require 'vizkit'
require 'utilrb'
require 'optparse'

include Orocos

Orocos::CORBA::max_message_size = 100000000000
Bundles.initialize

Orocos::Process.run 'stereo::Task' => 'stereo' do

    ## Get the task context ##
    STDERR.print "setting up stereo..."
    stereo = TaskContext.get 'stereo'
    Orocos.conf.apply(stereo, ['bumblebee'], :override => true)
    stereo.configure
    STDERR.puts "done"

    # logs files
    log_replay = Orocos::Log::Replay.open( ARGV[0] )
    log_replay.camera_bb2.left_frame.connect_to(stereo.left_frame, :type => :buffer, :size => 200)
    log_replay.camera_bb2.right_frame.connect_to(stereo.right_frame, :type => :buffer, :size => 200)

    ###################
    ## LOG THE PORTS ##
    ###################
    Bundles.log_all

    stereo.start

    # open the log replay widget
    control = Vizkit.control log_replay
    control.speed = 1

    Vizkit.exec

end
