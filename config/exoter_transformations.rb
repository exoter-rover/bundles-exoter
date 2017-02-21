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
###
# Change LOG: 17-01-2017
# Authors: Moritz S. and Martin A.
# Changes: Addedd static transformations to front and rear loc cams. Also modified the transformation
# of PTU to Left Camera for the BB3 camera baseline (only translation change, no rotation change).
###
# BB2: Baseline: 12 cm
#      Height: 3.7 cm
#      Width: 4.75 cm
#
#      Coordinates of left lens from center of mounting point at housing (x in front direction):
#      (4.75/2, 6, 3.7/2) 
#      After rotation of 30 deg around y-axis:
#      (cos(30)*4.75/2 + sin(30)*3.7/2, 6, -sin(30)*4.75/2 + cos(30)*3.7/2)
#
#      30 deg = 0.52 rad
#      (2.99, 6, 0.415)

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

# Transformation PTU to Left camera bb3 (Left camera frame expressed in PTU frame) but transformer expects the other sense
static_transform Eigen::Quaternion.from_euler(Eigen::Vector3.new( -Math::PI/2.0, 0.00, -Math::PI/2.0), 2,1,0),
    Eigen::Vector3.new( 0.0, 0.120, 0.035 ), "left_camera_bb3" => "ptu"

# Transformation PTU to Left camera bb2 (Left camera frame expressed in PTU frame) but transformer expects the other sense
static_transform Eigen::Quaternion.from_euler(Eigen::Vector3.new( -Math::PI/2.0, 0.00, -Math::PI/2.0), 2,1,0),
    Eigen::Vector3.new( 0.0, 0.0602, 0.035 ), "left_camera_bb2" => "ptu"

# Transformation Body to Left camera bb2 front (Front Left camera frame expressed in Body frame) but transformer expects the other sense
static_transform Eigen::Quaternion.from_euler(Eigen::Vector3.new( -Math::PI/2.0, 0.00, -2.0*Math::PI/3.0), 2,1,0),
    Eigen::Vector3.new( 0.195, 0.06, 0.235 ), "left_camera_bb2_front" => "body"

# Transformation Body to Left camera bb2 back (Back Left camera frame expressed in Body frame) but transformer expects the other sense
static_transform Eigen::Quaternion.from_euler(Eigen::Vector3.new( Math::PI/2.0, 0.00, -2.0*Math::PI/3.0), 2,1,0),
    Eigen::Vector3.new( -0.245, -0.06, 0.235 ), "left_camera_bb2_back" => "body"

# Transformation Left camera to Right camera (Right camera frame expressed in Left camera frame) but transformer expects the other sense
static_transform Eigen::Quaternion.Identity(),
    Eigen::Vector3.new( 0.12, 0.0, 0.0 ), "right_camera_bb2" => "left_camera_bb2"

# Transformation Left camera to ToF camera (ToF camera frame expressed in Left camera frame) but transformer expects the other sense
#static_transform Eigen::Quaternion.from_euler(Eigen::Vector3.new( Math::PI/2.0, 0.00, Math::PI/2.0), 2,1,0),
static_transform Eigen::Quaternion.from_euler(Eigen::Vector3.new( Math::PI, 0.00, 0.00), 2,1,0),
    Eigen::Vector3.new( 0.0602, -0.0625, 0.026), "tof_camera" => "left_camera_bb2"

