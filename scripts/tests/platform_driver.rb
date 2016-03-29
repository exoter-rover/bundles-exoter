#!/usr/bin/env ruby

require 'rock/bundle'
require 'readline'

include Orocos

## Initialize orocos ##
Bundles.initialize

Orocos::Process.run 'platform_driver::Task' => 'platform_driver' do


    # Vicon driver
    puts "Setting up platform_driver"
    pd = Orocos.name_service.get 'platform_driver'
    Orocos.conf.apply(pd, ['default'], :override => true)
    pd.configure
    puts "done"

    # Log all ports
    Orocos.log_all_ports

    #Start the tasks
    pd.start

    Readline::readline("Press ENTER to exit\n") do
    end


end
