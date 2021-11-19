function varargout = GUI1(varargin)

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @GUI1_OpeningFcn, ...
    'gui_OutputFcn',  @GUI1_OutputFcn, ...
    'gui_LayoutFcn',  [], ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before GUI1 is made visible.
function GUI1_OpeningFcn(hObject, ~, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% handles    structure with handles and user data (see GUIDATA)
% varargin   unrecognized PropertyName/PropertyValue pairs from the
%            command line (see VARARGIN)

% hObject is default command line output for GUI1
handles.output = hObject;

%initialize all text and variables

%AUTORG SOFTWARE INITIALIZATION ONLY: Begin copying here to paste in reset
%section 

% Control variables 

handles.Com = 'COM4'; %EDIT to match device port on your CPU
handles.CPX = 'CPX';
handles.Status = 'Status: OFF';
handles.connectstat = 'NO CONNECTION';
% Assay Variables
handles.Animal = 'C001486XX'; %EDIT to create template for animal identification
handles.ExpName = 'BG'; %EDIT to create template for experimenter documentation
handles.Timestamp = '0';
handles.Assay = {'Stage 1';'Stage 2'; 'Stage 3';'Stage 4';'Stage 5';'Stage 6';'Stage 7 - Assessment'}; %EDIT to add stages or custom training protocols options on GUI
handles.AssayIdx = 1;
handles.Duration = '20'; %EDIT to modify default session duration (in minutes)
handles.MaxSuccess = 100; %EDIT to modify default maximum number of successes
handles.Success = 0;
handles.Fail = 0;
handles.Total = 0;
handles.SuccessRate = 0;
handles.Threshold = 10; %EDIT to modify minimum force reading required to initiate a trial
handles.Servo = 0;

%hidden variables
handles.Cal = [0 0]; %calibration parameters offset, slope get(popupmenu1, 'Value') check later
set(handles.assay_id,'String','Assay Type');
handles.successRate = 0; %Calculated with Number of Successes / Total Number of Trials

%data memory
handles.trial = [];
handles.data = [];
handles.forcetrace = [];
handles.uitable_result.Data = [];


%status object
handles.StatusFlag = 0; %flag for start of session
handles.StartFlag = 0; %flag for start of trial
handles.SuccessFlag = 0; %flag for success (cross upper threshold within 2 sec of trial initiation)
handles.noreadFlag = 0; %flag for a pause in force reading - avoid abberrant readings
handles.s = []; %serial object for CPX reading
handles.correctionFlag = 0;

%update all text boxes
set(handles.edit_COM, 'String', handles.Com);
set(handles.text_Status, 'String', handles.Status);
set(handles.text_connectstat,'String',handles.connectstat);
set(handles.edit_Animal, 'String', handles.Animal);
set(handles.edit_ExpName, 'String', handles.ExpName);
set(handles.text_Timestamp, 'String', handles.Timestamp);
set(handles.assay_id, 'String', handles.Assay);
set(handles.edit_Duration, 'String', handles.Duration);
set(handles.edit_MaxSuccess, 'String', num2str(handles.MaxSuccess));
set(handles.text_Success, 'String', num2str(handles.Success));
set(handles.text_Fail, 'String', num2str(handles.Fail));
set(handles.text_Total, 'String', num2str(handles.Total));

set(handles.edit_Threshold,'String',num2str(handles.Threshold));
set(handles.edit_Servo,'String',num2str(handles.Servo));

%Setup live data table
set(handles.uitable_result,'Data',[])
set(handles.uitable_result,'ColumnName',{'Start','Stop','Success','Max Pull', 'Threshold','Distance'})
set(handles.uitable_result,'Units','Normalized')

%Update handles structure
guidata(hObject, handles);

%AUTORG INITIALIZATION ONLY: End copying here to paste in reset
%section 

% --- Outputs from this function are returned to the command line.
function varargout = GUI1_OutputFcn(hObject, ~, handles)

% Default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in pushbutton_LoadCalibration.
function pushbutton_LoadCalibration_Callback(hObject, ~, handles)

newCal = [0 0];

disp('Loading Calibration')
uiload;
if exist('Calibration')
    newCal = Calibration;
    anglecal = SCalibration;
else
    disp('No Force Calibration Loaded - Please Load Calibration File')
end

handles.Cal = newCal; %update calibration if the file contains the right parameters
handles.angles = anglecal;
guidata(hObject, handles);

% --- Executes on button press in pushbutton_Start.
function pushbutton_Start_Callback(hObject, ~, handles)

popStrings = handles.assay_id.String ;
selectedIndex = handles.assay_id.Value;
assayname = popStrings{selectedIndex};
handles.savename = [handles.Animal '_' handles.ExpName '_' assayname '_' datestr(now,'yyyy-mm-dd')]; %EDIT to modify your saved file names
disp('Start')
handles.StatusFlag = 1;
set(handles.text_Status,'string','Status: ON')

StatusFlag = handles.StatusFlag;
handles.resetFlag = 0;
handles.saveFlag = 0;
handles.trial = [];
guidata(hObject, handles);

%threshold
lowthr = 10; %EDIT to change trial initiation threshold - Note: System designed for 10g
uppthr = str2double(get(handles.edit_Threshold,'String')); %Force threshold (g)
thr0 = uppthr;
Servo = str2double(get(handles.edit_Servo,'String')); %Handle position (in deg)
maxduration = str2double(get(handles.edit_Duration,'String'));%min
maxtime = 2; %EDIT to change trial time - Note: System designed for 2 sec
MaxSuccess = str2double(get(handles.edit_MaxSuccess,'String')); %# success trials


%reset all values to 0
handles.Success = 0;
handles.Fail = 0;
handles.Total = 0;
set(handles.text_Success, 'String', num2str(handles.Success));
set(handles.text_Fail, 'String', num2str(handles.Fail));
set(handles.text_Total, 'String', num2str(handles.Total));
set(handles.uitable_result,'Data',[]);

%initialize for the Pull Plot
handles = guidata(hObject);
t0 = tic;
N = 200;
buffertime = zeros(1,N);
buffer = zeros(1,N);
estFS = 50; %estimated sampling rate 50Hz
runData = nan(2,estFS*maxduration*60); %running data pre allocated
maxval = 0.1;
baseval = 0;
basesample = 0.028;
if ~isempty(handles.s)
    try
        fopen(handles.s);
    catch
        disp('Serial Connection already started');
    end
else
    disp('Please Plug in CPX, Check COM Input, and Try Again')
    return
end


%Set intial handle distance
angle = Servo;
fprintf(handles.s, '%s\n',['S' num2str(angle)]);


%Real-Time trace setup
cla(handles.axes_Pull)
axes(handles.axes_Pull)
hp = plot(NaN,NaN,'k'); hold off
hlow = line([0 6],lowthr*[1 1],'color','k','linestyle','--'); hold off
hhigh = line([0 6],uppthr*[1 1],'color','k','linestyle','--'); hold off


StartFlag = 0;
SuccessFlag = 0;
handles.noreadFlag = 1;
handles.PelletONFlag = 0;
handles.startTSservo = [];
currentTS = 0;
track = 0;
runFlag = 1; %count each sampling
disp('Running Experiment')
guidata(hObject,handles);
iter = 0;
init = 1;
last_interact = 0;
dispenses = 0;
dispenses0 = 0;
while StatusFlag == 1
    StatusFlag = handles.StatusFlag;
    handles = guidata(hObject);
    
    drawnow
    noreadFlag = handles.noreadFlag;
    
    
    t1 = toc(t0);
    buffertime(1:(N-1)) = buffertime(2:N);
    buffertime(N) = t1;
    buffer(1:(N-1)) = buffer(2:N);
    
    
    if ~isempty(handles.s)
        try
            out = fscanf(handles.s);
        catch
            break
        end
        
        if (~isempty(out)||(sum(out == ':')>0 && sum(out == 'W')>0))
            idxs = find(out == ':');
            idxw = find(out == 'W');
            readval = str2double(out(1,idxs+2:idxw-1));
            
        else
            disp('CPX Cannot Be Read')
            readval = nan;
            if isempty(handles.trial) == 0
                if handles.correctionFlag == 0 && handles.AssayIdx > 1
                    lastrow = size(handles.trial,1);
                    if handles.trial(lastrow,5) == 10 || handles.trial(lastrow,5) == 15
                        if handles.trial(lastrow,6) == -0.30
                            handles.trial(lastrow,:) = [];
                        end
                    end
                end
                trialdata = handles.trial;
                tracedata = handles.data;
                summarydata = [];
                set(handles.text_Status,'string','SAVING')
                set(handles.text_Status, 'BackgroundColor','yellow')
                
                matname = [handles.savename  '.mat'];
                if ~isfile(['C:\Users\klabuser\Desktop\AutoRG\Running Experiments\' matname]) %EDIT save location during initialization
                    disp(['Data saved in: ' matname])
                    destination = 'C:\Users\klabuser\Desktop\AutoRG\Running Experiments'; %EDIT save location during initialization
                    save(fullfile(destination,matname),'trialdata','tracedata','summarydata')
                    handles.saveFlag = 1;
                    guidata(hObject,handles);
                else
                    disp('Duplicate Name for Data - Saving in Alternative Name')
                    destination  = 'C:\Users\klabuser\Desktop\AutoRG\Running Experiments'; %EDIT save location during initialization
                    filesAndFolders = dir(destination);
                    filesInDir = filesAndFolders(~([filesAndFolders.isdir]));
                    Nfiles = length(filesInDir);
                    i = 1;
                    duplicate_count = 0;
                    while i<= Nfiles
                        filename = filesInDir(i).name;
                        compare_filename = extractBefore(filename, '.mat');
                        compare_matname = extractBefore(matname, '.mat');
                        strlength1 = length(compare_filename);
                        strlength2 = length(compare_matname);
                        if strlength1 == strlength2
                            check = strncmp(compare_filename,compare_matname,strlength1);
                            if check == 1
                                duplicate_count = duplicate_count + 1;
                            end
                        end
                        i = i+1;
                    end
                    matname = [handles.savename '_' num2str(duplicate_count+1) '.mat'];
                    display(['Data Saved in: ' matname ' append ' num2str(duplicate_count+1)])
                    destination = 'C:\Users\klabuser\Desktop\AutoRG\Running Experiments'; %EDIT save location during initialization
                    save(fullfile(destination,matname),'trialdata','tracedata','summarydata')
                    handles.saveFlag = 1;
                    guidata(hObject, handles);
                end
                
            end
            TS1 = buffertime(N);
            while true
                TS2 = buffertime(N);
                time_slowed = TS2 - TS1;
                if time_slowed > 120 %Greater than 20 sec of buffer
                    set(handles.text_Status,'string','Status: OFF')
                    
                    set(handles.text_Status, 'BackgroundColor',[.3 .75 .93])
                    break
                end
                pause(2);
                bytes = handles.s.BytesAvailable;
                if bytes > 0
                    break
                end
            end
            
        end
        
        drawnow
        
        %Check if system should be reading or if it is on pause
        if noreadFlag ~= 0
            if iter == 0 %noreadval JUST triggered
                startTSservo = buffertime(N);
                iter = 1;
            end
            noreadtime = buffertime(N) - startTSservo ;
            
            if noreadtime > 2 %Time delay 
                noreadFlag = 0; %Hold on force reading is removed
                iter = 0;
                handles.noreadFlag = noreadFlag;
                
                guidata(hObject,handles);
            else
                readval = nan ;
            end
        end
        
        
        if size(readval) ~=1
            buffer(N) = 0.1;
        else
            buffer(N) = readval*handles.Cal(1)+handles.Cal(2);
        end
        runData(:,runFlag) = [buffertime(N);buffer(N)];
        
        handles.forcetrace = [buffertime(N) buffer(N); handles.forcetrace];
        
        guidata(hObject);
        
        trialdata = handles.trial;
        
        
        if isempty(trialdata) == 1 %beginning of assay - no interaction so far
            if buffertime(N) > 30 && dispenses == 0 %30 sec, for first time only
                fprintf(handles.s, '%s\n',['P' num2str(0)]);
                handles.noreadFlag = 1;
                last_interact = buffertime(N);
                dispenses0 = dispenses;
                dispenses = dispenses + 1;
                last_interact = buffertime(N);
            else
                time_elapsed = buffertime(N) - last_interact;
                if time_elapsed > 120 %another 120 sec of no interaction with handle since last pellet dispense
                    fprintf(handles.s, '%s\n',['P' num2str(0)]);
                    handles.noreadFlag = 1;
                    last_interact = buffertime(N);
                    
                end
            end
        else %rat has had some interaction
            time_elapsed = buffertime(N) - trialdata(1,1);
            dispenses = size(trialdata,1);
            if time_elapsed > 60 && dispenses ~= dispenses0 %1 min without interaction
                fprintf(handles.s, '%s\n',['P' num2str(0)]);
                handles.noreadFlag = 1;
                dispenses0 = dispenses;
                
            end
            
            
        end
        guidata(hObject,handles);
        if buffer(N)>=lowthr && StartFlag == 0
            StartFlag = 1;
            SuccessFlag = 0;
            startTS = buffertime(N);
            stopTS = [];
            disp('Trial starts')
        end
        
        %Successes & Fails
        idxdata = [];
        
        %updating flag for success if any
        if StartFlag ==1  %verify trial is going
            
            if (buffertime(N)-startTS)< maxtime
                if buffer(N) >= uppthr
                    %success
                    stopTS = buffertime(N);
                    SuccessFlag = 1;
                    
                    
                else
                    %threshold not exceeded
                    stopTS = buffertime(N);
                end
            end
            if (buffertime(N)-startTS) >= maxtime %maxtime exceeded
                disp('Trial end')
                
                pause(0.001)
                idxdata = find(runData(1,:)>=(startTS-0.5)&runData(1,:)<=stopTS); %time index of the trial curve
                handles = guidata(hObject);
                if SuccessFlag == 1
                    track = track + 1;
                    %success
                    disp('Trial Success')
                    disp('Pellet: sent')
                    fprintf(handles.s, '%s\n',['P' num2str(0)]); %send comment to arduino
                    %signal pellet servo has been triggered
                    noreadFlag = 1;
                    handles.noreadFlag = noreadFlag;
                    startTSservo = buffertime(N);
                    handles.startTSservo = startTSservo;
                    
                    guidata(hObject,handles);
                else
                    
                    disp('Trial Failed')
                    track = track + 1;
                    
                    
                    guidata(hObject,handles);
                end
                
                MaxPull = max(runData(2,idxdata));
                
                switch handles.AssayIdx %EDIT if custom protocol added
                    case 1
                        dist = -0.30;
                    case 2
                        dist = -0.30;
                    case 3
                        dist = 0;
                    case 4
                        dist = 0.25;
                    case 5
                        dist = 0.25;
                    case 6
                        dist = 0.50;
                    case 7
                        dist = 0.50;
                        
                end
                if track == 1 %corrects for true location of handle for first trial only
                    dist = -0.30;
                end
                
                ntrial = [startTS stopTS SuccessFlag MaxPull uppthr dist; handles.trial];
                
                lastrow = size(ntrial,1);
                if size(ntrial,1) > 1
                    if ntrial(lastrow,5) == 10 || ntrial(lastrow,6) == 15
                        if ntrial(lastrow,6) == -0.30 && handles.AssayIdx > 1
                            ntrial(lastrow,:) = [];
                            correctionFlag = 1;
                            handles.correctionFlag = correctionFlag;
                            
                            guidata(hObject);
                        end
                    end
                end
                handles.Success = nansum(ntrial(:,3));
                set(handles.text_Success,'string',num2str(handles.Success))
                handles.Fail = size(ntrial,1) - nansum(ntrial(:,3));
                set(handles.text_Fail,'string',num2str(handles.Fail))
                
                handles.Total = handles.Success + handles.Fail; %Update total # of trials
                handles.successRate = 100*handles.Success /(handles.Total);
                
                handles.trial = ntrial;
                
                get(handles.uitable_result,'Data');
                set(handles.uitable_result,'Data',ntrial); %update table
                
                
                trialdata = zeros(1,8);
                
                Servo0 = Servo; %Set pre-updated Servo value
                thr0 = uppthr;
                if ~isempty(handles.trial)
                    [uppthr,Servo] = update_param(handles.AssayIdx,handles.successRate,handles.Threshold,handles.Total,handles.MaxSuccess,handles.trial,handles.angles);
                end
                
                if Servo0 ~= Servo %check if servo has been updated by update_param
                    angle = Servo;
                    fprintf(handles.s, '%s\n',['S' num2str(angle)]); %Update servo
                    handles.noreadFlag = 1; %Delay reading until servo has moved / has been updated to avoid misreading
                    
                    startTSservo = buffertime(N);
                    handles.startTSservo = startTSservo ;
                    guidata(hObject, handles);
                    Servo0 = Servo ;
                end
                set(handles.text_Total,'string',num2str(handles.Total))
                set(handles.text_SRate,'string',num2str(handles.successRate))
                
                handles.Servo = Servo ;
                SuccessFlag = 0; %Reset SuccessFlag back to 0 for new trial
                StartFlag = 0;
                
                guidata(hObject, handles);
            end
            
        end
        
        currentTS0 = round(buffertime(N));
        if currentTS<currentTS0 %update time for every second only
            sec = mod(round(buffertime(N)),60);
            if sec ~= 0
                set(handles.text_Timestamp,'string',[num2str(floor(buffertime(N)/60)) 'min' ' ' num2str(mod(round(buffertime(N)),60)) 'sec'])
            else
                minute = floor(buffertime(N)/60) + 1;
                set(handles.text_Timestamp,'string',[num2str(minute) 'min' ' ' num2str(mod(round(buffertime(N)),60)) 'sec'])
            end
            currentTS = currentTS0;
            %update data
            handles.data = runData;
            guidata(hObject,handles);
        end
        
        try
            set(hp,'XData',buffertime-buffertime(1),'YData',buffer);
        catch
            break
        end
        set(handles.axes_Pull,'ylim',[-10 200])
        if thr0 ~= uppthr || init == 1
            get(hhigh,'YData');
            set(hhigh,'YData', uppthr*[1,1]);
        end
        
        pause(.001)
        
    else
        disp('CPX disconnected stop running')
    end
    
    
    pause(0.001)
    handles = guidata(hObject);
    StatusFlag = handles.StatusFlag;
    guidata(hObject, handles);
    
    %duration exceeded
    if buffertime(N)>=maxduration*60
        disp('Task terminated - Max duration reached')
        
        
        
        handles = guidata(hObject);
        
        
        disp('Stop')
        
        handles.StatusFlag = 0;
        guidata(hObject,handles);
        
    end
    if handles.Success >= MaxSuccess
        disp('Task terminated - Max successes reached')
        handles = guidata(hObject);
        
        
        disp('Stop')
        
        handles.StatusFlag = 0;
        guidata(hObject,handles);
        
    end
    if handles.Success >= MaxSuccess || buffertime(N)>=maxduration*60
        trialdata = handles.trial;
        tracedata = handles.data;
        
        popStrings = handles.assay_id.String; % All the strings in the menu.
        selectedIndex = handles.assay_id.Value;
        selectedString = popStrings{selectedIndex};
        
        switch selectedString %EDIT if custom protocol added
            case 'Stage 1'
                stage = 1;
            case 'Stage 2'
                stage = 2;
            case 'Stage 3'
                stage = 3;
            case 'Stage 4'
                stage = 4;
            case 'Stage 5'
                stage = 5;
            case 'Stage 6'
                stage = 6;
            case 'Stage 7 - Assessment'
                stage = 7;
                
        end
        
        if handles.correctionFlag == 0 && handles.AssayIdx > 1
            lastrow = size(handles.trial,1);
            if handles.trial(lastrow,5) == 10 || handles.trial(lastrow,5) == 15
                if handles.trial(lastrow,6) == -0.30
                    handles.trial(lastrow,:) = [];
                end
            end
        end
        
        trialdata = handles.trial;
        success = nansum(trialdata(:,3));
        failidx = trialdata(:,3)==0;
        fails = nansum(failidx);
        total = success + fails;
        
        
        summarydata = [stage success fails total];
        
        set(handles.text_Status,'string','SAVING')
        set(handles.text_Status, 'BackgroundColor','yellow')
        
        matname = [handles.savename  '.mat'];
        if ~isfile(['C:\Users\klabuser\Desktop\AutoRG\Running Experiments\' matname]) %EDIT save location during initialization
            disp(['Data saved in: ' matname])
            destination = 'C:\Users\klabuser\Desktop\AutoRG\Running Experiments'; %EDIT save location during initialization
            save(fullfile(destination,matname),'trialdata','tracedata','summarydata')
            handles.saveFlag = 1;
            guidata(hObject,handles);
        else
            disp('Duplicate Name for Data - Saving in Alternative Name')
            destination  = 'C:\Users\klabuser\Desktop\AutoRG\Running Experiments'; %EDIT save location during initialization
            filesAndFolders = dir(destination);
            filesInDir = filesAndFolders(~([filesAndFolders.isdir]));
            Nfiles = length(filesInDir);
            i = 1;
            duplicate_count = 0;
            while i<= Nfiles
                filename = filesInDir(i).name;
                compare_filename = extractBefore(filename, '.mat');
                compare_matname = extractBefore(matname, '.mat');
                strlength1 = length(compare_filename);
                strlength2 = length(compare_matname);
                if strlength1 == strlength2
                    check = strncmp(compare_filename,compare_matname,strlength1);
                    if check == 1
                        duplicate_count = duplicate_count + 1;
                    end
                end
                i = i+1;
            end
            matname = [handles.savename '_' num2str(duplicate_count+1) '.mat'];
            display(['Data Saved in: ' matname ' append ' num2str(duplicate_count+1)])
            destination = 'C:\Users\klabuser\Desktop\AutoRG\Running Experiments'; %EDIT save location during initialization
            save(fullfile(destination,matname),'trialdata','tracedata','summarydata')
            handles.saveFlag = 1;
            guidata(hObject, handles);
        end
        
        set(handles.text_Status,'string','Status: OFF')
        
        set(handles.text_Status, 'BackgroundColor',[.3 .75 .93])
        handles.StatusFlag = 0;
        handles.Success = 0;
        handles.Fail = 0;
        handles.SuccessRate = 0;
        handles.Total = 0;
        handles.trial = [];
        % stop all running plots
        return
        guidata(hObject, handles);
    end
    guidata(hObject, handles);
    runFlag = runFlag+1;
    guidata(hObject,handles);
    init = 0;
end

guidata(hObject, handles);

function edit_Animal_Callback(hObject, ~, handles)

disp('Animal ID Updated')
Animal = get(handles.edit_Animal,'String');
set(handles.edit_Animal, 'String', Animal);
handles.Animal = Animal;
guidata(hObject, handles);

function edit_Animal_CreateFcn(hObject, ~, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_ExpName_Callback(hObject, ~, handles)

disp('Experimenter Updated ')
ExpName = get(handles.edit_ExpName,'String');
set(handles.edit_ExpName, 'String', ExpName);
handles.ExpName = ExpName;
guidata(hObject, handles);

function edit_ExpName_CreateFcn(hObject, ~, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_Duration_Callback(hObject, ~, handles)

disp('Duration Updated')
Dur = get(handles.edit_Duration,'String');
set(handles.edit_Duration, 'String', Dur);
handles.Duration = str2num(Dur);
guidata(hObject, handles);

function edit_Duration_CreateFcn(hObject, ~, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function assay_id_Callback(hObject, ~, handles)

popStrings = handles.assay_id.String; % All the strings in the menu.
selectedIndex = handles.assay_id.Value;
selectedString = popStrings{selectedIndex};

switch selectedString %EDIT if custom protocol added
    case 'Stage 1'
        handles.AssayIdx = 1;
    case 'Stage 2'
        handles.AssayIdx = 2;
    case 'Stage 3'
        handles.AssayIdx = 3;
    case 'Stage 4'
        handles.AssayIdx = 4;
    case 'Stage 5'
        handles.AssayIdx = 5;
    case 'Stage 6'
        handles.AssayIdx = 6;
    case 'Stage 7 - Assessment'
        handles.AssayIdx = 7;
        
end
guidata(hObject, handles);

function assay_id_CreateFcn(hObject, ~, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function pushbutton_CPX_Callback(hObject, ~, handles)

disp('Connecting CPX')
newobjs = instrfind;
if ~isempty(newobjs)
    fclose(newobjs);
end
s = serial(handles.Com,'BaudRate',115200);
if isempty(s)
    set(handles.text_connectstat,'string',['No CPX'])
else
    %update text
    set(handles.text_connectstat,'string', [handles.Com ' CONNECTED']);
    set(handles.text_connectstat,'BackgroundColor','green');
end
handles.s = s;
guidata(hObject, handles);

function edit_COM_Callback(hObject, ~, handles)

disp('Check COM')
Com = get(handles.edit_COM,'String');
set(handles.edit_COM, 'String', Com);
handles.Com = Com;
guidata(hObject, handles);

function edit_COM_CreateFcn(hObject, ~, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function edit_MaxSuccess_Callback(hObject, ~, handles)

disp('Success Max Updated')
MS = get(handles.edit_MaxSuccess,'String');
set(handles.edit_MaxSuccess, 'String', MS);
handles.MaxSuccess = MS;
guidata(hObject, handles);

function edit_MaxSuccess_CreateFcn(hObject, ~, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function pushbutton_reset_Callback(hObject, ~, handles)

handles.resetFlag = 1;
handles = guidata(hObject);


set(handles.text_Status, 'String', 'Resetting...Please Wait');
set(handles.text_Status, 'BackgroundColor','yellow')
try
    fclose(handles.s);
end
handles.StatusFlag = 0;

guidata(hObject,handles);

trialdata = handles.trial;
tracedata = handles.data;

popStrings = handles.assay_id.String; % All the strings in the menu.
selectedIndex = handles.assay_id.Value;
selectedString = popStrings{selectedIndex};

switch selectedString %EDIT if custom protocol added - Copy and paste from switch-->end for section near Line 737
    case 'Stage 1'
        stage = 1;
    case 'Stage 2'
        stage = 2;
    case 'Stage 3'
        stage = 3;
    case 'Stage 4'
        stage = 4;
    case 'Stage 5'
        stage = 5;
    case 'Stage 6'
        stage = 6;
    case 'Stage 7 - Assessment'
        stage = 7;
        
end
if ~isempty(handles.trial)
    if handles.correctionFlag == 0 && handles.AssayIdx > 1
        lastrow = size(handles.trial,1);
        
        if handles.trial(lastrow,5) == 10 || handles.trial(lastrow,5) == 15
            if handles.trial(lastrow,6) == -0.30
                handles.trial(lastrow,:) = [];
            end
        end
    end
end

if ~isempty(handles.trial)
    trialdata = handles.trial;
    
    success = nansum(trialdata(:,3));
    failidx = trialdata(:,3)==0;
    fails = nansum(failidx);
    total = success + fails;
else
    trialdata = [];
    success = 0;
    fails = 0;
    total = 0;
end


summarydata = [stage success fails total];

set(handles.text_Status,'string','SAVING')
set(handles.text_Status, 'BackgroundColor','yellow')

matname = [handles.savename  '.mat'];
if ~isfile(['C:\Users\klabuser\Desktop\AutoRG\Running Experiments\' matname]) %EDIT save location during initialization
    disp(['Data saved in: ' matname])
    destination = 'C:\Users\klabuser\Desktop\AutoRG\Running Experiments'; %EDIT save location during initialization
    save(fullfile(destination,matname),'trialdata','tracedata','summarydata')
    handles.saveFlag = 1;
    guidata(hObject,handles);
else
    disp('Duplicate Name for Data - Saving in Alternative Name')
    %see how many versions exist
    destination  = 'C:\Users\klabuser\Desktop\AutoRG\Running Experiments'; %EDIT save location during initialization
    filesAndFolders = dir(destination);
    filesInDir = filesAndFolders(~([filesAndFolders.isdir]));
    Nfiles = length(filesInDir);
    i = 1;
    duplicate_count = 0;
    while i<= Nfiles
        filename = filesInDir(i).name;
        compare_filename = extractBefore(filename, '.mat');
        compare_matname = extractBefore(matname, '.mat');
        strlength1 = length(compare_filename);
        strlength2 = length(compare_matname);
        if strlength1 == strlength2
            check = strncmp(compare_filename,compare_matname,strlength1);
            if check == 1
                duplicate_count = duplicate_count + 1;
            end
        end
        i = i+1;
    end
    matname = [handles.savename '_' num2str(duplicate_count+1) '.mat'];
    display(['Data Saved in: ' matname ' append ' num2str(duplicate_count+1)])
    destination = 'C:\Users\klabuser\Desktop\AutoRG\Running Experiments'; %EDIT save location during initialization
    save(fullfile(destination,matname),'trialdata','tracedata','summarydata')
    handles.saveFlag = 1;
    guidata(hObject, handles);
end

set(handles.text_Status,'string','Status: OFF')
set(handles.text_Status, 'BackgroundColor',[.3 .75 .93])

handles.Timestamp = '0';
set(handles.text_Timestamp, 'String', handles.Timestamp);
handles.StatusFlag = 0;
handles.Success = 0;
handles.Fail = 0;
handles.SuccessRate = 0;
handles.Total = 0;


guidata(hObject, handles);

% stop all running plots

disp('Reset Assay')

cla(handles.axes_Pull,'reset');

handles.output = hObject;

%Re-initialize all text and variables

%BEGIN PASTE HERE 

% Control variables

handles.Com = 'COM4'; %EDIT to match initialization section
handles.CPX = 'CPX';
handles.Status = 'Status: OFF';
handles.connectstat = 'NO CONNECTION';
% Assay Variables
handles.Timestamp = '0';
handles.Success = 0;
handles.Fail = 0;
handles.Total = 0;
handles.SuccessRate = 0;

%hidden variables
set(handles.assay_id,'String','Assay Type');
handles.successRate = 0;

%data memory
handles.trial = [];
handles.data = [];
handles.forcetrace = [];
handles.uitable_result.Data = [];


%status object
handles.StatusFlag = 0; %flag for start of session
handles.StartFlag = 0; %flag for start of trial
handles.SuccessFlag = 0; %flag for success (cross upper threshold within 2 sec of trial initiation)
handles.noreadFlag = 0; %flag for a pause in force reading - avoid abberrant readings
handles.s = []; %serial object for CPX reading
handles.correctionFlag = 0;

%update all text boxes
set(handles.edit_COM, 'String', handles.Com);
set(handles.text_Status, 'String', handles.Status);
set(handles.text_connectstat,'String',handles.connectstat);
set(handles.edit_Animal, 'String', handles.Animal);
set(handles.edit_ExpName, 'String', handles.ExpName);
set(handles.text_Timestamp, 'String', handles.Timestamp);
set(handles.assay_id, 'String', handles.Assay);
set(handles.edit_Duration, 'String', handles.Duration);
set(handles.edit_MaxSuccess, 'String', num2str(handles.MaxSuccess));
set(handles.text_Success, 'String', num2str(handles.Success));
set(handles.text_Fail, 'String', num2str(handles.Fail));
set(handles.text_Total, 'String', num2str(handles.Total));

set(handles.edit_Threshold,'String',num2str(handles.Threshold));
set(handles.edit_Servo,'String',num2str(handles.Servo));

%Setup live data table
set(handles.uitable_result,'Data',[])
set(handles.uitable_result,'ColumnName',{'Start','Stop','Success','Max Pull', 'Threshold','Distance'})
set(handles.uitable_result,'Units','Normalized')

%Update handles structure
guidata(hObject, handles);

%END PASTE HERE

function edit_Threshold_Callback(hObject, ~, handles)

thres = get(handles.edit_Threshold,'String');
testthres = str2double(thres);
if testthres >= 10
    disp('Force Threshold Updated')
    set(handles.edit_Threshold, 'String', thres);
    handles.Threshold = thres;
    guidata(hObject, handles);
    
else
    disp('Error: Please enter threshold greater than 10g') %EDIT text if default parameter of 10g trial initiation is changed
end

function edit_Threshold_CreateFcn(hObject, ~, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_Servo_Callback(hObject, ~, handles)

serv = get(handles.edit_Servo,'String');
testserv = str2double(serv);
if testserv >= 0 && testserv <= 100
    disp('Handle Position Updated')
    set(handles.edit_Servo, 'String', serv);
    handles.Servo = serv;
else
    disp('Error: Please enter handle position between 0 and 100 degrees')
end
guidata(hObject, handles);

function edit_Servo_CreateFcn(hObject, ~, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
