function obj = focus_linear(obj, focus, fc, fbw, excitation, bwr, tpe)

%  Function to create transmit related fields. Must call obj.make_xdc()
%  prior to use.
%
%  Calling:
%           obj.focus_linear(focus)
%
%  Parameters:
%           focus           - Focal point in [y z] (m)
%           fc              - Center frequency of transducer (Hz) [obj.input_vars.f0]
%           fbw             - Fractional bandwidth of transducer [0.8]
%           excitation      - Vector of excitation in time
%           bwr             - Fractional bandwidth reference level [-6 dB]
%           tpe             - Cutoff for trailing pulse envelope [-40 dB]
%
%  Returns:
%           obj.xdc.inmap   - Input map for initial conditions
%           obj.xdc.incoords- Paired coordinates of input and initial
%                             conditions
%           obj.xdc.icmat   - Initial condition matrix for wave form time
%                             trace
%           obj.xdc.out     - Element positions in [x y z] for beamforming
%           obj.xdc.delays  - Time delays on elements in transmit
%           obj.xdc.t0      - Time of first time index (s) for beamforming
%
%  James Long 12/06/2018

if ~exist('fc','var')||isempty(fc), fc = obj.input_vars.f0; end
if ~exist('fbw','var')||isempty(fbw), fbw = 0.8; end
if ~exist('bwr','var')||isempty(bwr), bwr=-6; end
if ~exist('tpe','var')||isempty(tpe), tpe=-40; end
assert(strcmp(obj.xdc.type, 'linear'),'Transducer must be defined as linear.')
    
%%% Initialize in/outmap and in/outcoords %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
layers = 3;
obj.xdc.inmap(:,1:layers) = 1;
obj.xdc.incoords = mapToCoords(obj.xdc.inmap);
obj.xdc.outmap = zeros(size(obj.xdc.inmap));
obj.xdc.outmap(:,layers) = 1;
obj.xdc.outcoords = mapToCoords(obj.xdc.outmap);
obj.grid_vars.z_axis = obj.grid_vars.z_axis-(layers-1)*obj.grid_vars.dZ;

%%% Calculate impulse response and transmitted pulse %%%%%%%%%%%%%%%%%%%%%%
fy = (focus(1)-obj.grid_vars.y_axis(1))/obj.grid_vars.dY+1;
fz = (focus(2)-obj.grid_vars.z_axis(1))/obj.grid_vars.dZ+1;

tc = gauspuls('cutoff',fc,fbw,bwr,tpe);
fs=1/obj.grid_vars.dT;
tv = -tc:1/fs:tc;
impulse_response = gauspuls(tv,fc,fbw);
impulse_response = impulse_response-mean(impulse_response);
obj.xdc.impulse_t = tv;
obj.xdc.impulse = impulse_response;

if ~exist('excitation','var')||isempty(excitation)
    excitation = sin(2*pi*obj.input_vars.f0*(0:1/fs:obj.input_vars.ncycles/obj.input_vars.f0));
end
pulse = conv(impulse_response,excitation);
pulse = pulse/max(abs(pulse));
obj.xdc.pulse_t = (0:length(pulse)-1)/fs;
obj.xdc.pulse = pulse;
obj.xdc.excitation_t = (0:length(excitation)-1)/fs;
obj.xdc.excitation = excitation;

%%% Call focus_transmit to focus transmit beam %%%%%%%%%%%%%%%%%%%%%%%%%%%%
coord_row = 1:size(obj.xdc.incoords,1)/3;
t = (0:obj.grid_vars.nT-1)/obj.grid_vars.nT*obj.input_vars.td-obj.input_vars.ncycles/obj.input_vars.omega0*2*pi;
icvec = zeros(size(obj.grid_vars.t_axis));
icvec(1:length(pulse)) = pulse*obj.input_vars.p0;
icmat = average_icmat(obj,focus_transmit(obj,fy,fz,icvec,obj.xdc.incoords(coord_row,:)));

coord_row = size(obj.xdc.incoords,1)/3+1:2*size(obj.xdc.incoords,1)/3;
tnew=t-obj.grid_vars.dT/obj.input_vars.cfl;
icvec = interp1(t,icvec,tnew,[],0);
icmat_add = average_icmat(obj,focus_transmit(obj,fy,fz,icvec,obj.xdc.incoords(coord_row,:)));
icmat = [icmat; icmat_add];

coord_row = 2*size(obj.xdc.incoords,1)/3+1:size(obj.xdc.incoords,1);
tneww=tnew-obj.grid_vars.dT/obj.input_vars.cfl;
icvec = interp1(tnew,icvec,tneww,[],0);
icmat_add = average_icmat(obj,focus_transmit(obj,fy,fz,icvec,obj.xdc.incoords(coord_row,:)));
obj.xdc.icmat = [icmat; icmat_add];

obj.xdc.out = zeros(obj.xdc.n,3);
for i=1:obj.xdc.n
    obj.xdc.out(i,1) = mean(obj.grid_vars.y_axis(obj.xdc.e_ind(i,1):obj.xdc.e_ind(i,2)));    
end
obj.xdc.delays=get_delays(obj,focus);
obj.xdc.t0 = -(obj.input_vars.ncycles/obj.input_vars.omega0*2*pi);

end