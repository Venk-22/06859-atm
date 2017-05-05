function[]= RMControl_simpleNet(runNumber, mainlineDemand, rampDemand, bottleneckSpeed)
%RMControl_simpleNet   Function to create a connection with VISSIM using
%COM interface and run the microsimulation for the scheduled time.
% Written by: Venktesh Pandey

% Inputs:
% runNumber: The unique value for the current run
% mainlineDemand: demand entering the mainline in veh/hr
% rampDemand: demand entering the on-ramp in veh/hr
% bottleneckSpeed: speed of the downstream end in km/hr

    clc
    
    clearvars -except runNumber mainlineDemand rampDemand bottleneckSpeed
    clear functions
    
    newSeed=53+runNumber;
    % load network file
    proj_name='simplermnetwork.inpx'
    dir_name=mfilename('fullpath');
    dir_name=dir_name(1:end-length(mfilename));
    file_load=strcat(dir_name,proj_name);

    % get function handle
    vissim=actxserver('VISSIM.vissim.600'); %change to VISSIM.vissim.700 for VISSIM 7.0 COM interface
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
    dt=120; % metering cycle length, 10-300
    control_steps=time_duration/dt;
    obs_num=0;
    ramp_capacity=1800; % assumed value
    ramp_flow_min=100; % truncated range
    ramp_flow_max=ramp_capacity;
    meter_rate1=ramp_flow_max;
    meter_rate2=ramp_flow_max;
    green_length1=0;
    green_length2=0;
    occupancy_estimate1=0;
    occupancy_estimate2=0;

    % ALINEA control parameters (may be calibrated)
    K=200; % range 10-300
    occ_des=0.2; % range 0.1-0.4

    % Initialize demand
    num_interval=4;

    InFlow1=vissim.net.VehicleInputs.GetAll{1}; % inflow at mainline
    InFlow2=vissim.net.VehicleInputs.GetAll{2}; % inflow at onramp
    for i=1:num_interval-1
        InFlow1.set('AttValue',['Volume(' num2str(i) ')'],num2str(mainlineDemand));
        InFlow2.set('AttValue',['Volume(' num2str(i) ')'],num2str(rampDemand));
    end
    %zero demand in the last timeinterval for clearing out the traffic
    InFlow1.set('AttValue',['Volume(' num2str(num_interval) ')'],num2str(0));
    InFlow2.set('AttValue',['Volume(' num2str(num_interval) ')'],num2str(0));

    % get all meters and detectors
    inputemu('key_win','m'); %minimizes all active screens for faster simulation
    detector_set=vissim.net.Detectors.GetAll;
    detector1=detector_set{1}; % detector on mainline for ramp meter
    detector2=detector_set{2};
    detector3=detector_set{3};

    meter_set=vissim.net.SignalControllers.GetAll;
    meter1=meter_set{1}.SGs.ItemByKey(1); % ramp meter

    % save data (green ratio)
    rec_gr1=[];

    %Initialize the downstream bottleneck speed for all vehicle classes on
    %all lanes
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

    % ALINEA control logic
    green_length1=0;

    for i=1:control_steps

        for j=1:(dt*sim_resolution)
            vissim_sim.RunSingleStep;
            real_time=vissim_sim.SimulationSecond;

            %Run one control step, each dt seconds long. Set the ramp meter
            %to green for first green_length1 seconds and keep it red
            %otherwise.
            if j<=green_length1
                meter_value1=meter1.set('AttValue','State','GREEN');
            else
                meter_value1=meter1.set('AttValue','State','RED');
            end

        end

        real_time=vissim_sim.SimulationSecond;

        % detection
        occupancy_estimate1=detector1.AttValue('Occuprate');
        occupancy_estimate2=detector2.AttValue('Occuprate');
        occupancy_estimate3=detector3.AttValue('Occuprate');

        avgOccupancy= (occupancy_estimate1+occupancy_estimate2+occupancy_estimate3)/3;

        % metering algorithm
        meter_rate1=meter_rate1+K*(occ_des-avgOccupancy);
        
        meter_rate1=min(ramp_flow_max,max(ramp_flow_min,meter_rate1)); % truncation interval
        
        green_ratio1=meter_rate1/ramp_flow_max; 
        
        green_length1=green_ratio1*dt*sim_resolution;

        rec_gr1=[rec_gr1 green_ratio1];

        disp(num2str([real_time avgOccupancy meter_rate1]))

    end

    GRatio=[rec_gr1'];
    
    save(strcat('GreenRatio_Run',num2str(runNumber),'.att'),'GRatio','-ascii')

    vissim.release
end