# RD02 robot description

Package ROS 2 Humble `vd_robot_description`, dùng `ament_cmake`. Source package
nằm ngay tại thư mục gốc `quang_ws`, không cần chuyển các asset sang `src/`.

## Build và mở RViz

Các file STL và USD được lưu bằng Git LFS. Cần tải dữ liệu thật trước khi build;
file con trỏ LFS chỉ chứa văn bản và sẽ khiến RViz báo STL `malformed`.

```bash
cd /home/minh/quang_ws
git lfs pull
source /opt/ros/humble/setup.bash
colcon build --symlink-install --packages-select vd_robot_description
source install/setup.bash
ros2 launch vd_robot_description rviz.launch.py
```

Launch chạy `robot_state_publisher`, `joint_state_publisher_gui` và `rviz2`.
RViz nạp sẵn mô hình robot với fixed frame `pelvis_link`; bảng GUI cho phép chỉnh
27 khớp. Đây là hiển thị động học, không phải mô phỏng vật lý.

Tắt bảng chỉnh khớp và dùng trạng thái khớp mặc định:

```bash
ros2 launch vd_robot_description rviz.launch.py gui:=false
```

Chạy các publisher mà không mở cửa sổ:

```bash
ros2 launch vd_robot_description rviz.launch.py gui:=false rviz:=false
```

## Asset

- `description/urdf/RD02.urdf`: mô hình dùng cho RViz, giữ nguyên các URI `package://`.
- `description/urdf/RD02_training.urdf`: cùng mô hình, dùng đường dẫn mesh tương đối.
- `description/meshes/`: mesh hình học và convex hull.
- `description/original_meshes/`: mesh gốc, dùng làm tài liệu nguồn, không cài vào package.
- `description/xml/scene.xml`: cảnh MuJoCo.
- `description/usd/`: mô hình USD.
- `description/launch/`: launch ROS 2 và cấu hình RViz.

Các file mô hình, launch và cấu hình RViz nằm trong `description/`;
`package.xml` và `CMakeLists.txt` nằm ở thư mục gốc package. Khi build,
launch được cài vào `share/vd_robot_description/launch/`, còn các asset được cài
vào `share/vd_robot_description/robots/RD02/` để khớp URI sẵn có trong URDF.

## MATLAB / Simulink cho cổ chân trái

Thư mục [`matlab/`](matlab/README.md) có URDF rút gọn từ cẳng chân trái xuống
bàn chân, ba mesh STL và quỹ đạo pitch–roll `.mat` dài 20 giây.
Cẳng chân được cố định theo phương trọng lực; chỉ hai khớp cổ chân chuyển động.

Trong MATLAB có Simulink, Simscape và Simscape Multibody:

```matlab
cd('/home/minh/quang_ws/matlab')
open_left_ankle
```

Script sinh model `.slx` xem chuyển động theo quỹ đạo. Dùng
`open_left_ankle('torque')` để mở model riêng nhận torque trực tiếp tại hai khớp.
Đây là mô hình pitch–roll từ URDF, chưa gồm các nhánh dẫn động song song M1/M2.
