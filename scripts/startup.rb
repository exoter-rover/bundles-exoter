# Roby/Bundles modelling tool. Therefore, it is hard code to the task
# of the RTT/Rock component framework

class Startup
    # Locomotion
    attr_accessor :platform_driver
    attr_accessor :read_joint_dispatcher
    attr_accessor :command_joint_dispatcher
    attr_accessor :locomotion_control
    attr_accessor :ptu_control

    # SLAM
    attr_accessor :localization_frontend
    attr_accessor :exoter_odometry
    attr_accessor :imu_stim300

    # Perception
    attr_accessor :camera_firewire
    attr_accessor :camera_bb2
    attr_accessor :camera_tof
    attr_accessor :colorize_pointcloud

    # Ground Truth
    attr_accessor :vicon


    attr_accessor :tasks

    def initialize()
        @tasks = []
    end

    def getTask(name)
        task = Orocos.name_service.get(name)
        @tasks << task
        task
    end

    def getContext(configuration)
        @configuration = configuration

        @platform_driver = Orocos.name_service.get 'platform_driver'
        @tasks << @platform_driver

        @read_joint_dispatcher = Orocos.name_service.get 'read_joint_dispatcher'
        @tasks << @read_joint_dispatcher

        @command_joint_dispatcher = Orocos.name_service.get 'command_joint_dispatcher'
        @tasks << @command_joint_dispatcher

        @locomotion_control = Orocos.name_service.get 'locomotion_control'
        @tasks << @locomotion_control

        @ptu_control = Orocos.name_service.get 'ptu_control'
        @tasks << @ptu_control

        @localization_frontend = Orocos.name_service.get 'localization_frontend'
        @tasks << @localization_frontend

        @exoter_odometry = Orocos.name_service.get 'exoter_odometry'
        @tasks << @exoter_odometry

        @imu_stim300 = Orocos.name_service.get 'imu_stim300'
        @tasks << @imu_stim300

        @camera_firewire = Orocos.name_service.get 'camera_firewire'
        @tasks << @camera_firewire

        @camera_bb2 = Orocos.name_service.get 'camera_bb2'
        @tasks << @camera_bb2

        @camera_tof = Orocos.name_service.get 'camera_tof'
        @tasks << @camera_tof

        @colorize_pointcloud= Orocos.name_service.get 'colorize_pointcloud'
        @tasks << @colorize_pointcloud

        if @configuration[:reference].casecmp("vicon").zero?
            @vicon = Orocos.name_service.get 'vicon'
            @tasks << @vicon
        end

        if @configuration[:reference].casecmp("gnss").zero?
            @gnss_trimble = Orocos.name_service.get 'gnss_trimble'
            @tasks << @gnss_trimble
        end


    end

    def setConfig()

        Orocos.conf.apply( @platform_driver, ['default'], :override => true)
        Orocos.conf.apply( @read_joint_dispatcher, ['reading'], :override => true)
        Orocos.conf.apply( @command_joint_dispatcher, ['commanding'], :override => true)
        Orocos.conf.apply( @locomotion_control, ['default'], :override => true)
        Orocos.conf.apply( @ptu_control, ['default'], :override => true)
        Orocos.conf.apply( @localization_frontend, ['default', 'hamming1hzsampling12hz'], :override => true)
        Orocos.conf.apply( @exoter_odometry, ['default', 'bessel50'], :override => true)
        @exoter_odometry.urdf_file = Bundles.find_file('data/odometry', 'exoter_odometry_model.urdf')

        Orocos.conf.apply( @imu_stim300, ['default','ExoTer','ESTEC','stim300_5g'], :override => true)
        Orocos.conf.apply( @camera_firewire, ['default'], :override => true)
        Orocos.conf.apply( @camera_bb2, ['default'], :override => true)
        Orocos.conf.apply( @camera_tof, ['default'], :override => true)
        Orocos.conf.apply( @colorize_pointcloud, ['default'], :override => true)

        if @configuration[:reference].casecmp("vicon").zero?
            Orocos.conf.apply( @vicon, ['default', 'exoter'], :override => true)
            @localization_frontend.reference_pose_samples_period = 0.01 # Vicon is normally at 100Hz
        end

        if @configuration[:reference].casecmp("gnss").zero?
            Orocos.conf.apply( @gnss_trimble, ['ExoTer', 'Netherlands', 'DECOS'], :override => true)
            @localization_frontend.reference_pose_samples_period = 0.1 # GNSS/GPS is normally at 10Hz
        end

        Bundles.transformer.setup(@localization_frontend)
        Bundles.transformer.setup(@exoter_odometry)
        Bundles.transformer.setup(@colorize_pointcloud)
    end

    def configure()
        @tasks.each do |i|
            i.configure()
        end
    end

    def start()
        @tasks.each do |i|
            i.start()
        end
    end

    def connectLocomotion()

        # Connect ports: platform_driver to read_joint_dispatcher
        @platform_driver.joints_readings.connect_to @read_joint_dispatcher.joints_readings

        # Connect ports: read_joint_dispatcher to locomotion_control
        @read_joint_dispatcher.motors_samples.connect_to @locomotion_control.joints_readings

        # Connect ports: locomotion_control to command_joint_dispatcher
        @locomotion_control.joints_commands.connect_to @command_joint_dispatcher.joints_commands

        # Connect ports: command_joint_dispatcher to platform_driver
        @command_joint_dispatcher.motors_commands.connect_to @platform_driver.joints_commands

        # Connect ports: read_joint_dispatcher to ptu_control
        @read_joint_dispatcher.ptu_samples.connect_to @ptu_control.ptu_samples

        # Connect ports: ptu_control to command_joint_dispatcher
        @ptu_control.ptu_commands_out.connect_to @command_joint_dispatcher.ptu_commands
    end

    def connectPerception()

        # Camera driver to camera bb2
        @camera_firewire.frame.connect_to @camera_bb2.frame_in

        # Camera bb2 to colorize pointcloud
        @camera_bb2.left_frame.connect_to @colorize_pointcloud.camera
        @localization_frontend.point_cloud_samples_out.connect_to @colorize_pointcloud.points
    end

    def connectSLAM()

        # Connect ports to the Front-End hub
        @read_joint_dispatcher.joints_samples.connect_to @localization_frontend.joints_samples
        @imu_stim300.orientation_samples_out.connect_to @localization_frontend.orientation_samples
        @imu_stim300.calibrated_sensors.connect_to @localization_frontend.inertial_samples

        if @configuration[:reference].casecmp("vicon").zero?
            @vicon.pose_samples.connect_to @localization_frontend.reference_pose_samples
        end

        if @configuration[:reference].casecmp("gnss").zero?
            @gnss_trimble.pose_samples.connect_to @localization_frontend.reference_pose_samples
        end


        @camera_tof.pointcloud.connect_to @localization_frontend.point_cloud_samples
        #@camera_bb2.left_frame.connect_to @localization_frontend.left_frame
        #@camera_bb2.right_frame.connect_to @localization_frontend.right_frame

        # Connect odometry ports
        @localization_frontend.joints_samples_out.connect_to @exoter_odometry.joints_samples
        @localization_frontend.orientation_samples_out.connect_to @exoter_odometry.orientation_samples

        # Connect port to the localization Back-End

    end

    def log_all()
        # Log all ports
        Orocos.log_all
    end

    # Log all the port in the task that are 
    def log_minimum_all()

        @platform_driver.log_all_ports
        @locomotion_control.log_all_ports
        @ptu_control.log_all_ports
        @read_joint_dispatcher.log_all_ports
        @command_joint_dispatcher.log_all_ports

        # Proprioceptive sensors
        @imu_stim300.log_all_ports

        # Ground truth
        if @configuration[:reference].casecmp("vicon").zero?
            @vicon.log_all_ports
        end

        if @configuration[:reference].casecmp("gnss").zero?
            @gnss_trimble.log_all_ports
        end
    end

    # Log all minimum port to be able to replay a ExoTeR test
    def log_nominal_all()

        # The minimum all logs
        self.log_minimum_all

        print "Waiting localization frontend is in state #{@localization_frontend.state}"

        # Wait until localization initialization
        @localization_frontend.wait_for_state(:RUNNING)

        puts " => #{@localization_frontend.state}"

        #Exteroceptive sensors
        @camera_firewire.log_all_ports
        @camera_tof.log_all_ports
    end

    def stop_ptu_to_safe_position()
        @ptu_control.stop
    end

    def stop()
        @tasks.reverse.each do |i|
            puts "Stopping task in state #{i.rtt_state}"
            if i.rtt_state == :RUNNING
                puts "Stopping task #{i.to_s}"
                i.stop()
            end

        end
    end

    def cleanup()
        @tasks.reverse.each do |i|
            puts "Cleaning-up task #{i.to_s}"
            i.cleanup()
        end
    end


end
