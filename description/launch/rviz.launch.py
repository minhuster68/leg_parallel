"""Display the installed RD02 URDF in RViz with optional joint sliders.

Run after building and sourcing the package:
    ros2 launch vd_robot_description rviz.launch.py
"""

from pathlib import Path

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.conditions import IfCondition, UnlessCondition
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node
from launch_ros.parameter_descriptions import ParameterValue


def generate_launch_description():
    package_dir = Path(get_package_share_directory('vd_robot_description'))
    robot_dir = package_dir / 'robots' / 'RD02'
    robot_description = (robot_dir / 'urdf' / 'RD02.urdf').read_text(
        encoding='utf-8'
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
            arguments=['-d', str(package_dir / 'launch' / 'rd02.rviz')],
            condition=IfCondition(rviz),
        ),
    ])
