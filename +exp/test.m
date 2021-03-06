function test(expdef)
%UNTITLED Summary of this function goes here
%   Input: Handle to experiment definition function

addSignalsJava();
global AGL GL GLU %#ok<NUSED>
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
% wheelslider = uicontrol('Parent', ctrlgrid, 'Style', 'slider',...
%   'Callback', @wheelSliderChanged, 'Min', -50, 'Max', 50, 'Value', 0);
wheelslider = uicontrol('Parent', ctrlgrid, 'Style', 'slider',...
  'Min', -50, 'Max', 50, 'Value', 0);


ctrlgrid.ColumnSizes = [-1 -1];
ctrlgrid.RowSizes = [30 20*ones(1, 3)];

leftbox.Sizes = [-1 100];
% leftbox.Sizes = [-1 30 25];
% parslist = addlistener(parsEditor, 'Changed', @appl);
%% experiment framework
[t, setElems, curser] = sig.playgroundPTB(expdefname, ctrlgrid);
% mainsplit.Sizes = [700 -1]; 
net = t.Node.Net;
% inputs & outputs
inputs = sig.Registry;
wx = net.fromUIEvent(wheelslider);
inputs.wheel = net.origin('wheel');
% inputs.wheel = net.origin('wheel');
inputs.keyboard = net.origin('keyboard');
outputs = sig.Registry;
% video and audio registries
vs = StructRef;
audio = audstream.Registry();
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
expdef(t, evts, pars, vs, inputs, outputs, audio);

setCtrlStr = @(h)@(v)set(h, 'String', toStr(v));
listeners = [
  evts.expStart.into(advanceTrial) %expStart signals advance
  evts.endTrial.into(advanceTrial) %endTrial signals advance
  advanceTrial.map(true).keepWhen(hasNext).into(evts.newTrial) %newTrial if more
  evts.trialNum.onValue(setCtrlStr(trialNumCtrl))
  curser.into(inputs.wheel)
%   wx.onValue(@(e)post(inputs.wheel,e.Source.Value))
%   wx.onValue(@(e)set(e.Source,'Min', e.Source.Value - 50, 'Max', e.Source.Value + 50))
  ];

if isfield(outputs, 'reward') % TODO display all outputs in UI
  listeners = [listeners
    outputs.reward.scan(@plus, 0).onValue(setCtrlStr(rewardCtrl))];
end

% plotting the signals
sigsFig = figure('Name', 'LivePlot', 'NumberTitle', 'off', 'Color', 'w'); 
listeners = [listeners 
  sig.timeplot(t, evts, 'parent', sigsFig, 'mode', 0, 'tWin', 5)];

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
    set(src, 'Min', get(src, 'Value') - 50, 'Max', get(src, 'Value') + 50);
    inputs.wheel.post(get(src, 'Value'));
  end
 

end