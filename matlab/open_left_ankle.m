function modelName = open_left_ankle(mode, rebuild)
%OPEN_LEFT_ANKLE Import the fixed left shank and two ankle joints into Simulink.
%   open_left_ankle                 Motion preview using the MAT trajectory.
%   open_left_ankle('torque')       Torque-input plant, initially zero torque.
%   open_left_ankle('motion', true) Rebuild the generated model from the URDF.
%
% Requires MATLAB, Simulink, Simscape and Simscape Multibody. Robotics System
% Toolbox is not needed: smimport reads the URDF directly.
% Motion preview prescribes ankle angles; it is not a torque controller or a
% model of the two parallel motor branches.

if nargin < 1
    mode = 'motion';
end
if nargin < 2
    rebuild = false;
end
mode = validatestring(mode, {'motion', 'torque'});
assert(~isempty(which('smimport')), 'left_ankle:MissingToolbox', ...
    'Install/enable Simulink, Simscape and Simscape Multibody to use smimport.');

rootDir = fileparts(mfilename('fullpath'));
addpath(rootDir);
addpath(fullfile(rootDir, 'meshes'));
reference = load_left_ankle_reference();
generatedDir = fullfile(rootDir, 'generated');
if ~isfolder(generatedDir)
    mkdir(generatedDir);
end
modelName = ['RD02_left_ankle_' mode];
modelFile = fullfile(generatedDir, [modelName '.slx']);

if rebuild && bdIsLoaded(modelName)
    error('left_ankle:ModelOpen', ...
        'Close %s first, saving any changes, before rebuilding it.', modelName);
end
if rebuild || ~isfile(modelFile)
    buildModel(rootDir, generatedDir, modelName, modelFile, mode, reference);
elseif ~bdIsLoaded(modelName)
    load_system(modelFile);
end

open_system(modelName);
set_param(modelName, 'SimulationCommand', 'update');
fprintf('Opened %s\nGravity: [0 0 -9.81] m/s^2; fixed shank.\n', modelFile);
if strcmp(mode, 'motion')
    fprintf('Press Run to preview the 20 s pitch/roll reference.\n');
else
    fprintf(['Torque inputs: ankle_pitch_torque_input / ankle_roll_torque_input, ', ...
        'each [time, torque_Nm].\n']);
    fprintf('Zero torque lets gravity move the foot; no stabilizing controller is installed.\n');
end
end

function buildModel(rootDir, generatedDir, modelName, modelFile, mode, reference)
% Resolve local mesh paths before importing, independent of MATLAB's pwd.
sourceUrdf = fullfile(rootDir, 'urdf', 'RD02_left_ankle.urdf');
resolvedUrdf = fullfile(generatedDir, 'RD02_left_ankle_resolved.urdf');
document = xmlread(sourceUrdf);
meshes = document.getElementsByTagName('mesh');
for k = 0:meshes.getLength()-1
    mesh = meshes.item(k);
    relativeName = char(mesh.getAttribute('filename'));
    meshFile = fullfile(fileparts(sourceUrdf), strrep(relativeName, '/', filesep));
    assert(isfile(meshFile), 'left_ankle:MissingMesh', 'Missing mesh: %s', meshFile);
    fileId = fopen(meshFile, 'rb');
    assert(fileId >= 0, 'left_ankle:MeshRead', 'Cannot read mesh: %s', meshFile);
    header = char(fread(fileId, 64, '*uint8').');
    fclose(fileId);
    assert(~startsWith(header, 'version https://git-lfs.github.com/spec/v1'), ...
        'left_ankle:LfsPointer', 'Mesh is a Git LFS pointer; run git lfs pull: %s', meshFile);
    mesh.setAttribute('filename', strrep(meshFile, filesep, '/'));
end
xmlwrite(resolvedUrdf, document);

previousDir = pwd;
restoreDir = onCleanup(@() cd(previousDir));
cd(generatedDir);
load_system('sm_lib');
load_system('nesl_utility');
smimport(resolvedUrdf, 'ModelName', modelName);
set_param(modelName, 'Solver', 'ode15s', 'MaxStep', '0.005', ...
    'RelTol', '1e-5', 'AbsTol', '1e-7', ...
    'StopTime', num2str(reference.t(end)), 'ReturnWorkspaceOutputs', 'on');

% A generated SLX can also be reopened directly: reload its reference data.
quotedRoot = strrep(rootDir, '''', '''''');
set_param(modelName, 'PostLoadFcn', sprintf( ...
    'addpath(''%s''); load_left_ankle_reference();', quotedRoot));

blocks = find_system(modelName, 'SearchDepth', 1, 'Type', 'Block');
gravityBlocks = {};
for k = 1:numel(blocks)
    parameters = get_param(blocks{k}, 'DialogParameters');
    if isfield(parameters, 'GravityVector')
        gravityBlocks{end+1} = blocks{k}; %#ok<AGROW>
    end
end
assert(numel(gravityBlocks) == 1, 'left_ankle:GravityBlock', ...
    'Expected exactly one imported Mechanism Configuration block.');
set_param(gravityBlocks{1}, 'UniformGravity', 'Constant', ...
    'GravityVector', '[0 0 -9.81]', 'GravityVectorUnits', 'm/s^2');

jointNames = {'left_ankle_pitch_joint', 'left_ankle_roll_joint'};
axesNames = {'pitch', 'roll'};
for k = 1:2
    matches = find_system(modelName, 'SearchDepth', 1, 'Name', jointNames{k});
    assert(numel(matches) == 1, 'left_ankle:JointBlock', ...
        'Expected one top-level joint named %s.', jointNames{k});
    joint = matches{1};
    setJointParameter(joint, 'SensePosition', 'on');
    setJointParameter(joint, 'SenseVelocity', 'on');
    setJointParameter(joint, 'SenseAcceleration', 'off');
    setJointParameter(joint, 'SenseTorqueForce', 'off');
    setJointParameter(joint, 'PositionTargetSpecify', 'on');
    setJointParameter(joint, 'PositionTargetValue', '0');
    setJointParameter(joint, 'PositionTargetValueUnits', 'rad');
    setJointParameter(joint, 'VelocityTargetSpecify', 'on');
    setJointParameter(joint, 'VelocityTargetValue', '0');
    setJointParameter(joint, 'VelocityTargetValueUnits', 'rad/s');
    if strcmp(mode, 'motion')
        setJointParameter(joint, 'TorqueActuationMode', 'ComputedTorque');
        setJointParameter(joint, 'MotionActuationMode', 'InputMotion');
    else
        setJointParameter(joint, 'MotionActuationMode', 'ComputedMotion');
        setJointParameter(joint, 'TorqueActuationMode', 'InputTorque');
    end

    ports = get_param(joint, 'PortHandles');
    assert(numel(ports.LConn) == 2 && numel(ports.RConn) == 3, ...
        'left_ankle:JointPorts', ...
        'Unexpected joint ports on %s; expected B/input and F/q/w.', joint);
    addActuation(modelName, axesNames{k}, mode, ports.LConn(2), k);
    addMeasurement(modelName, axesNames{k}, 'position', 'rad', ports.RConn(2), k);
    addMeasurement(modelName, axesNames{k}, 'velocity', 'rad/s', ports.RConn(3), k);
end

Simulink.BlockDiagram.arrangeSystem(modelName);
save_system(modelName, modelFile);
clear restoreDir;
end

function setJointParameter(joint, name, value)
% Revolute Joint versions use either unprefixed or Rz-prefixed mask names.
parameters = get_param(joint, 'DialogParameters');
if isfield(parameters, name)
    set_param(joint, name, value);
elseif isfield(parameters, ['Rz' name])
    set_param(joint, ['Rz' name], value);
else
    error('left_ankle:JointParameter', ...
        'Joint block %s does not expose parameter %s.', joint, name);
end
end

function addActuation(model, axisName, mode, jointInput, index)
prefix = ['ankle_' axisName];
converter = [model '/' axisName '_input_to_PS'];
add_block(sprintf('nesl_utility/Simulink-PS\nConverter'), converter, ...
    'Position', [300 100+240*index 360 140+240*index]);
if strcmp(mode, 'motion')
    % Supply angle, velocity and acceleration explicitly; no derivative filter.
    set_param(converter, 'Unit', 'rad', 'FilteringAndDerivatives', 'provide', ...
        'UdotUserProvided', '2');
    suffixes = {'position_ref', 'velocity_ref', 'acceleration_ref'};
else
    set_param(converter, 'Unit', 'N*m', 'FilteringAndDerivatives', 'provide', ...
        'UdotUserProvided', '0');
    suffixes = {'torque_input'};
end
converterPorts = get_param(converter, 'PortHandles');
assert(numel(converterPorts.Inport) == numel(suffixes), ...
    'left_ankle:ConverterPorts', 'Unexpected derivative inputs on %s.', converter);
for j = 1:numel(suffixes)
    source = [model '/' axisName '_' suffixes{j}];
    add_block('simulink/Sources/From Workspace', source, ...
        'VariableName', [prefix '_' suffixes{j}], 'Interpolate', 'on', ...
        'Position', [30 70+240*index+50*j 230 100+240*index+50*j]);
    sourcePorts = get_param(source, 'PortHandles');
    add_line(model, sourcePorts.Outport(1), converterPorts.Inport(j), 'autorouting', 'on');
end
add_line(model, converterPorts.RConn(1), jointInput, 'autorouting', 'on');
end

function addMeasurement(model, axisName, quantity, unit, jointOutput, index)
converter = [model '/' axisName '_' quantity '_to_Simulink'];
add_block(sprintf('nesl_utility/PS-Simulink\nConverter'), converter, ...
    'Unit', unit, 'Position', [900 100+240*index 960 140+240*index]);
sink = [model '/' axisName '_' quantity '_log'];
add_block('simulink/Sinks/To Workspace', sink, ...
    'VariableName', ['ankle_' axisName '_' quantity '_measured'], ...
    'SaveFormat', 'Timeseries', 'Position', [1050 100+240*index 1250 140+240*index]);
converterPorts = get_param(converter, 'PortHandles');
sinkPorts = get_param(sink, 'PortHandles');
add_line(model, jointOutput, converterPorts.LConn(1), 'autorouting', 'on');
add_line(model, converterPorts.Outport(1), sinkPorts.Inport(1), 'autorouting', 'on');
end
