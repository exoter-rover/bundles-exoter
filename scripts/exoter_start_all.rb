#!/usr/bin/env ruby

require 'orocos'
require 'vizkit'
require 'rock/bundle'
require 'utilrb'
require 'readline'
require 'optparse'
load 'scripts/startup.rb'

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
Orocos::CORBA.max_message_size = 80400000
Bundles.initialize
Bundles.transformer.load_conf(Bundles.find_file('config', 'transforms_scripts.rb'))

# Configuration values
if options[:reference].casecmp("vicon").zero?
    puts "[INFO] Vicon Ground Truth system available"
elsif options[:reference].casecmp("gnss").zero?
    puts "[INFOR] GNSS Ground Truth system available"
else
    puts "[INFO] No Ground Truth system available"
end

Bundles.run 'exoter_control',
            'exoter_proprioceptive',
            'exoter_exteroceptive',
            'exoter_localization',
            'exoter_slam',
            'exoter_groundtruth',
            'valgrind'=> false,
            'wait' => 1000 do

    startup = Startup.new

    #get all task context
    puts("Getting task context")
    startup.getContext(options)
    puts("done")

    #set configuration for all
    puts("Applying configuration")
    startup.setConfig()
    puts("done")

    #configure
    puts("Configuring tasks")
    startup.configure()
    puts("done")

    #connect all
    puts("Connecting tasks")
    startup.connectLocomotion()
    startup.connectPerception()
    startup.connectSLAM()
    puts("done")


    # start the tasks
    puts("starting tasks")
    startup.start()
    puts("done")

    # Log the ports
    if options[:logging].casecmp('none').zero?
        puts "[INFO] No logging Tasks informattion"
    elsif options[:logging].casecmp('minimum').zero?
        puts "[INFO] Logging Minimum Tasks information"
        startup.log_minimum_all()
    elsif options[:logging].casecmp('nominal').zero?
        puts "[INFO] Logging Nominal Tasks information"
        startup.log_nominal_all()
    else
        puts "[INFO] Logging All Tasks information"
        startup.log_all
    end
    puts("done")

    # Wait for ENTER on input
    puts "Press ENTER to stop!"
    STDIN.readline


    puts("Sending zero position to PTU")
    startup.stop_ptu_to_safe_position()
    puts("done")

    sleep 3.0

    # stopping the tasks
    puts("Stopping tasks")
    startup.stop()
    puts("done")



    # cleaning up the tasks
    puts("cleaning up tasks")
    startup.cleanup()
    puts("done")

end

