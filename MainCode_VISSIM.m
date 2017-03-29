clc;
clear;

% results= dlmread('GeneratedPoints.txt','\t',1,0);
% X=results(:,13:14);
% noOfClusters=100;
% [idx,ClusterPoints]=kmeans(X,noOfClusters);
% 
% results(:,15)=idx;
runCount=0;
for mainlineDemand=[4000 5000 6000]
    for bottleneckSpeed=[20 40 60 80 100]
        inputVector=[mainlineDemand; bottleneckSpeed];
        runCount= runCount+1;
        if runCount<9
            'do nothing';
        else
            currentFolder=pwd;
            mkdir(strcat(currentFolder,'\',num2str(runCount)));
            save('InputVector.att','inputVector','-ascii');
            for runNumber=1:3
                VSLControl(runNumber,mainlineDemand,bottleneckSpeed);
            end
            destination=strcat(currentFolder,'\',num2str(runCount));
            pause(10);
            movefile('*.att',destination);
            if exist('vslTestBed.err', 'file')==2
                movefile('vslTestBed.err',destination);
            end
        end
    end
end


% store=[];
% 
% ClusterPoints= dlmread('ClusterPoints.txt','\t',0,0);
% 
% %for mainlineDemand=
% 
% for runCount=10:size(ClusterPoints,1)
%     demandVec=ClusterPoints(runCount,:)';
%     currentFolder=pwd;
%     %runCount=runCount+1;
%     mkdir(strcat(currentFolder,'\',num2str(runCount)));
%     Files_Creator(demandVec,runCount);
%     avgSpeedLimit= ProVSLControl(runCount);
%     STT=printSTT(runCount);
%     pause(10);
%     store=[ store; runCount, demandVec', avgSpeedLimit, STT'];
% %                 store=[ store; demandVector'];
%     destination=strcat(currentFolder,'\',num2str(runCount));
%     movefile('*.att',destination);
%     
% %     for i=1:size(results,1)
% %        if results(i,19)==runCount
% %            results(i,20)=avgSpeedLimit;
% %        end
% %     end
%     
% end
% 
% dlmwrite('AccumulatedVSL.txt', store,'\t');
%dlmwrite('Results_1.txt',results,'\t');

% for datapoint=1:size(results,1)
%     ffTTVec=results(datapoint,2:7)';
%     capVec=results(datapoint,8:13)';
%     demand_7_8=results(datapoint,14);
%     
%     
%     setArtificialLinkParams(capVec,ffTTVec);
%     setNewDemand(demand_7_8);
%     system('tap.exe Corridor_net.txt Corridor_trips.txt');
%     pathFlows= Optimization();
%     clc;
%     datapointNo= datapointNo+1
%     fids=fopen('all')
%     outputVec=[ffTTVec;capVec;demand_7_8;pathFlows(2:5)];
%     if datapointNo>1000
%         display('We are here');
%     end
% 
% end
