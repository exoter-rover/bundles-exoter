#!/usr/bin/env ruby

require 'rock/bundle'
require 'readline'

include Orocos

## Initialize orocos ##
Bundles.initialize

Orocos::Process.run 'imu_stim300::Task' => 'imu_stim300',
            'vicon::Task' => 'vicon' do


    # Vicon driver
    puts "Setting up vicon"
    vicon = Orocos.name_service.get 'vicon'
    Orocos.conf.apply(vicon, ['default', 'imu_test'], :override => true)
    vicon.configure
    puts "done"

    #STIM300 imu
    puts "Setting up imu_stim300"
    imu_stim300 = Orocos.name_service.get 'imu_stim300'
    Orocos.conf.apply(imu_stim300,  ['default','ExoTer','ESTEC','stim300_5g'], :override => true)
    imu_stim300.configure
    puts "done"

    # Log all ports
    Orocos.log_all_ports

    #Start the tasks
    vicon.start
    imu_stim300.start

    Readline::readline("Press ENTER to exit\n") do
    end


end
