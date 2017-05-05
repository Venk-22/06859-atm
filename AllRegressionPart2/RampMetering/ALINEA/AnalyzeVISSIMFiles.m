%This Matlab file analyzes the output written for different input
%combination and compiles them together into a single file. It analyzes the
%queueLength and travel time files written at the third iteration and uses
%the average simulation result as the output data point
clc;
clear;

accumulatedGR=[]; %stores all results for each input combination in a row.
currentFolder= pwd;

for runCount=1:48
    fileLocation=strcat(currentFolder,'\',num2str(runCount),'\InputVector.att');
    Input= dlmread(fileLocation,'\t');
    
    greenRatioVector= [];
    for i=1:3
        fileLocation=strcat(currentFolder,'\',num2str(runCount),'\GreenRatio_Run',num2str(i),'.att');
        greenRatio=dlmread(fileLocation,'\t');
        greenRatioVector= [greenRatioVector greenRatio];
    end
    
    greenRatioVector= mean(greenRatioVector')';
    
    fileLocation=strcat(currentFolder,'\',num2str(runCount),'\simplermnetwork_003_Queue Results.att');
    fid=fopen(fileLocation,'r');
    fullFileScan=textscan(fid,'%s');
    splitFileScan=fullFileScan{1};
    
    sumQueueLength= zeros(3,1); %I know there are three queue counter locations
    sumQueueStops= zeros(3,1);
    maxQueueLength= zeros(3,1);
    noOfTimeQexceedsRampLength=0;
    noOfTimeQexceedMainline=0;
    count=0;
    
    for i=1:length(splitFileScan)
        b=splitFileScan{i};
        if length(b)<3
            continue;
        end
        
        if sum(b(1:3)=='AVG')==3
            %Only concerned with avg of three simulations
            c=strsplit(b,';');
            if str2num(c{2}(1))==0
                continue; %don't want the results from first interval as they are skewed
            end
            index= str2num(c{3});
            count=count+1;
            sumQueueLength(index)=sumQueueLength(index)+str2double(c{4});
            if index==1
               %it's a ramp queue
               if  str2double(c{5})>244
                   noOfTimeQexceedsRampLength=noOfTimeQexceedsRampLength+1;
               end
            end
            if index==3
               %it's a mainline queue
               if  str2double(c{5})>402
                   noOfTimeQexceedMainline=noOfTimeQexceedMainline+1;
               end
            end
            if maxQueueLength(index)<str2double(c{5})
                maxQueueLength(index)=str2double(c{5});
            end
            sumQueueStops(index)=sumQueueStops(index)+str2double(c{6});
        end
    end
    avgQueueLength= sumQueueLength*2/count;
    percentTimeQexceeds = noOfTimeQexceedsRampLength*2/count;
    percentTimeQexceedsMainline = noOfTimeQexceedMainline*2/count;
    
    fileLocation=strcat(currentFolder,'\',num2str(runCount),'\simplermnetwork_003_Vehicle Travel Time Results.att');
    fid=fopen(fileLocation,'r');
    fullFileScan=textscan(fid,'%s');
    splitFileScan=fullFileScan{1};
    
    sumTravelTime= zeros(2,1); %I know there is two veh tt sensor
    count=0;
    TSTT=0;
    for i=1:length(splitFileScan)
        b=splitFileScan{i};
        if length(b)<3
            continue;
        end
        
        if sum(b(1:3)=='AVG')==3
            %Only concerned with avg of three simulations
            c=strsplit(b,';');
            if  length(c)<5
               continue; %empty row 
            end
            d=strsplit(c{2},'-');
            if str2num(d{1})==0 || str2num(d{1})>=2700
                %Ignoring the first timestep and last 15min 
                continue; 
            end
            index= str2num(c{3});
            sumTravelTime(index)= sumTravelTime(index)+str2double(c{7});
            TSTT= TSTT+ str2double(c{7})*str2double(c{4});
            count=count+1;
        end
    end
    avgTravelTime = sumTravelTime*2/count;
    
    accumulatedGR= [ accumulatedGR; runCount,   Input', mean(greenRatioVector), maxQueueLength', avgTravelTime', avgQueueLength', percentTimeQexceeds, percentTimeQexceedsMainline]; %check this
    
end

dlmwrite('CompiledResult.txt',accumulatedGR,'\t');

