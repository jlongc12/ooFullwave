function obj = add_wall(obj, wall_name, offset, filt_size)

%  Function to add abdominal wall.
%
%  Calling:
%           obj.add_wall('r75hi')
%
%  Parameters:
%           wall_name           - String of wall name
%           offset              - Lateral offset from center (m)
%           filt_size           - Factor for Gaussian blurring (default: 12)
%
%  James Long, 04/16/2020

if ~exist('offset','var'); offset=0; end

dY = obj.grid_vars.dY;
dZ = obj.grid_vars.dZ;
if(obj.input_vars.v==1)
    [cwall, rhowall, attenwall, Bwall] = img2fieldFlatten(wall_name,dY,dZ,obj.input_vars.c0,obj.input_vars.rho);
    Bwall=-Bwall*obj.input_vars.rho*obj.input_vars.c0.^4;
else
    [cwall, rhowall, attenwall, Bwall] = img2fieldFlatten2(wall_name,dY,dZ);
end

if size(cwall,1) < obj.grid_vars.nY; error('Simulation width exceeds wall width.'); end
if size(cwall,2) > obj.grid_vars.nZ; error('Wall depth exceeds simulation depth.'); end

% Lateral offset %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
nY = obj.grid_vars.nY;
nW = size(cwall,1);
pad = round((nW-nY)/2);
offset = round(offset/obj.grid_vars.dY);
wall_select = (pad+1:pad+nY)+offset;

if any(wall_select < 1) || any(wall_select > nW); error('Offset exceeds wall width.'); end
cwall = cwall(wall_select,:);
rhowall = rhowall(wall_select,:);
attenwall = attenwall(wall_select,:);
Bwall = Bwall(wall_select,:);

% Apply Gaussian blur %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~exist('filt_size','var'); filt_size = 12; end
if filt_size ~= 0
    cwall = imgaussfilt(cwall,obj.input_vars.ppw/filt_size);
    rhowall = imgaussfilt(rhowall,obj.input_vars.ppw/filt_size);
    attenwall = imgaussfilt(attenwall,obj.input_vars.ppw/filt_size);
    Bwall = imgaussfilt(Bwall,obj.input_vars.ppw/filt_size);
end

% Add to field_maps structure %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
ind = 1:size(cwall,2);
ax = 2*obj.input_vars.ppw;
for i = 1:size(obj.xdc.inmap,1)
    int = find(obj.xdc.inmap(i,:)==1,1,'last');
    obj.field_maps.cmap(i,ind+ax+int) = cwall(i,:);
    obj.field_maps.rhomap(i,ind+ax+int) = rhowall(i,:);
    obj.field_maps.attenmap(i,ind+ax+int) = attenwall(i,:);
    if(obj.input_vars.v==1)
        obj.field_maps.boveramap(i,ind+ax+int) = (Bwall(i,:)-1)*2;
    elseif(obj.input_vars.v==2)
        obj.field_maps.Bmap(i,ind+ax+int) = Bwall(i,:);
    end
end

end