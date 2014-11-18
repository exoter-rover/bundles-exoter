############################
# Static transformations
############################
load_transformer_conf "#{ENV['AUTOPROJ_CURRENT_ROOT']}/bundles/exoter/config/exoter_transformations.rb"

############################
# Dynamic transformations
############################

# Transformation from Navigation to Body but transformer expected in the inverse sense
dynamic_transform "localization_frontend.world_osg_to_world_out", "world" => "world_osg"
#static_transform Eigen::Quaternion.Identity(),
#    Eigen::Vector3.new( 2.0, 0.0, 0.0 ), "world" => "world_osg"

# Transformation from Navigation to Body but transformer expected in the inverse sense
dynamic_transform "localization_frontend.world_to_navigation_out", "navigation" => "world"
#static_transform Eigen::Quaternion.Identity(),
#    Eigen::Vector3.new( 2.0, 0.0, 0.0 ), "navigation" => "world"

# Transformation from Navigation to Body but transformer expected in the inverse sense
dynamic_transform "localization_frontend.reference_pose_samples_out", "body" => "navigation"

# Transformation from mast to Pan and Tilt Unit but transformed expected in the inverse sense
dynamic_transform "ptu_control.mast_to_ptu_out", "ptu" => "mast"
#static_transform Eigen::Quaternion.Identity(),
#    Eigen::Vector3.new( 2.0, 0.0, 0.0 ), "ptu" => "mast"

pp self
