function [thr,servo] = update_param(AssayID,successRate,thr,success,maxsuccess,trialdata,angles)
%Update parameters for the RG pull force box
%trialdata {'Start','Stop','Success','MaxForce','TrigThr','HandleDist'})

trialdata0 = trialdata;
trialdata = trialdata(trialdata(:,5)==0,:);%filter non auto pellet delivery
inside = angles(1);
onwall = angles(2);
outside = angles(3); 
assessment = angles(4);

switch AssayID
    %Angles are for box setup for unit 2
    case 1 %Stage 1
        thr = 10; %Almost any interaction is a success
        maxtime = 2;
        servo = inside; %Situated within the cage: -.30 in inside
        
    case 2 %Stage 2
        thr = 35;
        maxtime = 2;
        servo = inside; %-.30 in / inside cage
        
    case 3 %Stage 3
        thr = 35;
        maxtime = 2;
        servo = onwall; %In line with inner wall slit
        
    case 4 %Stage 4
        thr = 35;
        maxtime = 2;
        servo = outside; %+.25 in from inner wall
        
    case 5 %Stage 5
        thr = 65;
        maxtime = 2;
        servo = outside; %+.25 in from inner wall
        
    case 6 %Stage 6
        thr = 65;
        maxtime = 2;
        servo = assessment; %+.50 in
        
    case 7 %Stage 7 / Assessment
        thr = 120;
        maxtime = 2;
        servo = assessment;
        
end
end



