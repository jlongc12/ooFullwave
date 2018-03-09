classdef fwObj < handle
    
    %  Create simulation object of class fwObj to perform Fullwave simulations
    %  (created by Gianmarco Pinton). Assumes path to Fullwave tools have
    %  already been added.
    %
    %  Initialization:
    %           obj = fwObj(varargin)
    %
    %  Optional parameters (default):
    %           f0              - Center frequency in MHz (1)
    %           c0              - Speed of sound in m/s (1540)
    %           td              - Time duration of simulation in s (40e-6)
    %           p0              - Pressure amplitude of transmit in Pa (1e5)
    %           ppw             - Spatial points per wavelength (15)
    %           cfl             - Courant-Friedrichs-Levi number (0.4)
    %           wY              - Lateral span of simulation in m (5e-2)
    %           wZ              - Depth of simulation in m (5e-2)
    %           rho             - Density in kg/m^3 (1000)
    %           atten           - Attenuation in dB/MHz/cm (0)
    %           bovera          - Non-linearity parameter (-2)
    %
    %  Return:
    %           obj             - Simulation object with properties:
    %                               input_vars:     Input variables
    %                               grid_vars:      Grid variables
    %                               field_maps:     Field maps (cmap, rhomap,
    %                                               attenmap, boveramap)
    %
    %  Methods:
    %           make_xdc        - Generate transducer properties based on
    %                             transducer type and focusing
    %
    %  James Long, 03/09/2018
    
    properties
        input_vars
        grid_vars
        field_maps
        
        xdc
        txrx_maps
    end
    
    methods
        
        %%% Initialization %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function obj = fwObj(varargin)
            
            p = inputParser;
            %%% Add defaults for optional requirements %%%%%%%%%%%%%%%%%%%%
            addOptional(p,'c0',1540)
            addOptional(p,'td',40e-6)
            addOptional(p,'p0',1e5)
            addOptional(p,'ppw',15)
            addOptional(p,'cfl',0.4)
            addOptional(p,'wY',10e-2)
            addOptional(p,'wZ',6e-2)
            addOptional(p,'rho',1000)
            addOptional(p,'atten',0)
            addOptional(p,'bovera',-2)
            addOptional(p,'f0',1)
            
            %%% Parse inputs and extract variables from p %%%%%%%%%%%%%%%%%
            p.parse(varargin{:})
            var_struct = p.Results;
            assignments = extract_struct(var_struct);
            for i = 1:length(assignments)
                eval(assignments{i})
            end
            
            %%% Grid size calculations %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            omega0 = 2*pi*f0*1e6;
            lambda = c0/omega0*2*pi;
            nY = round(wY/lambda*ppw);
            nZ = round(wZ/lambda*ppw);
            nT = round(td*c0/lambda*ppw/cfl);
            dY = c0/omega0*2*pi/ppw;
            dZ = c0/omega0*2*pi/ppw;
            dT = dY/c0*cfl;
            t_axis = 0:dT:(nT-1)*dT;
            z_axis = 0:dZ:(nZ-1)*dZ;
            y_axis = 0:dY:(nY-1)*dY; y_axis = y_axis - mean(y_axis);
            
            %%% Generate field maps %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            cmap = ones(nY,nZ)*c0;   % speed of sound map (m/s)
            rhomap = ones(nY,nZ)*rho; % density map (kg/m^3)
            attenmap = ones(nY,nZ)*atten;    % attenuation map (dB/MHz/cm)
            boveramap = ones(nY,nZ)*bovera;    % nonlinearity map
            
            %%% Package into structures %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            obj.input_vars = struct('c0',c0,...
                'td',td,...
                'p0',p0,...
                'ppw',ppw,...
                'cfl',cfl,...
                'wY',wY,...
                'wZ',wZ,...
                'rho',rho,...
                'atten',atten,...
                'bovera',bovera,...
                'f0',f0,...
                'omega0',omega0,...
                'lambda',lambda);
            
            obj.grid_vars = struct('nY',nY,...
                'nZ',nZ,...
                'nT',nT,...
                'dY',dY,...
                'dZ',dZ,...
                'dT',dT,...
                'y_axis',y_axis,...
                'z_axis',z_axis,...
                't_axis',t_axis);
            
            obj.field_maps = struct('cmap',cmap,...
                'rhomap',rhomap,...
                'attenmap',attenmap,...
                'boveramap',boveramap);
            
        end
        
        %%% Generate transducer related fields %%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function obj = make_xdc(obj, tx_params)
            
            %  Function to create transducer related fields
            %
            %  Calling:
            %           obj.make_xdc(tx_params)
            %
            %  Parameters:
            %           tx_params       - Structure of transmit parameters
            %                               name:   Transducer name
            %                               event:  Transmit event ('plane'
            %                                       or 'focused')
            %                               focus:  Focal position in [y,z]
            %                               theta:  Transmit steering angle
            
            obj.xdc = xdc_lib(tx_params.name);
            obj.xdc.inmap = zeros(size(obj.field_maps.cmap));
            obj.xdc.outmap = zeros(size(obj.field_maps.cmap));
            
            %%% Check if grid spacing if adequate for modeling %%%%%%%%%%%%
            if obj.grid_vars.dY > obj.xdc.pitch, error('Grid spacing is too small.'); end
            
            if strcmp(obj.xdc.type, 'curvilinear')
                dtheta = atand(obj.xdc.pitch/obj.xdc.r);
                span = 2*obj.xdc.r*sind((obj.xdc.n-1)*dtheta/2);
                
                y = -span/2:obj.grid_vars.dY:span/2;
                z = sqrt(obj.xdc.r^2.-y.^2); z = z-min(z);
                
                %%% Store xdc trace as figure handle %%%%%%%%%%%%%%%%%%%%%%
                obj.xdc.xdc_plot = figure;
                plot(y*1e3, z*1e3, 'linewidth', 2); axis('image','ij')
                xlabel('y (mm)'); ylabel('z (mm)'); title(obj.xdc.name);
                set(gcf, 'visible', 'off'); close all;
                
                %%% Calculate indices of xdc in space %%%%%%%%%%%%%%%%%%%%%
                [~,idx_y] = min(abs(obj.grid_vars.y_axis-y'));
                idx_y = find(idx_y ~= 1 & idx_y ~= length(y));
                [~,idx_z] = min(abs(obj.grid_vars.z_axis'-z));
                idx_z = idx_z(2:end-1);
                for i = 1:length(idx_y)
                    obj.xdc.inmap(idx_y(i),idx_z(i):idx_z(i)+3) = ones(4,1);
                    obj.xdc.outmap(idx_y(i),idx_z(i)+3) = 1;
                end
                obj.xdc.idx_y = idx_y; obj.xdc.idx_z = idx_z;
                obj.xdc.incoords = mapToCoords(obj.xdc.inmap);
                obj.xdc.outcoords = mapToCoords(obj.xdc.outmap);
                
                %%% Calculate delays and generate icmat %%%%%%%%%%%%%%%%%%%
                tfield = calc_tfield(obj, tx_params);
                ncycles = 2; % number of cycles in pulse
                dur = 2; % exponential drop-off of envelope;
                icvec1 = exp(-(1.05*tfield*obj.input_vars.omega0/(ncycles*pi)).^(2*dur))...
                    .*sin(tfield*obj.input_vars.omega0)*obj.input_vars.p0;
                icvec2 = exp(-(1.05*tfield*obj.input_vars.omega0/(ncycles*pi)).^(2*dur))...
                    .*sin((tfield-obj.grid_vars.dY/obj.input_vars.c0)*obj.input_vars.omega0)*obj.input_vars.p0;
                icvec3 = exp(-(1.05*tfield*obj.input_vars.omega0/(ncycles*pi)).^(2*dur))...
                    .*sin((tfield-2*obj.grid_vars.dY/obj.input_vars.c0)*obj.input_vars.omega0)*obj.input_vars.p0;
                icvec4 = exp(-(1.05*tfield*obj.input_vars.omega0/(ncycles*pi)).^(2*dur))...
                    .*sin((tfield-3*obj.grid_vars.dY/obj.input_vars.c0)*obj.input_vars.omega0)*obj.input_vars.p0;
                obj.xdc.icmat = [icvec1; icvec2; icvec3; icvec4];
  
            elseif strcmp(obj.xdc.type, 'linear')
                
            else
                error('Unsupported transducer type.')
            end
            
        end
        
    end
    
end