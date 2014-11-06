require 'orocos'
require 'readline'

include Orocos

## Initialize orocos ##
Orocos.initialize

## Execute the task 'platform_driver::Task' ##
Orocos.run 'platform_driver::Task' => 'platform_driver' , 'locomotion_control::Task' => 'locomotion_control' , 'exoter_teleop::Task' => 'teleop' do
  ## Get the task context ##
  platform_driver = TaskContext.get 'platform_driver'
  locomotion = TaskContext.get 'locomotion_control'
  exoter_teleop = TaskContext.get 'teleop'
  
  exoter_teleop.motion_command.connect_to locomotion.motion_command
  locomotion.motor_commands.connect_to platform_driver.motor_commands
  platform_driver.motor_readings.connect_to locomotion.motor_readings

  platform_driver.apply_conf_file("../config/platform_driver::Task.yml")
  locomotion.apply_conf_file("../../locomotion_control/config/locomotion_control::Task.yml")

  Orocos.log_all_ports

  ## Start the tasks ##
  platform_driver.configure
  locomotion.configure
  exoter_teleop.configure
  platform_driver.start
  locomotion.start
  exoter_teleop.start

  Readline::readline("Press ENTER to exit\n") do
  end
end
