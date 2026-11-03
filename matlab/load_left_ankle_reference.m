function reference = load_left_ankle_reference()
%LOAD_LEFT_ANKLE_REFERENCE Load MAT data and publish Simulink input matrices.
% All input matrices use [time, scalar_value]. Angles are radians.
% Existing torque input variables are preserved, so reopening a model does
% not replace a user-supplied torque experiment with zero torque.

rootDir = fileparts(mfilename('fullpath'));
trajectoryFile = fullfile(rootDir, 'data', 'left_ankle_trajectory.mat');
if ~isfile(trajectoryFile)
    make_left_ankle_trajectory(trajectoryFile);
end
reference = load(trajectoryFile);
requiredFields = {'t', 'ankle_q', 'ankle_qd', 'ankle_qdd', 'gravity'};
for k = 1:numel(requiredFields)
    assert(isfield(reference, requiredFields{k}), ...
        'left_ankle:TrajectoryData', 'Missing MAT variable: %s', requiredFields{k});
end
reference.t = reference.t(:);
n = numel(reference.t);
assert(n > 1 && all(isfinite(reference.t)) && all(diff(reference.t) > 0), ...
    'left_ankle:TrajectoryTime', 'Time must be finite and strictly increasing.');
for field = {'ankle_q', 'ankle_qd', 'ankle_qdd'}
    values = reference.(field{1});
    assert(isequal(size(values), [n 2]) && all(isfinite(values(:))), ...
        'left_ankle:TrajectoryShape', '%s must be a finite N-by-2 matrix.', field{1});
end
assert(isequal(reference.gravity, [0 0 -9.81]), ...
    'left_ankle:Gravity', 'Expected gravity [0 0 -9.81] in world coordinates.');

assignin('base', 'left_ankle_reference', reference);
assignin('base', 'left_ankle_gravity', reference.gravity);
axesNames = {'pitch', 'roll'};
for k = 1:2
    prefix = ['ankle_' axesNames{k}];
    assignin('base', [prefix '_position_ref'], [reference.t reference.ankle_q(:,k)]);
    assignin('base', [prefix '_velocity_ref'], [reference.t reference.ankle_qd(:,k)]);
    assignin('base', [prefix '_acceleration_ref'], [reference.t reference.ankle_qdd(:,k)]);
    torqueName = [prefix '_torque_input'];
    if ~evalin('base', sprintf('exist(''%s'', ''var'')', torqueName))
        assignin('base', torqueName, [reference.t zeros(n,1)]);
    end
end
end
