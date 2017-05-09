function[]= DLUCControlRamp(runNumber, mainlineDemand, rampDemand, bottleneckSpeed)
% I-35 ramp metering control

% ATM tests with VISSIM 6.0 COM interface

% Reading demand on mainline, put the number of intervals on which you will have
% flow, example 0-900,900-1800, etc. and the demand on each interval except
% the last one since considering that the last one will have zero demand so
% that the vehicles will leave the system.

%use MainCode instead of for loop to generate multiple runs


clearvars -except runNumber mainlineDemand rampDemand bottleneckSpeed
clear functions
newSeed=53+runNumber;

% load network file
proj_name='DLUCWithRamp.inpx'
dir_name=mfilename('fullpath');
dir_name=dir_name(1:end-length(mfilename));
file_load=strcat(dir_name,proj_name);

% get function handle
vissim=actxserver('VISSIM.vissim.600');
vissim.LoadNet(file_load);
vissim_sim=vissim.Simulation;
vissim_eval=vissim.Evaluation;
vissim_net=vissim.net;

if runNumber==1
    vissim_eval.set('AttValue','DelPrevRes','true'); %in hope that delPrevResult overwrites the past result
else
    vissim_eval.set('AttValue','DelPrevRes','false');
end

%run simulation & control & evaluation
time_duration=3599; % second

vissim_sim.set('AttValue','RandSeed',num2str(newSeed));

%Code I don't know what to use for:
sim_resolution=vissim_sim.set('AttValue','SimRes','1');
sim_resolution=vissim_sim.get('AttValue','SimRes');
%vissim_sim.set('AttValue','NumRuns','3');
sim_steps=time_duration*sim_resolution;

dt=600; % HSR time; the lane use control will work for this interval
control_steps=(time_duration+1)/dt; %Be careful to add +1 here, edit

%Setting the threshold occupancy on the ramp to be 40%
Thres_Occ=0.4;

%use inputemu if you want the code to run faster
inputemu('key_win','m');
num_interval=4;

InFlow1=vissim.net.VehicleInputs.GetAll{1}; % inflow at onramp
InFlow2=vissim.net.VehicleInputs.GetAll{2}; % inflow at mainline, yes they are flipped
for i=1:num_interval-1
    InFlow1.set('AttValue',['Volume(' num2str(i) ')'],num2str(rampDemand));
    InFlow2.set('AttValue',['Volume(' num2str(i) ')'],num2str(mainlineDemand)); %yes they are flipped
end
%zero demand in the last timeinterval for clearing out the traffic
InFlow1.set('AttValue',['Volume(' num2str(num_interval) ')'],num2str(0));
InFlow2.set('AttValue',['Volume(' num2str(num_interval) ')'],num2str(0));


% get all meters and detectors
detector_set=vissim.net.Detectors.GetAll;
detector1=detector_set{1}; % detector on the ramp
vehclass_set=vissim.net.VehicleClasses.GetAll; % all vehicle classes
vehclass_No=[];
vehclass_Str='';
len_vehclass=length(vehclass_set);

for i=1:len_vehclass
    vehclass_No=[vehclass_No vehclass_set{i}.get('AttValue','No')];
    vehclass_Str=strcat(vehclass_Str,',',num2str(vehclass_set{i}.get('AttValue','No')));
end

vehclass_Str=vehclass_Str(2:end);

link_set=vissim.net.Links.GetAll; % all links

% save data
%rec_HSR=[];

occ_Avg=0;%Used to measure the occupancy on the ramp
occ_Rec=[];
signstore=[];
occstore=[];

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


%More code I don't know what to use for:
%vissim_sim.RunSingleStep;

%The algorithm is used to close the lane if there is congestion on the
%ramp. Otherwise the lane is open for through traffic.

for i=1:control_steps

    real_time=vissim_sim.SimulationSecond;

    %Updates the lane behavior based on previous control step avg occupancy
    if occ_Avg>Thres_Occ %if average occupancy greater than threshold then close lane
        HSRsig=0;
        display(['lane - Closed at ' num2str(real_time) ' seconds; Average occupancy: ' num2str(occ_Avg)])
        %for k=1:length(link_set)
        temp_link1=link_set{7}; %select the lane of interest
        temp_link1.Lanes.GetAll{1}.set('AttValue','BlockedVehClasses',vehclass_Str); %block the vehicles of interest on rightmost lane
            %end
        %end
    else
        HSRsig=1;
        display(['lane - Open at ' num2str(real_time) ' seconds; Average occupancy: ' num2str(occ_Avg)])
        %for k=1:length(link_set)
        temp_link=link_set{7};
            %if length(temp_link.Lanes.GetAll)==4
        temp_link.Lanes.GetAll{1}.set('AttValue','BlockedVehClasses','60'); % block bike
            %end
        %end
    end
    %rec_HSR=[rec_HSR HSRsig];


    for j=1:(dt*sim_resolution)
        vissim_sim.RunSingleStep;
        real_time=vissim_sim.SimulationSecond;
        occupancy_estimate1=detector1.AttValue('Occuprate');
        occ_Rec=[occ_Rec occupancy_estimate1];
    end

    occ_Avg=mean(occ_Rec(end-180:end)); % take average in last 180 simulation steps or 3min
    occ_Rec=[];
    signstore=[signstore HSRsig];
    occstore=[occstore occ_Avg];

end
AllData=[occstore' signstore'];
save(strcat('DLUC_Run',num2str(runNumber),'.att'),'AllData','-ascii')
vissim.release
pause(20);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

end