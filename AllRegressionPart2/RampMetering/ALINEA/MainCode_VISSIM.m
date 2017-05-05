%Maincode which generates combinations of inputs and calls
%RMControl_Simplenet to run microsimulation for each input combination

clc;
clear;

runCount=0;
for mainlineDemand=3000:1000:6000
    for rampDemand=750:500:1750
        for bottleneckSpeed=[20 40 60 80]
            inputVector=[mainlineDemand; rampDemand; bottleneckSpeed];
            runCount= runCount+1; %unique index for each input combination
            if runCount<1
                'do nothing';
            else
                currentFolder=pwd;
                %make a directory for the current input combination
                mkdir(strcat(currentFolder,'\',num2str(runCount)));
                save('InputVector.att','inputVector','-ascii');
                for runNumber=1:3
                    %Run 3 iterations for the given input combination
                    RMControl_simpleNet(runNumber,mainlineDemand,rampDemand,bottleneckSpeed);
                end
                destination=strcat(currentFolder,'\',num2str(runCount));
                pause(10);
                %pause for 10 seconds and move all results stored in .att
                %files into the destination folder
                movefile('*.att',destination);
                if exist('simplermnetwork.err', 'file')==2
                    movefile('simplermnetwork.err',destination);
                end
            end
        end
    end
end