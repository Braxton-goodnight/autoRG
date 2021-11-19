  function varargout = GUI_scale_calibration(varargin)

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_scale_calibration_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_scale_calibration_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
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

function GUI_scale_calibration_OpeningFcn(hObject, eventdata, handles, varargin)

% Choose default command line output for GUI_scale_calibration
handles.output = hObject;

%variables
handles.Com = 'COM4'; %EDIT to match device port on your CPU
handles.Load = 0;
handles.Data = [];
handles.DataPairs = [];
handles.Calibration = [0 0];
handles.inside = 0; 
handles.onwall = 25; 
handles.outside = 50;
handles.assessment = 75;
handles.Status = 'DISCONNECTED';
handles.servoangle = 0;
handles.servoflag = 0;
%hidden variables
handles.s = [];
handles.StatusFlag = 0;

set(handles.edit_CPX, 'String', handles.Com);
set(handles.edit_Load, 'String', handles.Load);
set(handles.edit_servoangle, 'String', handles.servoangle);
set(handles.text_Status, 'String', handles.Status);
% Update handles structure
guidata(hObject, handles);

function varargout = GUI_scale_calibration_OutputFcn(hObject, eventdata, handles) 

varargout{1} = handles.output;

function pushbutton_CPX_Callback(hObject, eventdata, handles)

display('Connecting CPX')
newobjs = instrfind;
if ~isempty(newobjs)
    fclose(newobjs);
end
s = serial(handles.Com,'BaudRate',115200);
if isempty(s)
    set(handles.text_Status,'string','NO CPX')
    set(handles.text_Status,'BackgroundColor','r')
else
    %update text
    set(handles.text_Status,'string','CONNECTED')
    set(handles.text_Status,'BackgroundColor','g')
end
handles.s = s;
guidata(hObject, handles);

function pushbutton_Start_Callback(hObject, eventdata, handles)

%Replot data and fit
    
display('Start')
handles.StatusFlag = 1;
guidata(hObject, handles);
StatusFlag = handles.StatusFlag;
servoFlag = handles.servoflag;

%initialize for the Pull plot
t0 = cputime;
N = 100;
buffertime = zeros(1,N);
buffer = zeros(1,N);
fopen(handles.s)
cla(handles.axes1)
axes(handles.axes1)
ylim manual
h1 = plot(NaN,NaN,'k');hold off
cla(handles.axes2)
axes(handles.axes2)
h2 = plot(NaN,NaN,'k');hold off
handles = guidata(hObject);
display('Beginning Calibration')
while StatusFlag == 1

    if ~isempty(handles.s)
        %update pull data
        
        out = fscanf(handles.s);
        if (~isempty(out)|(sum(out == ':')>0&sum(out == 'W')>0))
            idxs = find(out == ':');
            idxw = find(out == 'W');
            readval = str2num(out(1,idxs+2:idxw-1));
        else
            display('CPX serial loss bite')
            readval = nanmean(buffer);
            break
        end
        if servoFlag ==1
            drawnow
            handles = guidata(hObject);
            servoangle = handles.servoangle;
            display(['Servo angle: ' num2str(servoangle)])
            fprintf(handles.s, '%s\n',['S' num2str(servoangle)]); %send comment to arduino
            handles.servoflag = 0;
            servoFlag = 0;
            guidata(hObject, handles);
        end
        t1 = cputime;
        buffertime(1:(N-1)) = buffertime(2:N);
        buffertime(N) = t1-t0;
        buffer(1:(N-1)) = buffer(2:N);
        if size(readval) ~=1
            readval;
            buffer(N) = 0.1;
        else
            buffer(N) = mean([buffer(N-3:N) readval]);
        end
        handles.Data = buffer;
        
        if sum(handles.Calibration) == 0
            set(h1,'XData',buffertime-buffertime(1),'YData',buffer);%drawnow
        else
            set(h1,'XData',buffertime-buffertime(1),'YData',buffer*handles.Calibration(1)+handles.Calibration(2));%drawnow
            set(handles.axes1,'ylim',[0 150])
            
        end
        pause(0.005) 
            
    else
       display('CPX Disconnected - Reading Stopped')
    end
    
    handles = guidata(hObject);
    handles.Data = buffer;
    StatusFlag = handles.StatusFlag;
    servoFlag = handles.servoflag;
    servoangle = handles.servoangle;
    guidata(hObject, handles);
    
    
end

function pushbutton_Stop_Callback(hObject, eventdata, handles)

display('Calibration Stopped')
handles.StatusFlag = 0;
guidata(hObject, handles);


function edit_CPX_Callback(hObject, eventdata, handles)

handles.Com = get(handles.edit_CPX,'String');
guidata(hObject, handles);


function edit_CPX_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function pushbutton_Load_Callback(hObject, eventdata, handles)

handles = guidata(hObject);
if ~isempty(handles.Load)
    mD = nanmean(handles.Data); %get average value from CPX data
    
    %new pair of data
    Pairs = [handles.DataPairs;mD handles.Load];
    handles.DataPairs = Pairs;
    
    %Re-estimate calibration (linear)
    if size(handles.DataPairs,1) >=2
        p = polyfit(handles.DataPairs(:,1),handles.DataPairs(:,2),1);
        handles.Calibration = p;
    else
        handles.Calibration = [0 0];
    end
    
    if ~isempty(handles.DataPairs)
        if size(handles.DataPairs,1)>=2
            cla(handles.axes2)
            axes(handles.axes2)
            hold on
            plot(handles.DataPairs(:,1),handles.DataPairs(:,2),'ko','markerfacecolor','k')
            line(handles.DataPairs(:,1),handles.DataPairs(:,1)*handles.Calibration(1)+handles.Calibration(2),'color','k')
            hold off
        end
    else
        cla(handles.axes2)
    end
   
end
guidata(hObject, handles);

function edit_Load_Callback(hObject, eventdata, handles)

handles = guidata(hObject);
newload = str2double(get(handles.edit_Load,'String'));
if length(newload) == 1
    if newload == 0;
        handles.Load = newload;
    else
        handles.Load = newload + 10; %Account for approximate weight of handle apparatus during calibration
        
    guidata(hObject, handles)
    end
else
    display('Load Value Should Be a Single Numerical Value')
end

function edit_Load_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function pushbutton_Save_Callback(hObject, eventdata, handles)

inside = handles.inside; 
onwall = handles.onwall; 
outside = handles.outside;
assessment = handles.assessment;

Calibration = handles.Calibration;
DataPairs = handles.DataPairs;
SCalibration = [inside onwall outside assessment]; 
uisave({'Calibration' 'DataPairs' 'SCalibration'}, 'Calibration.mat')

function pushbutton_reset_Callback(hObject, eventdata, handles)

display('Reset Calibration Data')
    handles.Calibration = [];
    handles.Data = [];
    handles.DataPairs = [];
    cla(handles.axes2)
    guidata(hObject, handles)

function pushbutton_LoadC_Callback(hObject, eventdata, handles)

uiload
handles.Calibration = Calibration;
handles.DataPairs = DataPairs;
guidata(hObject, handles)


function pushbutton_updateservo_Callback(hObject, eventdata, handles)

handles = guidata(hObject);
handles.servoflag = 1;
guidata(hObject, handles)


function edit_servoangle_Callback(hObject, eventdata, handles)

handles = guidata(hObject);
newangle = get(hObject,'String');
newangle = str2double(newangle);
if length(newangle) == 1&newangle>=0&newangle<=180
    handles.servoangle = newangle;
    guidata(hObject, handles)
else
    display('Angle value should be a single numerical value between 0-180')
end

function edit_servoangle_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_inside_Callback(hObject, eventdata, handles)

handles = guidata(hObject);
inside = get(hObject,'String');
inside = str2double(inside);
if length(inside) == 1 & inside >=0 & inside<=180
    handles.inside = inside;
    guidata(hObject, handles)
else
    display('Angle value should be a single numerical value between 0-180')
end

function edit_inside_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_onwall_Callback(hObject, eventdata, handles)

handles = guidata(hObject);
onwall = get(hObject,'String');
onwall = str2double(onwall);
if length(onwall) == 1 & onwall >=0 & onwall <=180
    handles.onwall = onwall;
    guidata(hObject, handles)
else
    display('Angle value should be a single numerical value between 0-180')
end

function edit_onwall_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function pellet_cal_Callback(hObject, eventdata, handles)

fprintf(handles.s, '%s\n',['P' num2str(0)]);



function outside_Callback(hObject, eventdata, handles)

handles = guidata(hObject);
outside = get(hObject,'String');
outside = str2double(outside);
if length(outside) == 1 & outside >=0 & outside <=180
    handles.outside = outside;
    guidata(hObject, handles)
else
    display('Angle value should be a single numerical value between 0-180')
end

function outside_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function assessment_Callback(hObject, eventdata, handles)

handles = guidata(hObject);
assessment = get(hObject,'String');
assessment = str2double(assessment);
if length(assessment) == 1 & assessment >=0 & assessment <=180
    handles.assessment = assessment;
    guidata(hObject, handles)
else
    display('Angle value should be a single numerical value between 0-180')
end

function assessment_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
