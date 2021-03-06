function test(expdef)
%UNTITLED Summary of this function goes here
%   Input: Handle to experiment definition function

% should this file (along with playground PTB) actually be in Rigbox (not signals)?
% global parameters?
% what does "apply parameters" button actually do?
% what all is playgroundPTB doing and what are diffs between it and playground?
% expdef (line 99) ?

addSignalsJava(); %adds necessary Java files (classes) to *signals*
global AGL GL GLU %#ok<NUSED> %used by PTB 
persistent defdir lastParams;


if isempty(defdir)
  defdir = '\\zserver\code\Rigging\ExpDefinitions';
end

if isempty(lastParams)
  lastParams = containers.Map('KeyType', 'char', 'ValueType', 'any');
end

if nargin < 1
  [mfile, mpath] = uigetfile(...
    '*.m', 'Select the experiment definition function', defdir);
  if mfile == 0
    return
  end
  defdir = mpath;
  [~, expdefname] = fileparts(mfile);
  expdef = fileFunction(mpath, mfile);
else
  expdefname = func2str(expdef);
end

parsStruct = exp.inferParameters(expdef);
parsStruct = rmfield(parsStruct, 'defFunction');
parsStruct.expRef = dat.constructExpRef('fake', now, 1);

%% boring UI stuff
parsWindow = figure('Name', sprintf('%s', expdefname),...
  'NumberTitle', 'off', 'Toolbar', 'none', 'Menubar', 'none',...
  'Position', [800 550 800 580]);
mainsplit = uiextras.HBox('Parent', parsWindow);
leftbox = uiextras.VBox('Parent', mainsplit);

parsEditor = eui.ParamEditor(exp.Parameters(parsStruct), leftbox);
ctrlgrid = uiextras.Grid('Parent', leftbox);
uicontrol('Parent', ctrlgrid, 'Style', 'pushbutton',...
  'String', 'Apply parameters', 'Callback', @applyPars);
uicontrol('Parent', ctrlgrid, 'Style', 'text',...
  'String', 'Trial');
uicontrol('Parent', ctrlgrid, 'Style', 'text',...
  'String', 'Reward delivered');
uicontrol('Parent', ctrlgrid, 'Style', 'text',...
  'String', 'Wheel Position');


uicontrol('Parent', ctrlgrid, 'Style', 'pushbutton',...
  'String', 'Start experiment', 'Callback', @startExp);
trialNumCtrl = uicontrol('Parent', ctrlgrid, 'Style', 'text',...
  'String', '0');
rewardCtrl = uicontrol('Parent', ctrlgrid, 'Style', 'text',...
  'String', '0');
wheelslider = uicontrol('Parent', ctrlgrid, 'Style', 'slider',...
  'Callback', @wheelSliderChanged, 'Min', -50, 'Max', 50, 'Value', 0);

ctrlgrid.ColumnSizes = [-1 -1];
ctrlgrid.RowSizes = [30 20*ones(1, 3)];

leftbox.Sizes = [-1 100];
% leftbox.Sizes = [-1 30 25];
% parslist = addlistener(parsEditor, 'Changed', @appl);
%% experiment framework
[t, setElems] = sig.playgroundPTB(expdefname, ctrlgrid);
% mainsplit.Sizes = [700 -1]; 
net = t.Node.Net;
% inputs & outputs
inputs = sig.Registry; %create inputs as logging signals
inputs.wheel = net.origin('wheel');
inputs.keyboard = net.origin('keyboard');
outputs = sig.Registry; %create outputs as logging signals
% video and audio registries
vs = StructRef; %holds visual signals as a structure (StructRef is ~overloaded MATLAB 'struct'
audio = audstream.Registry(); %assigning to registry posts samples assigned to it from audio device *without saving)
% events registry
evts = sig.Registry;
evts.expStart = net.origin('expStart');
evts.expStop = net.origin('expStop');
evts.newTrial = net.origin('newTrial');
evts.trialNum = evts.newTrial.scan(@plus, 0); % track trial number
advanceTrial = net.origin('advanceTrial');
% parameters
globalPars = net.origin('globalPars');
allCondPars = net.origin('condPars');

[pars, hasNext, repeatNum] = exp.trialConditions(...
  globalPars, allCondPars, advanceTrial);
expdef(t, evts, pars, vs, inputs, outputs, audio); %run expdef with origin signals 

setCtrlStr = @(h)@(v)set(h, 'String', toStr(v));
listeners = [
  evts.expStart.into(advanceTrial) %expStart signals advance
  evts.endTrial.into(advanceTrial) %endTrial signals advance
  advanceTrial.map(true).keepWhen(hasNext).into(evts.newTrial) %newTrial if more
  evts.trialNum.onValue(setCtrlStr(trialNumCtrl))
  ];

if isfield(outputs, 'reward')
  listeners = [listeners
    outputs.reward.scan(@plus, 0).onValue(setCtrlStr(rewardCtrl))];
end

% plotting the signals
sigsFig = figure('Name', 'LivePlot', 'NumberTitle', 'off'); 
tmr = timer('ExecutionMode', 'fixedSpacing', 'Period', 100e-3, 'Tag', 'figUpdate',...
    'TimerFcn', @(~, ~)plotSignals(sigsFig, evts), 'Name', 'FigUpdate');
set(sigsFig, 'CloseRequestFcn', @(s,c)stopAndClose(s,c,tmr));

  function applyPars(~,~)
    setElems(vs);
    [~, gpars, cpars] = toConditionServer(parsEditor.Parameters);
    globalPars.post(gpars);
    allCondPars.post(cpars);
    disp('pars applied');
  end

  function startExp(~,~)
    applyPars();
    evts.expStart.post(parsStruct.expRef);
    inputs.wheel.post(get(wheelslider, 'Value'));
  end

  function wheelSliderChanged(src, ~)
    pos = get(src, 'Value');
    if isempty(pos); return; end
    set(src, 'Min', pos - 50, 'Max', pos + 50);
    inputs.wheel.post(pos);
  end
  
  function stopAndClose(~,~,tmr)
    stop(tmr);
    delete(tmr);
    delete(gcf);
  end

end