#!/usr/bin/env ruby

require 'orocos'
require 'orocos/log'
require 'rock/bundle'
require 'vizkit'
require 'utilrb'
require 'optparse'

include Orocos

options = {}
options[:camera_bb2] = 'none'

op = OptionParser.new do |opt|
    opt.banner = <<-EOD
    usage: proces_logs_stereo [options] <data_log_directory>
    EOD

    opt.on "-c", "--camera_bb2=task/log", String, 'set the type of camera_bb2: task to run the task log for taking the images from an existing log' do |camera|
        options[:camera_bb2] = camera
    end

    opt.on '--help', 'this help message' do
        puts opt
       exit 0
    end
end

args = op.parse(ARGV)
logfiles_path = args.shift

if !logfiles_path
    puts "missing path to log files"
    puts options
    exit 1
end

Orocos::CORBA::max_message_size = 100000000000
Bundles.initialize

if options[:camera_bb2].casecmp("task").zero?
    puts "[INFO] Running task camera_bb2"
elsif options[:camera_bb2].casecmp("log").zero?
    puts "[INFO] camera_bb2 taken from logs"
else
    puts "[INFO] Please specify camera_bb2! EXIT"
    exit 1
end

Orocos::Process.run 'stereo::Task' => 'stereo',
                    'camera_bb2::Task' => 'camera_bb2' do

    if options[:camera_bb2].casecmp("task").zero?
        STDERR.print "setting up camera_bb2..."
        camera_bb2 = TaskContext.get 'camera_bb2'
        Orocos.conf.apply(camera_bb2, ['default'], :override => true)
        camera_bb2.undistort = false
        STDERR.puts "done"
    end

    STDERR.print "setting up stereo..."
    stereo = TaskContext.get 'stereo'
    Orocos.conf.apply(stereo, ['bumblebee'], :override => true)
    STDERR.puts "done"

    log_replay = Orocos::Log::Replay.open( logfiles_path )

    ###################
    ## LOG THE PORTS ##
    ###################
    Bundles.log_all

    ###################
    ## CONFIGURE ##
    ###################
    if options[:camera_bb2].casecmp("task").zero?
        stereo.image_rectified = false
        camera_bb2.configure
    end
    stereo.configure

    ###########################
    ## LOG PORTS CONNECTIONS ##
    ###########################
    if options[:camera_bb2].casecmp("task").zero?
        log_replay.camera_firewire.frame.connect_to(camera_bb2.frame_in, :type => :buffer, :size => 200)

        # task
        camera_bb2.left_frame.connect_to(stereo.left_frame, :type => :buffer, :size => 200)
        camera_bb2.right_frame.connect_to(stereo.right_frame, :type => :buffer, :size => 200)
    elsif options[:camera_bb2].casecmp("log").zero?
        # logs files
        log_replay.camera_bb2.left_frame.connect_to(stereo.left_frame, :type => :buffer, :size => 200)
        log_replay.camera_bb2.right_frame.connect_to(stereo.right_frame, :type => :buffer, :size => 200)
    end

    ###################
    ## START ##
    ###################
    if options[:camera_bb2].casecmp("task").zero?
        camera_bb2.start
    end
    stereo.start

    # open the log replay widget
    control = Vizkit.control log_replay
    control.speed = 1

    Vizkit.exec
end
