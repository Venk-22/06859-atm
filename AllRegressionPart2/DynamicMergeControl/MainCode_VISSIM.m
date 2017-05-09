clc;
clear;

runCount=0;
for mainlineDemand=3000:1000:6000
    for rampDemand=750:500:1750
    %bottleneckSpeed=100;
        for bottleneckSpeed=[20 40 60 80 100]
            inputVector=[mainlineDemand; rampDemand; bottleneckSpeed];
            runCount= runCount+1;
            if runCount<1
                'do nothing';
            else
                currentFolder=pwd;
                %mkdir(strcat(currentFolder,'\',num2str(runCount)));
                save('InputVector.att','inputVector','-ascii');
                %for runNumber=1:3
                %    DLUCControlRamp(runNumber, mainlineDemand, rampDemand, bottleneckSpeed);
                %end
                destination=strcat(currentFolder,'\',num2str(runCount));
                %pause(20);
                movefile('inputVector.att',destination);
                %if exist('dlucwithramp.err', 'file')==2
                %    movefile('dlucwithramp.err',destination);
                %end
            end
        end
    end
end