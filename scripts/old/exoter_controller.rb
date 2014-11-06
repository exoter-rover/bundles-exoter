#!/usr/bin/env ruby

require 'rock/bundle'
require 'orocos/async'
require 'vizkit'
require 'readline'

include Orocos

if ARGV.size < 1
    puts "usage: joystick.rb host-address [device_name]"
    exit(0)
end

host_address = ARGV[0]
device_name = "/dev/input/js0" # This might be another port
if ARGV[1] then
    device_name = ARGV[1]
end


Orocos::CORBA.name_service.ip = host_address

## Initialize orocos ##
Bundles.initialize

file_joystick = Bundles.find_file('scripts/controllers/', 'joystick.rb')

system("ruby"+ file_joystick +" localhost /dev/input/js1")


puts file_joystick
    Readline::readline("Press Enter to exit\n") 
## Load GUI ##
#file_ui = Bundles.find_file('data/gui', 'joystick_controller.ui')
#widget = Vizkit.load file_ui

# Read the Raw Commands
#raw_command_writer = joystick.raw_command.writer

#widget.show
#Vizkit.exec
