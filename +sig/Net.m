classdef Net < handle
  %sig.Net A network that can contain sig.node.Node's.
  %   A network that contains and manages sig.node.Node's.
  
  properties (Transient)
    % A structure holding node ids, the values they should take and the
    % delay before they are applied.  Used for delayed posting of values.
    Schedule
    Listeners
  end
  
  properties (SetAccess = private, Transient)
    Id
  end
  
  events
    Deleting
  end
  
  methods
    function this = Net(size)
      if nargin < 1
        size = 4000;
      end
      this.Id = createNetwork(size);
      this.Schedule = struct('nodeid', {}, 'value', {}, 'when', {});
    end
    
    function runSchedule(this)
    % Apply values to nodes that are due to be updated
    %
    %   Applies values to nodes that are due to be updated, i.e. those that
    %   have a delayed post.  This method should be manually run or set as
    %   a callback in a timer function.
    %   Example:
    %     net = sig.Net; % Create network
    %     tmr = timer('TimerFcn', @(~,~)net.runSchedule,...
    %       'ExecutionMode', 'fixedrate', 'Period', 0.01);
    %     start(tmr) % Run schedule every 100 ms
    %     
    %     delayedSig = sig1.delay(5) % New signal delayed by 5 sec
    %     h = output(delayedSig);
    %     delayedPost(s, pi, 5) % Post to input signal also delayed by 5 sec
    %     ... 10 seconds later...
    %     3.1416
    %
    % See also sig.node.OriginSignal/delayedPost, sig.node.Signal/delay
      if numel(this.Schedule) > 0
        % slice out due tasks
        dueIdx = [this.Schedule.when] < GetSecs;
        dueTasks = this.Schedule(dueIdx);
        this.Schedule(dueIdx) = [];
        % work through them
        for ti = 1:numel(dueTasks)
          dt = GetSecs - dueTasks(ti).when;
          affectedIdxs = submit(this.Id, dueTasks(ti).nodeid, dueTasks(ti).value);
          changed = applyNodes(this.Id, affectedIdxs);
        end
      end
    end
    
    function s = origin(this, name)
      % Create an origin signal with a specified name
      %  Returns a signal of the class 'OriginSignal', which can have its
      %  values set via the post method.  The name is an optional string
      %  identifier.
      %
      %  Example:
      %   net = sig.Net; % Create network
      %   inputSig = net.origin('input');
      %   post(inputSig, pi)
      %   inputSig.Node.CurrValue
      %   >> ans =
      %          3.1416
      %
      % See also sig.node.OriginSignal, sig.Net.subscriptableOrigin
      s = sig.node.OriginSignal(rootNode(this, name));
    end
    
    function s = subscriptableOrigin(this, name)
      % Create a subscriptable origin signal with a specified name
      %  Returns a signal of the class 'SubscriptableOriginSignal', which
      %  can have its values set via the post method.  This signal can be
      %  subscripted to obtain a new signal whose value results from
      %  subscripting the value of the Origin Signal. The name is an
      %  optional string identifier.
      %
      %  Example:
      %   net = sig.Net; % Create network
      %   structSig = net.subscriptableOrigin('structSig');
      %   post(structSig, struct('a', 1, 'b', 2)) % Post a structure
      %   s = structSig.a;
      %   class(s)
      %   >> ans = 
      %         'sig.node.Signal'
      %   s.Node.CurrValue % FIXME: this doesn't work!!
      %   >> ans = 
      %         1
      %
      % See also sig.Net.OriginSignal, sig.node.SubscriptableOriginSignal
      s = sig.node.SubscriptableOriginSignal(rootNode(this, name));
    end
    
    function s = fromUIEvent(this, uihandle, callback)
      if nargin < 3
        callback = 'Callback';
      end
      name = sprintf('%s@%sEvents', get(uihandle, 'Type'), callback);
      s = sig.node.SubscriptableOriginSignal(rootNode(this, name));
      set(uihandle, callback, @(src,evt)post(s, evt));
    end
    
    function n = rootNode(this, name)
    % Create a new node with a specified name
    %  The name of a node is usually a string representation of its
    %  transfer function (the FormatSpec), however some nodes (i.e. ones
    %  that simply hold a value, such a seed), have no transfer function.
    %  This function allows one to create such a node.  If the name is not
    %  specified, the node's id is used instead.
    %
    % See also sig.node.Node
      n = sig.node.Node(this);
      if nargin < 2
        n.Name = sprintf('n%i', n.Id);
      else
        n.Name = name;
      end
      n.FormatSpec = n.Name;
    end
    
    function delete(this)
      disp('**net.delete**');
      if ~isempty(this.Id)
        notify(this, 'Deleting');
        deleteNetwork(this.Id);
      end
    end
  end
  
  methods (Access = protected)
%     function mexNetworkDeleted(this)
%       fprintf('network #%i''s storage deleted\n', this.Id);
%       this.Id = [];
%     end
  end
  
end