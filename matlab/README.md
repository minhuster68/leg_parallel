# Cẳng chân trái và bàn chân trong MATLAB / Simulink

Bộ file độc lập để import phần dưới gối trái vào Simscape Multibody, xem
chuyển động cổ chân và chuẩn bị plant nhận torque. Cần MATLAB, Simulink,
Simscape và Simscape Multibody. Chạy trực tiếp `smimport` nên không bắt buộc
Robotics System Toolbox.

## Mở và chạy bản xem chuyển động

Trong MATLAB Command Window:

```matlab
cd('/home/minh/quang_ws/matlab')
modelName = open_left_ankle;
```

Lần đầu, script sinh `generated/RD02_left_ankle_motion.slx`, kết nối quỹ đạo
từ MAT vào hai khớp, bật cảm biến góc/vận tốc, kiểm tra update và mở model.
Bấm **Run** để xem chuyển động 20 giây. Cửa sổ 3D nằm trong Multibody Explorer
(Mechanics Explorer ở các phiên bản cũ).

Ở chế độ `motion`, Motion = Provided by Input và Torque = Automatically
Computed. Vị trí, vận tốc và gia tốc được cấp đầy đủ qua Simulink-PS Converter.
Đây là bản xem chuyển động cưỡng bức, không phải bộ điều khiển torque/LQR.

Script giải đường dẫn mesh thành đường dẫn tuyệt đối trong URDF tạm dưới
`generated/`, nên Current Folder của MATLAB không ảnh hưởng tới việc tìm STL.
URDF nguồn trong `urdf/` vẫn dùng đường dẫn tương đối, có thể chuyển cả thư
mục `matlab/` sang máy khác.

Nếu dùng đường dẫn Windows, đổi dòng `cd` theo vị trí thư mục trên máy đó.

## Mở plant nhận torque

```matlab
modelName = open_left_ankle('torque');
```

Script sinh một model riêng: `generated/RD02_left_ankle_torque.slx`.
Hai khớp có Torque = Provided by Input, Motion = Automatically Computed.
Hai khối From Workspace nhận:

```matlab
% Mỗi ma trận có hai cột: [thời gian (s), torque (N*m)].
ankle_pitch_torque_input = [left_ankle_reference.t, ...
    zeros(size(left_ankle_reference.t))];
ankle_roll_torque_input = [left_ankle_reference.t, ...
    zeros(size(left_ankle_reference.t))];
```

Torque mặc định bằng 0: khi Run, bàn chân được tự do chuyển động do trọng lực
và các giới hạn khớp. Chưa có điều khiển bám hoặc bù trọng lực. Có thể thay
hai nguồn này bằng đầu ra controller trong Simulink.

Các torque ở đây tác động trực tiếp lên khớp pitch/roll của URDF. Chúng chưa
phải torque của hai động cơ M1/M2 trong cơ cấu song song. Mô hình hiện tại
chưa có hai tay quay, thanh truyền hoặc ánh xạ động học của hai động cơ đó.
Không đồng nhất hai góc URDF với q1/q2 của cơ cấu song song.

## Trạng thái và quỹ đạo

File `data/left_ankle_trajectory.mat` đã có sẵn, đọc bằng:

```matlab
reference = load('data/left_ankle_trajectory.mat');
plot(reference.t, reference.ankle_q * 180/pi)
grid on
xlabel('Time (s)')
ylabel('Angle (deg)')
legend('Pitch alpha', 'Roll beta')
```

| Biến | Kích thước | Ý nghĩa |
|---|---|---|
| `t` | 2001 x 1 | Thời gian 0 đến 20 s |
| `Ts` | 1 x 1 | Bước lấy mẫu 0.01 s |
| `ankle_q` | 2001 x 2 | Góc [pitch alpha, roll beta], rad |
| `ankle_qd` | 2001 x 2 | Vận tốc góc, rad/s |
| `ankle_qdd` | 2001 x 2 | Gia tốc góc, rad/s² |
| `joint_names` | 1 x 2 cell | Tên hai khớp URDF theo thứ tự cột |
| `gravity` | 1 x 3 | [0 0 -9.81], m/s², trong World |

Quỹ đạo giữ nguyên tư thế 0 trong 2 s đầu, sau đó lần lượt:
pitch +10°, về 0; roll +6°, về 0; phối hợp pitch -8° và roll -5°; về 0.
Mỗi đoạn chuyển tiếp dùng đa thức bậc 5; vận tốc và gia tốc bằng 0 tại các
mốc nối. Mọi góc nằm trong giới hạn URDF.

Để sinh lại MAT sau khi chỉnh các waypoint:

```matlab
make_left_ankle_trajectory;
load_left_ankle_reference;
```

`load_left_ankle_reference` đưa dữ liệu vào base workspace để các khối From
Workspace sử dụng. Nó giữ lại các biến torque đã tồn tại của người dùng.

Khi chạy bằng lệnh, có thể lấy các tín hiệu đo như sau:

```matlab
simOut = sim(modelName);
pitchMeasured = simOut.ankle_pitch_position_measured;
rollMeasured = simOut.ankle_roll_position_measured;
pitchVelocity = simOut.ankle_pitch_velocity_measured;
rollVelocity = simOut.ankle_roll_velocity_measured;
```

## URDF rút gọn và gá cố định

```text
world
  └─ world_to_left_shank (fixed)
      └─ left_knee_link             2.197 kg
          └─ left_ankle_pitch_joint (Y)
              └─ left_ankle_pitch_link  0.066 kg
                  └─ left_ankle_roll_joint (X)
                      └─ left_ankle_roll_link   0.677 kg
```

- Source: `../description/urdf/RD02.urdf`.
- Giữ nguyên cả ba khối `<inertial>`: khối lượng, tâm khối lượng và tensor
  quán tính; giữ nguyên gốc, trục và giới hạn hai khớp cổ chân.
- Bỏ toàn bộ phần trên gối, chân phải và các camera. Không có khớp gối động.
- Giữ nguyên khoảng lệch pitch → roll 25 mm.
- Gốc cẳng chân được cố định ở World [0, 0, 0.55] m.
- Vector từ gốc cẳng chân tới tâm pitch trong source là [0.01, 0, -0.315] m.
  Gá cố định xoay quanh Y một góc `atan2(0.01, 0.315)` ≈ 1.818303° để vector
  này hướng đúng -Z, song song và cùng chiều với trọng lực.
- Do gá này, góc 0 của các khớp vẫn là góc zero trong URDF, không phải một
  phép hiệu chỉnh để lòng bàn chân nằm ngang tuyệt đối trong World.
- Trọng lực của model được đặt rõ là [0, 0, -9.81] m/s²; không tạo mặt đất.
- Các thuộc tính `armature`, `friction` nằm trong `<limit>` của source là
  thuộc tính mở rộng, không thuộc URDF chuẩn; bản này bỏ chúng. Không tự
  thêm quán tính rotor/giảm tốc hoặc đổi tensor quán tính link.

Các mesh cần thiết đã được sao chép vào `meshes/` (3 file STL); không cần
package ROS hoặc source `install/setup.bash` khi mở trong MATLAB.

## Sinh lại model

Model đã có sẽ được mở lại để giữ các chỉnh sửa của bạn. Khi cần sinh lại
từ URDF/script, đóng model trước, lưu các thay đổi cần giữ, rồi chạy:

```matlab
open_left_ankle('motion', true)
% hoặc
open_left_ankle('torque', true)
```

`generated/` là thư mục sản phẩm sinh tại máy chạy MATLAB, không đưa vào Git.
Nếu chuyển thư mục sang máy khác, sinh lại model để cập nhật đường dẫn mesh.

Trong môi trường tạo bộ file này chưa có MATLAB, nên chưa chạy được
`smimport`, compile hoặc simulate model bằng Simulink. Script sẽ thực hiện
update model khi bạn mở; URDF, mesh và dữ liệu MAT được kiểm tra riêng.
