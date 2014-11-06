# Transformations for the ExoTer rover
# ############################################
## ESA - NPI
## Author: Javier Hidalgo Carrio
## Email: javier.hidalgo_carrio@dfki.de
## ###########################################
# The convention to follow is "frame1" => "frame2" means the base of frame2 is
# expressed in the base of frame1. Therefore Tbody_stim300 is expressing
# stim300_frame in body_frame. Keep in mind that if we have a vector in
# stim300_frame and we want to have it in body_frame.
# v_body = Tbody_stim300 v_stim300
#
# It first translates by the Vector3d and then rotates

############################
# Static transformations
############################

# Transformation Body to IMU (IMU frame expressed in Body frame) but transformer expects the other sense
static_transform Eigen::Quaternion.from_angle_axis(Math::PI, Eigen::Vector3.UnitZ),
    Eigen::Vector3.new( 0.00417, -0.0399, 0.0052 ), "imu" => "body"

# Transformation Body to Mast top (Mast top frame expressed in Body frame) but transformations expects the other sense
static_transform Eigen::Quaternion.Identity(),
    Eigen::Vector3.new( 0.076, 0.0, 0.63275 ), "mast" => "body"

# Transformation Body to GPS (GPS frame expressed in Body frame) but transformer expects the other sense
static_transform Eigen::Quaternion.Identity(),
    Eigen::Vector3.new( -0.1705, 0.0745, 0.2206 ), "gps" => "body"

# Transformation PTU to Left camera (Left camera frame expressed in PTU frame) but transformer expects the other sense
static_transform Eigen::Quaternion.from_euler(Eigen::Vector3.new( -Math::PI/2.0, 0.00, -Math::PI/2.0), 2,1,0),
    Eigen::Vector3.new( 0.0, 0.0602, 0.035 ), "left_camera" => "ptu"

# Transformation Left camera to Right camera (Right camera frame expressed in Left camera frame) but transformer expects the other sense
static_transform Eigen::Quaternion.Identity(),
    Eigen::Vector3.new( 0.12, 0.0, 0.0 ), "right_camera" => "left_camera"

# Transformation Left camera to ToF camera (ToF camera frame expressed in Left camera frame) but transformer expects the other sense
#static_transform Eigen::Quaternion.from_euler(Eigen::Vector3.new( Math::PI/2.0, 0.00, Math::PI/2.0), 2,1,0),
static_transform Eigen::Quaternion.from_euler(Eigen::Vector3.new( Math::PI, 0.00, 0.00), 2,1,0),
    Eigen::Vector3.new( 0.0602, -0.0625, 0.026), "tof_camera" => "left_camera"

