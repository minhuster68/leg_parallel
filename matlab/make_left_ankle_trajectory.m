function reference = make_left_ankle_trajectory(outputFile)
%MAKE_LEFT_ANKLE_TRAJECTORY Save a C2-continuous ankle reference in SI units.
% Columns are [URDF ankle pitch, URDF ankle roll], NOT parallel motor q1/q2.
% Each quintic segment starts and ends with zero velocity and acceleration.

rootDir = fileparts(mfilename('fullpath'));
if nargin < 1
    outputFile = fullfile(rootDir, 'data', 'left_ankle_trajectory.mat');
end

Ts = 0.01;
t = (0:2000).' * Ts;
waypoint_times = [0; 2; 5; 8; 11; 14; 17; 20];
waypoint_angles_deg = [0 0; 0 0; 10 0; 0 0; 0 6; 0 0; -8 -5; 0 0];
waypoints = waypoint_angles_deg * pi / 180;

ankle_q = zeros(numel(t), 2);
ankle_qd = zeros(size(ankle_q));
ankle_qdd = zeros(size(ankle_q));
for k = 1:numel(waypoint_times)-1
    duration = waypoint_times(k+1) - waypoint_times(k);
    selected = t >= waypoint_times(k) & t <= waypoint_times(k+1);
    s = (t(selected) - waypoint_times(k)) / duration;
    blend = 10*s.^3 - 15*s.^4 + 6*s.^5;
    blend_d = (30*s.^2 - 60*s.^3 + 30*s.^4) / duration;
    blend_dd = (60*s - 180*s.^2 + 120*s.^3) / duration^2;
    delta = waypoints(k+1,:) - waypoints(k,:);
    ankle_q(selected,:) = repmat(waypoints(k,:), sum(selected), 1) ...
        + blend * delta;
    ankle_qd(selected,:) = blend_d * delta;
    ankle_qdd(selected,:) = blend_dd * delta;
end

joint_names = {'left_ankle_pitch_joint', 'left_ankle_roll_joint'};
coordinate_names = {'pitch_alpha', 'roll_beta'};
angle_unit = 'rad';
time_unit = 's';
gravity = [0 0 -9.81];
shank_alignment_rpy = [0 atan2(0.01, 0.315) 0];
coordinate_note = ...
    'Columns are URDF ankle pitch and roll, not parallel motor q1/q2.';

outputDir = fileparts(outputFile);
if ~isempty(outputDir) && ~isfolder(outputDir)
    mkdir(outputDir);
end
save(outputFile, 't', 'Ts', 'ankle_q', 'ankle_qd', 'ankle_qdd', ...
    'joint_names', 'coordinate_names', 'angle_unit', 'time_unit', ...
    'waypoint_times', 'waypoint_angles_deg', 'gravity', ...
    'shank_alignment_rpy', 'coordinate_note', '-v7');
reference = load(outputFile);
fprintf('Saved %d samples over %.1f s: %s\n', numel(t), t(end), outputFile);
end
