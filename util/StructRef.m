classdef StructRef < handle
  %STRUCTREF Container for subassigning and referencing signals
  %  Container class for holding groups of signals. 
  %
  %  See also SIG.REGISTRY, AUDSTEREAM.REGISTRY 
  
  properties
    Name = ''
  end

  properties (SetAccess = protected)
    Entries = struct()
    EntryNames = {}
    Reserved = {}
  end
  
  methods (Sealed)
    function A = subsasgn(this, s, varargin)
      newentry = false;
      if strcmp(s(1).type, '.') && ~any(strcmp(this.EntryNames, s(1).subs))
        newentry = true;
        newentryname = s(1).subs;
      end
      this.Entries = builtin('subsasgn', this.Entries, s, varargin{:});
      A = this;
      if newentry
        this.EntryNames = [this.EntryNames {newentryname}];
        this.Entries.(newentryname) = entryAdded(this, newentryname, this.Entries.(newentryname));
      end
    end
    
    function [varargout] = subsref(this, s)
      if any(strcmp(this.Reserved, s(1).subs))
        % If subscripted reference is a reserved property, use builtin
        [varargout{1:nargout}] = builtin('subsref', this, s);
      else % Otherwise return entry value
        [varargout{1:nargout}] = subsref(this.Entries, s);
      end
    end
  end

  methods
    function n = fieldnames(this)
      n = this.EntryNames';
    end
    
    function c = struct2cell(this)
      c = struct2cell(this.Entries);
    end
    
    function tf = isfield(this, varargin)
      tf = isfield(this.Entries, varargin{:});
    end
    
    function value = entryAdded(this, name, value)
    % ENTRYADDED Assigns an entry to Entries
    %   Allows an inputs to be processed before assignent to Entries.
    %   This function is intended to be overloaded by subclasses.
%       fprintf('entry %s:%s added\n', name, toStr(value));
    end
  end
end
