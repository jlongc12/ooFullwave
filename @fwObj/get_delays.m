function delays = get_delays(obj,focus)

%  Retrieve time delay profile for elements
%
%  James Long 12/06/2018

rx_pos = obj.xdc.out(obj.xdc.on_elements,:);
if(any(isinf(focus)))
    delays=zeros(1,size(rx_pos,1));
else
    delays=sqrt((focus(1)-rx_pos(:,1)).^2+(focus(2)-rx_pos(:,3)).^2);
    if(focus(2)>0)
        delays = -delays;
    end
    delays=delays-min(delays);
end
delays = delays/obj.input_vars.c0;

end


