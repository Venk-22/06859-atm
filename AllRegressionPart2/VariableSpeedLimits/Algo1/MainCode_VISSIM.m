%Maincode which generates combinations of inputs and calls
%VSlControl to run microsimulation for each input combination

clc;
clear;

runCount=16;
for mainlineDemand=3500:1000:5500
    for bottleneckSpeed=[20 40 60 80 100]
        inputVector=[mainlineDemand; bottleneckSpeed];
        runCount= runCount+1;
        if runCount<1
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