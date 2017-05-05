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
    vissim=actxserver('VISSIM.vissim.600');%change to VISSIM.vissim.700 for VISSIM 7.0 COM interface
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
    occ_des1=0.4; % range 0.1-0.4

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
    inputemu('key_win','m');
    detector_set=vissim.net.Detectors.GetAll;
    detector1=detector_set{1}; % detector on mainline for ramp meter
    detector2=detector_set{2};
    detector3=detector_set{3};
    
    queuecounter_set=vissim.net.QueueCounters.GetAll;
    queuecounter_Ramp2=queuecounter_set{1}; % onramp 2
    queueTimeID=0; %used to access the queue counter records
    queueEvaluationStep=5; %seconds; set in the VISSIM file
    


    meter_set=vissim.net.SignalControllers.GetAll;
    meter1=meter_set{1}.SGs.ItemByKey(1); % ramp meter
    
    % save data
    rec_gr1=[]; %green ratios
    prevOccupancy1=0; %previous occupancy reading
    prevFlow1=0; %previous flow reading
    occDes_record=[occ_des1];
    
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

        actualGreenRatio1=0;
        storeOccupancy1=[];
        flow1=0;
        
        for j=1:(dt*sim_resolution)
            vissim_sim.RunSingleStep;
            real_time=vissim_sim.SimulationSecond;

            queueTimeID= ceil(real_time/queueEvaluationStep);
            QL1=queuecounter_Ramp2.AttValue(strcat('QLenMax(Current,',num2str(queueTimeID),')'));
        
            %242 is the maximum queue length
            if j>green_length1 && QL1<242
                meter_value1=meter1.set('AttValue','State','RED');
            else
                meter_value1=meter1.set('AttValue','State','GREEN');
                actualGreenRatio1=actualGreenRatio1+1;
            end
            
            if j> (dt*sim_resolution/2)
               %record occupancy readings for the last half of control step
               storeOccupancy1=[storeOccupancy1;  (detector1.AttValue('Occuprate')+detector2.AttValue('Occuprate')+detector3.AttValue('Occuprate'))/3];
               flow1 = flow1+ detector1.AttValue('Impulse')+detector2.AttValue('Impulse')+detector3.AttValue('Impulse');
               
            end

        end

        flow1= flow1*3600/(dt*sim_resolution/2);
        actualGreenRatio1=actualGreenRatio1/dt;
        
        real_time=vissim_sim.SimulationSecond;
       
        % detection
        occupancy_estimate1=mean(storeOccupancy1);
        
        %Estimation of occ_des
        if abs(occ_des1-occupancy_estimate1)<=0.03
            deltaDerivative1= (flow1-prevFlow1)/(100*(occupancy_estimate1-prevOccupancy1))
            %no smoothing done
            if deltaDerivative1> 25
                occ_des1 = occ_des1+ 0.01;
            elseif deltaDerivative1< -10
                occ_des1 = occ_des1- 0.01;
            end
        end
        
        
        % metering algorithm
        meter_rate1=meter_rate1+K*(occ_des1-occupancy_estimate1);
        meter_rate1=min(ramp_flow_max,max(ramp_flow_min,meter_rate1)); % truncation interval
        green_ratio1=meter_rate1/ramp_flow_max; 
        green_length1=green_ratio1*dt*sim_resolution;
        
        rec_gr1=[rec_gr1 actualGreenRatio1];
        
        disp(num2str([real_time occupancy_estimate1 meter_rate1]))
        display(num2str([flow1 occupancy_estimate1]))
        display(num2str([occ_des1]))
        prevOccupancy1= occupancy_estimate1;
        if occupancy_estimate1==0 && flow1~=0
            pause; %some error!!
        end
        prevFlow1= flow1;
        occDes_record= [ occDes_record; occ_des1];

    end


    GRatio=[rec_gr1'];
    
    save(strcat('GreenRatio_Run',num2str(runNumber),'.att'),'GRatio','-ascii')
    save(strcat('OccDesired_',num2str(runNumber),'.att'),'occDes_record','-ascii')
   

    vissim.release
end