#!/usr/bin/env ruby

require 'rock/bundle'
require 'vizkit'
require 'readline'

hostname = nil

options = OptionParser.new do |opt|
    opt.banner = <<-EOD
    usage: exoter_gamepad.rb [options]  </path/to/gamepad_device>
    EOD
    opt.on '--host=HOSTNAME', String, 'the host we should contact to find RTT tasks' do |host|
    hostname = host
    end
    opt.on '--help', 'this help message' do
    puts opt
    exit 0
    end
end

args = options.parse(ARGV)
device_name = args.shift

if !device_name
    puts "missing device name for the joystick/gamepad"
    puts options
    exit 1
end

if hostname
    Orocos::CORBA.name_service.ip = hostname
end

include Orocos

## Initialize Orocos ##
Bundles.initialize

## Load GUI ##
file_ui = Bundles.find_file('data/gui', 'joystick_controller.ui')
widget = Vizkit.load file_ui

widget.pan_position.setValidator(Qt::IntValidator.new(-180, 180))
widget.tilt_position.setValidator(Qt::IntValidator.new(-180, 180))

# Global variable
max_linear_speed = 0.00
max_rot_speed = 0.00
rover_speed_ratio = 0.00
ptu_speed_ratio = 0.00
x_velocity = 0.00
y_velocity = 0.00
rotation = 0.00
translation = 0.00
x_axis = 0.00
y_axis = 0.00
pan_axis = 0.00
tilt_axis = 0.00
pan_velocity = 0.00
pan_position = 0.00
tilt_velocity = 0.00
tilt_position = 0.00
axes_changed = FALSE
buttons_changed = FALSE

Orocos::Process.run 'controldev::JoystickTask' => 'joystick' do

    ## Get the Joystick task context ##
    joystick = TaskContext.get 'joystick'
    Orocos.conf.apply(joystick, ['default', 'logitech_gamepad'], :override => true)
    joystick.device = device_name

    ## Get the ExoTer control
    locomotion_control = Orocos.name_service.get 'locomotion_control'
    command_dispatcher = Orocos.name_service.get 'command_joint_dispatcher'

    # Log all ports
    Orocos.log_all_ports

    # Configure and start the task
    if File.exist? device_name then
        #joystick.motion_command.connect_to locomotion_control.motion_command
        joystick.configure
        joystick.start

        ## Joystick Variables
        axes = Array.new(joystick.axisScale.size, 0.00)
        buttons = Array.new(11, 0.00)
        max_linear_speed = joystick.maxSpeed
        max_rot_speed = joystick.maxRotationSpeed
        puts "          number of buttons: #{buttons.length}"
        puts "          max_linear_speed: #{max_linear_speed}"
        puts "          max_rot_speed: #{max_rot_speed}"
        puts "DONE."
    else
        puts 'Couldn\'t find device ' + device_name + '. Using joystick gui instead.'
        motion_cmd_writer = locomotion_control.motion_command.writer
        motion_cmd = motion_cmd_writer.new_sample
        joystickGui = Vizkit.default_loader.create_plugin('VirtualJoystick')
        joystickGui.show
        joystickGui.connect(SIGNAL('axisChanged(double, double)')) do |x, y|
            motion_cmd.translation = x * 0.1
            motion_cmd.rotation =  - y.abs() * Math::atan2(y, x.abs()) / 1.0 * 0.3
            motion_cmd_writer.write(motion_cmd)
        end
    end

    # Read the Raw Commands
    joystick.raw_command.connect_to do |raw_command, _|

        # Axes
        i = 0
        current_axes = Array.new(joystick.axisScale.size, 0.00)
        raw_command.axes.elements.each do |item|
            current_axes[i] = item
            i = i + 1
        end

        #Buttons
        i = 0
        current_buttons = Array.new(11, 0.00)
        raw_command.buttons.elements.each do |item|
            current_buttons[i] = item
            i = i + 1
        end

        # Check Axes changed
        unless (axes == current_axes)

            # Main Axes set have priority
            unless (axes[5] == current_axes[5]) and (axes[4] == current_axes[4])
                x_axis = current_axes[5]
                y_axis = current_axes[4]
            else
                x_axis = current_axes[1]
                y_axis = current_axes[0]
            end

            #PTU Joints information
            pan_axis = current_axes[2]
            tilt_axis = current_axes[3]

            #puts "x_axis: #{x_axis}"
            #puts "y_axis: #{y_axis}"
            puts "pan_axis: #{pan_axis}"
            puts "tilt_axis: #{tilt_axis}"

            axes = current_axes;
            axes_changed = TRUE
        end

        # Check buttons changed
        unless (buttons == current_buttons)
            #puts "Pressed at: #{raw_command.time}"

            # Check buttons
            if current_buttons[8] == 1.0 ## emergency stop button 5
                # TO-DO Kill locomotion control
            end

            if current_buttons[5]==1.0
                rover_speed_ratio = rover_speed_ratio + 0.050000
            elsif current_buttons[7]==1.0
                rover_speed_ratio = rover_speed_ratio - 0.050000
            end

            if (rover_speed_ratio > 1.0)
                rover_speed_ratio = 1.0
            elsif (rover_speed_ratio < 0.0)
                rover_speed_ratio = 0.00
            end

            if current_buttons[4]==1.0 and ptu_speed_ratio < 1.0
                ptu_speed_ratio = ptu_speed_ratio + 0.050000
            elsif current_buttons[6]==1.0 and ptu_speed_ratio > 0.0
                ptu_speed_ratio = ptu_speed_ratio - 0.050000
            end

            if (ptu_speed_ratio > 1.0)
                ptu_speed_ratio = 1.0
            elsif (ptu_speed_ratio < 0.0)
                ptu_speed_ratio = 0.00
            end

            buttons = current_buttons;
            buttons_changed = TRUE
        end

        # Send the command to the locomotion control
        if (axes_changed or buttons_changed)

            # Form the command
            x_velocity = x_axis * max_linear_speed * rover_speed_ratio
            y_velocity = y_axis

            translation = x_velocity
            rotation = -y_velocity.abs * Math::atan2(y_velocity, x_velocity.abs) / Math::PI * max_rot_speed * rover_speed_ratio
            if translation < 0.00
                rotation = -rotation
            end

            # Point turn button
            if buttons[10]==1.0
                translation = 0.00
            elsif rotation != 0.00 and translation == 0.00
                translation = 0.05 * max_linear_speed * rover_speed_ratio
            end

            # PTU velocities
            pan_velocity = pan_axis * ptu_speed_ratio
            tilt_velocity = tilt_axis * ptu_speed_ratio

            puts "SEND TO EXOTER"
            puts "rover_speed_ratio: #{rover_speed_ratio}"
            puts "ptu_speed_ratio: #{ptu_speed_ratio}"
            puts "translation: #{translation}"
            puts "rotation: #{rotation}"
            puts "pan_velocity: #{pan_velocity}"
            puts "tilt_velocity: #{tilt_velocity}"

            motion_cmd_writer = locomotion_control.motion_command.writer
            motion_cmd = motion_cmd_writer.new_sample
            motion_cmd.translation = translation
            motion_cmd.rotation =  rotation
            motion_cmd_writer.write(motion_cmd)

            ptu_joints_writer = command_dispatcher.ptu_commands.writer
            ptu_joints = ptu_joints_writer.new_sample
            ptu_joints.names = ["MAST_PAN", "MAST_TILT"]
            ptu_joints.elements = [Types::Base::JointState.new(:speed => pan_velocity, :position => NaN),
                                Types::Base::JointState.new(:speed => tilt_velocity, :position => NaN)]
            ptu_joints_writer.write(ptu_joints)

            axes_changed = FALSE
            buttons_changed = FALSE
        end

        ## ###### ##
        # Update GUI
        ## ###### ##
        #puts widget.lcd_translation.public_methods
        #puts "TRANSLATION:#{translation*100.00}"
        widget.lcd_translation.display(translation*100.00)
        widget.lcd_heading.display(rotation*180.00/Math::PI)
        widget.bar_rover_ratio.setValue(rover_speed_ratio*100.00)
        widget.bar_ptu_ratio.setValue(ptu_speed_ratio*100.00)
        widget.lcd_pan.display(pan_velocity*180.00/Math::PI)
        widget.lcd_tilt.display(tilt_velocity*180.00/Math::PI)

        ## ############## ##
        # Send PTU Positions
        ## ############## ##
        widget.sendButton.connect(SIGNAL('clicked()')) do
            ptu_joints_writer = command_dispatcher.ptu_commands.writer
            ptu_joints = ptu_joints_writer.new_sample
            pan_position = (widget.pan_position.text.to_f * Math::PI / 180.00)
            tilt_position = (widget.tilt_position.text.to_f * Math::PI / 180.00)
            ptu_joints.names = ["MAST_PAN", "MAST_TILT"]
            ptu_joints.elements = [Types::Base::JointState.new(:speed => NaN, :position => pan_position),
                    Types::Base::JointState.new(:speed => NaN, :position => tilt_position)]
            ptu_joints_writer.write(ptu_joints)
        end

        ## ######### ##
        # Update Images
        ## ######### ##

        # ExoTer Stop
        pixmap = Qt::Pixmap.new(Bundles.find_file('data/gui/images', 'exoter_start.png'))

        if (pan_velocity != 0.00 or tilt_velocity != 0.00)
            if (translation != 0.00 or rotation != 0.00)
                # Moving ExoTer and the Pan and Tilt
                pixmap = Qt::Pixmap.new(Bundles.find_file('data/gui/images', 'exoter_move_all.png'))
            elsif (translation == 0.00 and rotation == 0.00)
                # Moving the Pan and Tilt
                pixmap = Qt::Pixmap.new(Bundles.find_file('data/gui/images', 'exoter_pan_tilt.png'))
            end
        else
           if rotation > 0.00
               if translation == 0.00
                   # Spot-turn to left
                   pixmap = Qt::Pixmap.new(Bundles.find_file('data/gui/images', 'exoter_point_turn_left.png'))
               elsif translation > 0.00
                   # Ackerman left forward
                   pixmap = Qt::Pixmap.new(Bundles.find_file('data/gui/images', 'exoter_ackerman_left_fwd.png'))
               else
                   # Ackerman left back
                   pixmap = Qt::Pixmap.new(Bundles.find_file('data/gui/images', 'exoter_ackerman_right_back.png'))
               end
           elsif rotation < 0.00
               if translation == 0.00
                   # Spot-turn to right
                   pixmap = Qt::Pixmap.new(Bundles.find_file('data/gui/images', 'exoter_point_turn_right.png'))
               elsif translation > 0.00
                   # Ackerman right forward
                   pixmap = Qt::Pixmap.new(Bundles.find_file('data/gui/images', 'exoter_ackerman_right_fwd.png'))
               else
                   # Ackerman right back
                   pixmap = Qt::Pixmap.new(Bundles.find_file('data/gui/images', 'exoter_ackerman_left_back.png'))
               end
           elsif rotation == 0.00
               if translation > 0.00
                   # Forward
                   pixmap = Qt::Pixmap.new(Bundles.find_file('data/gui/images', 'exoter_fwd.png'))
               elsif translation < 0.00
                   # Backward
                   pixmap = Qt::Pixmap.new(Bundles.find_file('data/gui/images', 'exoter_back.png'))
               end
           end
        end
        widget.image.setPixmap(pixmap)

    end

    # Show the GUI
    widget.show
    Vizkit.exec

    #Readline::readline("Press Enter to exit\n") 
end

