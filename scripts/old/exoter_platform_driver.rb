require 'orocos'
require 'readline'

include Orocos

## Initialize orocos ##
Orocos.initialize

## Execute the task 'platform_driver::Task' ##
Orocos.run 'platform_driver::Task' => 'platform_driver' , 'locomotion_control::Task' => 'locomotion_control' do #, 'controldev::JoystickTask' => 'joystick' do
  ## Get the task context ##
  platform_driver = TaskContext.get 'platform_driver'
  locomotion = TaskContext.get 'locomotion_control'
  joystick_driver = TaskContext.get 'joystick'
  
  joystick_driver.motion_command.connect_to locomotion.motion_command
  locomotion.motor_commands.connect_to platform_driver.motor_commands
  platform_driver.motor_readings.connect_to locomotion.motor_readings

  platform_driver.apply_conf_file("../config/platform_driver::Task.yml")
  locomotion.apply_conf_file("../../locomotion_control/config/locomotion_control::Task.yml")

  Orocos.log_all_ports

  ## Start the tasks ##
  platform_driver.configure
  locomotion.configure
  joystick_driver.configure
  platform_driver.start
  locomotion.start
  joystick_driver.start

  #reader = platform_driver.motorReadings.reader
  
  #while true
  #    if p = reader.read_new
  #        puts "#{p}"
  #    end
  #    if v = reader.read_new
  #        puts "#{v}"
  #    end  
  #    sleep 0.1
  #end
  Readline::readline("Press ENTER to exit\n") do
  end
end
