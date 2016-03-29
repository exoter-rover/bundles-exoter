#!/usr/bin/env ruby

require 'vizkit'
require 'rock/bundle'
require 'readline'

include Orocos

options = {}
options[:reference] = "none"
options[:logging] = "nominal"

OptionParser.new do |opt|
    opt.banner = <<-EOD
    usage: exoter_start_all.rb [options] 
    EOD

    opt.on '-r or --reference=none/vicon/gnss', String, 'set the type of reference system available' do |reference|
        options[:reference] = reference
    end

    opt.on '-l or --logging=none/minimum/nominal/all', String, 'set the type of log files you want. Nominal as default' do |logging|
        options[:logging] = logging
    end

    opt.on '--help', 'this help message' do
        puts opt
       exit 0
    end
end.parse!(ARGV)

## Initialize orocos ##
Bundles.initialize

Orocos::Process.run 'exoter_groundtruth', 'exoter_exteroceptive', 'exoter_proprioceptive' do

    if options[:reference].casecmp("gnss").zero?
        puts "[INFO] GPS system available"
        # setup exoter gnss
        puts "Setting up gnss"
        gnss = Orocos.name_service.get 'gnss_trimble'
        Orocos.conf.apply(gnss, ['exoter', 'Netherlands', 'SEROM'], :override => true)
        gnss.configure
        puts "done"
    else
        puts "[INFO] No Ground Truth system available"
    end

    # setup exoter mesa tof
    puts "Setting up mesa tof"
    tof_mesa = Orocos.name_service.get 'camera_tof'
    Orocos.conf.apply(tof_mesa, ['default'], :override => true)
    tof_mesa.configure
    puts "done"

    # setup exoter bb2
    puts "Setting up bb2"
    camera_firewire_pan_cam = Orocos.name_service.get 'camera_firewire_pan_cam'
    Orocos.conf.apply(camera_firewire_pan_cam, ['default'], :override => true)
    camera_firewire_pan_cam.configure
    camera_bb2_pan_cam = Orocos.name_service.get 'camera_bb2_pan_cam'
    Orocos.conf.apply(camera_bb2_pan_cam, ['default'], :override => true)
    camera_bb2_pan_cam.configure
    puts "done"

    # setup exoter imu_stim300
    puts "Setting up imu"
    imu = Orocos.name_service.get 'imu_stim300'
    Orocos.conf.apply(imu, ['default', 'exoter','SEROM','stim300_5g'], :override => true)
    imu.configure
    puts "done"

    # Log all ports
    Orocos.log_all_ports

    puts "Connecting ports"
    camera_firewire_pan_cam.frame.connect_to camera_bb2_pan_cam.frame_in

    # Start the tasks
    if options[:reference].casecmp("gnss").zero?
        gnss.start
    end
    tof_mesa.start
    camera_firewire_pan_cam.start
    camera_bb2_pan_cam.start
    imu.start

    Readline::readline("Press ENTER to exit\n") do
    end

end

