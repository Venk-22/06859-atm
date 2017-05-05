function[]= VSLControl(runNumber, mainlineDemand, bottleneckSpeed)
%VSLControl   Function to create a connection with VISSIM using
%COM interface and run the microsimulation for the scheduled time.

% Inputs:
% runNumber: The unique value for the current run
% mainlineDemand: demand entering the mainline in veh/hr
% bottleneckSpeed: speed of the downstream end in km/hr
    
    clearvars -except runNumber mainlineDemand rampDemand bottleneckSpeed
    clear functions
    newSeed=53+runNumber;

    % load network file
    proj_name='vslTestBed.inpx'
    dir_name=mfilename('fullpath');
    dir_name=dir_name(1:end-length(mfilename));
    file_load=strcat(dir_name,proj_name);

    % get function handle
    vissim=actxserver('VISSIM.vissim.600');
    vissim.LoadNet(file_load);
    vissim_sim=vissim.Simulation;
    vissim_eval=vissim.Evaluation;
    vissim_net=vissim.net;

    % overwrite the previous results if it is the first run; else continue
    % saving the results from this iteration in new files
    if runNumber==1
        vissim_eval.set('AttValue','DelPrevRes','true');
    else
        vissim_eval.set('AttValue','DelPrevRes','false');
    end
    
    % run simulation & control & evaluation
    time_duration=3599; % second
    
    vissim_sim.set('AttValue','RandSeed',num2str(newSeed));
    sim_resolution=vissim_sim.set('AttValue','SimRes','1');
    sim_resolution=vissim_sim.get('AttValue','SimRes');
    sim_steps=time_duration*sim_resolution;
    dt=300; % Control cycle
    control_steps=(time_duration)/dt;

    % get VSL handle
    VSL_set=vissim_net.ReducedSpeedAreas.GetAll;
    numVSL=length(VSL_set);

    spd_set={'5' '12' '15' '20' '25' '30' '40' '50' '60' '70' '80' '85' '90' '100' '120' '130' '140'};
    Vmin=str2num(spd_set{1});
    Vmax=str2num(spd_set{end});

    %Set input demand for mainline
    num_interval=4;
    InFlow1=vissim.net.VehicleInputs.GetAll{1}; % inflow at mainline
    for i=1:num_interval-1
        InFlow1.set('AttValue',['Volume(' num2str(i) ')'],num2str(mainlineDemand));    
    end
    %zero demand in the last timeinterval for clearing out the traffic
    InFlow1.set('AttValue',['Volume(' num2str(num_interval) ')'],num2str(0));

    %set bottleneck speed
    desiredSpeedDist = vissim_net.DesSpeedDecisions.GetAll;
    decisionPoint1= desiredSpeedDist{1}.VehClassDesSpeedDistr.GetAll;
    decisionPoint2= desiredSpeedDist{2}.VehClassDesSpeedDistr.GetAll;
    decisionPoint3= desiredSpeedDist{3}.VehClassDesSpeedDistr.GetAll;

    decisionPoint1{1}.set('AttValue','DesSpeedDistr',num2str(bottleneckSpeed)); %Cars
    decisionPoint1{2}.set('AttValue','DesSpeedDistr',num2str(bottleneckSpeed)); %Trucks
    decisionPoint2{1}.set('AttValue','DesSpeedDistr',num2str(bottleneckSpeed));
    decisionPoint2{2}.set('AttValue','DesSpeedDistr',num2str(bottleneckSpeed));
    decisionPoint3{1}.set('AttValue','DesSpeedDistr',num2str(bottleneckSpeed));
    decisionPoint3{2}.set('AttValue','DesSpeedDistr',num2str(bottleneckSpeed));
    
    % get all meters and detectors
    detector_set=vissim.net.Detectors.GetAll;

    detector1=detector_set{1}; % vsl
    detector2=detector_set{2}; % vsl
    detector3=detector_set{3}; % vsl

    inputemu('key_win','m');
    
    vehclass_set=vissim.net.VehicleClasses.GetAll; % all vehicle classes
    vehclass_No=[];
    vehclass_Str='';
    len_vehclass=length(vehclass_set);

    for i=1:len_vehclass
        vehclass_No=[vehclass_No vehclass_set{i}.get('AttValue','No')];
        vehclass_Str=strcat(vehclass_Str,',',num2str(vehclass_set{i}.get('AttValue','No')));
    end

    vehclass_Str=vehclass_Str(2:end);

    % save data (green ratio)
    occ_Rec=[];
    occ_Avg=0;

    speed_Rec=[];
    speed_Avg=0;

    vol_Rec=[];
    vol_Avg=0;

    vsl_Rec=[];
    %vissim_sim.RunSingleStep;


    for i=1:control_steps

        real_time=vissim_sim.SimulationSecond;

        % the control cycle

        if (occ_Avg<0.20)
            DesSpeedCat=100;
        elseif occ_Avg<0.50 % km/hour
            DesSpeedCat=80;
        elseif occ_Avg<0.75;
            DesSpeedCat=60
        else
            DesSpeedCat=40;
        end

        vsl_Rec=[vsl_Rec DesSpeedCat];

        display(num2str([real_time occ_Avg speed_Avg vol_Avg DesSpeedCat]))

        for p=1:numVSL
            VSL_set{p}.VehClassSpeedRed.GetAll{1}.set('AttValue','DesSpeedDistr',DesSpeedCat);
            VSL_set{p}.VehClassSpeedRed.GetAll{2}.set('AttValue','DesSpeedDistr',DesSpeedCat);
        end

        display(real_time)

        for j=1:(dt*sim_resolution)

            vissim_sim.RunSingleStep;
            real_time=vissim_sim.SimulationSecond;

            occupancy_estimate1=detector1.AttValue('Occuprate');
            speed_estimate1=detector1.AttValue('VehSpeed');
            vol_estimate1=detector1.AttValue('VehNo');
            
            occupancy_estimate2=detector2.AttValue('Occuprate');
            speed_estimate2=detector2.AttValue('VehSpeed');
            vol_estimate2=detector2.AttValue('VehNo');
            
            occupancy_estimate3=detector3.AttValue('Occuprate');
            speed_estimate3=detector3.AttValue('VehSpeed');
            vol_estimate3=detector3.AttValue('VehNo');
            
            
            occ_Rec=[occ_Rec (occupancy_estimate1+occupancy_estimate2+occupancy_estimate3)/3];
            speed_Rec=[speed_Rec (speed_estimate1+speed_estimate2+speed_estimate3)/3];
            vol_Rec=[vol_Rec (vol_estimate1>0)+(vol_estimate2>0)+(vol_estimate3>0)];
            %VehNo is more than zero everytime a vehicle is present on the
            %detector and thus counting this number for every second gives
            %us the flow/volume

        end

        occ_Avg=mean(occ_Rec(1:end));
        occ_Rec=[];

        speed_Avg=mean(speed_Rec(speed_Rec>0));
        speed_Rec=[];

        vol_Avg=(3600/dt)*sum(vol_Rec(vol_Rec>0));
        vol_Rec=[];


    end
    vsl_Rec= vsl_Rec';
    save(strcat('VSLOutput_Run',num2str(runNumber),'.att'),'vsl_Rec','-ascii')

    vissim.release
end