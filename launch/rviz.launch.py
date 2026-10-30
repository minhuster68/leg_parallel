"""Display the local RD02 URDF in RViz with optional joint sliders.

Run without building a ROS package:
    ros2 launch /home/minh/quang_ws/launch/rviz.launch.py
"""

from pathlib import Path

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.conditions import IfCondition, UnlessCondition
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node
from launch_ros.parameter_descriptions import ParameterValue


def generate_launch_description():
    launch_dir = Path(__file__).resolve().parent
    robot_dir = launch_dir.parent
    robot_description = (robot_dir / 'urdf' / 'RD02.urdf').read_text(
        encoding='utf-8'
    )
    # This folder is standalone, so resolve the original ROS package URI locally.
    robot_description = robot_description.replace(
        'package://vd_robot_description/robots/RD02/meshes/',
        (robot_dir / 'meshes').as_uri() + '/',
    )

    gui = LaunchConfiguration('gui')
    rviz = LaunchConfiguration('rviz')

    return LaunchDescription([
        DeclareLaunchArgument(
            'gui', default_value='true',
            description='Show sliders for the 27 movable joints.',
        ),
        DeclareLaunchArgument(
            'rviz', default_value='true',
            description='Start RViz with the RD02 display configuration.',
        ),
        Node(
            package='robot_state_publisher',
            executable='robot_state_publisher',
            name='robot_state_publisher',
            output='screen',
            parameters=[{
                'robot_description': ParameterValue(
                    robot_description, value_type=str
                ),
            }],
        ),
        Node(
            package='joint_state_publisher_gui',
            executable='joint_state_publisher_gui',
            name='joint_state_publisher_gui',
            output='screen',
            condition=IfCondition(gui),
        ),
        Node(
            package='joint_state_publisher',
            executable='joint_state_publisher',
            name='joint_state_publisher',
            output='screen',
            condition=UnlessCondition(gui),
        ),
        Node(
            package='rviz2',
            executable='rviz2',
            name='rviz2',
            output='screen',
            arguments=['-d', str(launch_dir / 'rd02.rviz')],
            condition=IfCondition(rviz),
        ),
    ])
