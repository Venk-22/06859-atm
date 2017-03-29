clc;
clear;

accumulatedGR=[];
currentFolder= pwd;

for runCount=1:15
    fileLocation=strcat(currentFolder,'\',num2str(runCount),'\InputVector.att');
    Input= dlmread(fileLocation,'\t');
    
    vslVector= [];
    for i=1:3
        fileLocation=strcat(currentFolder,'\',num2str(runCount),'\VSLOutput_Run',num2str(i),'.att');
        speeds=dlmread(fileLocation,'\t');
        vslVector= [vslVector speeds];
    end
    
    vslVector= mean(vslVector(2:end,:)')';
%     hold on
%     plot(vslVector,'color',rand(1,3))
%     %plot(rec_gr2,'k.')
%     xlabel('Cycle number')
%     ylabel('Green ratio')
%     legend(strcat('DataPoint',num2str(runCount)))
    
    fileLocation=strcat(currentFolder,'\',num2str(runCount),'\vslTestBed_003_Queue Results.att');
    fid=fopen(fileLocation,'r');
    fullFileScan=textscan(fid,'%s');
    splitFileScan=fullFileScan{1};
    
    sumQueueLength= 0; %I know there are one queue counter locations
    sumQueueStops= 0;
    maxQueueLength= 0;
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
            count=count+1;
            sumQueueLength=sumQueueLength+str2double(c{4});
            
            if maxQueueLength<str2double(c{5})
                maxQueueLength=str2double(c{5});
            end
            sumQueueStops=sumQueueStops+str2double(c{6});
        end
    end
    avgQueueLength= sumQueueLength/count;
    
    fileLocation=strcat(currentFolder,'\',num2str(runCount),'\vslTestBed_003_Vehicle Travel Time Results.att');
    fid=fopen(fileLocation,'r');
    fullFileScan=textscan(fid,'%s');
    splitFileScan=fullFileScan{1};
    
    sumTravelTime= 0; %I know there is one veh tt sensor
    count=0;
    
    for i=1:length(splitFileScan)
        b=splitFileScan{i};
        if length(b)<3
            continue;
        end
        
        if sum(b(1:3)=='AVG')==3
            %Only concerned with avg of three simulations
            c=strsplit(b,';');
            
            d=strsplit(c{2},'-');
            if str2num(d{1})<900 || str2num(d{1})>=2700
                %Ignoring the first timestep and last 15min 
                continue; 
            end
            sumTravelTime= sumTravelTime+str2double(c{5});
            count=count+1;
        end
    end
    avgTravelTime = sumTravelTime/count;
%     
%     accumulatedGR(runCount,13)=sumQueueLength_1/90;
%     accumulatedGR(runCount,14)=maxQueueLength_1;
%     accumulatedGR(runCount,15)=sumQueueStops_1/90;
%     
%     accumulatedGR(runCount,16)=sumQueueLength_2/90;
%     accumulatedGR(runCount,17)=maxQueueLength_2;
%     accumulatedGR(runCount,18)=sumQueueStops_2/90;
%     
%     fileLocation=strcat(currentFolder,'\',num2str(runCount),'\atm_2_exit_3_lanes_large_network_001_Vehicle Travel Time Results.att');
%     fid=fopen(fileLocation,'r');
%     fullFileScan=textscan(fid,'%s');
%     splitFileScan=fullFileScan{1};
%     
%     travelTime=zeros(6,1); %stores the travel time for first and second half of corridor for the three hours
%     %tt_1 is first half first hour, tt_1 is second half first hour and
%     %likewise
%     for i=51:56
%         b=splitFileScan{i};
%         c=strsplit(b,';');
%         travelTime(i-50)= str2double(c{5});
%     end
%     
%     accumulatedGR(runCount,19:24)=travelTime';
    
    accumulatedGR= [ accumulatedGR; runCount,   Input', mean(vslVector), maxQueueLength', avgQueueLength', avgTravelTime, ]; %check this
    
end

dlmwrite('CompiledResult.txt',accumulatedGR,'\t');

