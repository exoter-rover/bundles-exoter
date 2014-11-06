#!/usr/bin/env ruby

require 'rock/bundle'
require 'readline'

include Orocos

## Initialize orocos ##
Bundles.initialize

Orocos::Process.run 'vicon::Task' => 'vicon_chessboard' do 

    # Vicon driver
    puts "Setting up vicon for the chessboard"
    vicon_chessboard = Orocos.name_service.get 'vicon_chessboard'
    Orocos.conf.apply(vicon_chessboard, ['default', 'chessboard'], :override => true)
    vicon_chessboard.configure
    puts "done"

    # Log all ports
    Orocos.log_all_ports

    #Start the tasks
    vicon_chessboard.start

    Readline::readline("Press ENTER to exit\n") do
    end


end
