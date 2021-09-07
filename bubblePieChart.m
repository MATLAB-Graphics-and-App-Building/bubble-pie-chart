classdef bubblePieChart < matlab.graphics.chartcontainer.ChartContainer & ...
        matlab.graphics.chartcontainer.mixin.Legend
    % bubblePieChart Creates a bubble pie chart.
    %   bubblePieChart(x,y,p) create a bubble pie chart with the specified
    %   pie locations and data. The sizes of the pies are determined
    %   automatically based on the pie data.
    %
    %   bubblePieChart(x,y,p,s) create a bubble pie chart with
    %   the specified size for each pie in points, where one point equals
    %   1/72 of an inch. s can be a scalar or a vector the same length as x
    %   and y. If s is a scalar, the same size is used for all pies.
    %
    %   bubblePieChart() create a bubble pie chart using only name-value
    %   pairs.
    %
    %   bubblePieChart(___,Name,Value) specifies additional options for
    %   the bubble pie chart using one or more name-value pair arguments.
    %   Specify the options after all other input arguments.
    %
    %   bubblePieChart(parent,___) creates the bubble pie chart in the
    %   specified parent.
    %
    %   b = bubblePieChart(___) returns the bubblePieChart object. Use b
    %   to modify properties of the plot after creating it.
    
    % Copyright 2020-2021 The MathWorks, Inc.

    properties
        % x-axis locations of the pies
        XData (1,:) = []
        
        % y-axis locations of the pies
        YData (1,:) = []
        
        % Pie data, specified as a matrix, where each row corresponds to
        % the data for one pie
        PieData {mustBeNumeric} = []
        
        % Pie sizes, diameters in points (1/72 inch)
        SizeData (1,:) {mustBeNumeric} = 50
        
        % Line style to use for drawing pies
        LineStyle {mustBeMember(LineStyle,{'-', '--',':','-.','none'})} = '-'
        
        % Names of the pie categories
        Labels (:,1) categorical = categorical.empty(0,1)
        
        % Title of the plot
        Title (:,1) string = ""
        
        % Subtitle of the plot
        Subtitle (:,1) string = ""
        
        % x-label of the plot
        XLabel (:,1) string = ""
        
        % y-label of the plot
        YLabel (:,1) string = ""
        
        % Mode for the x-limits.
        % Note that it is not a dependent property since auto limits are
        % set by the chart and not the axes
        XLimitsMode (1,:) char {mustBeAutoManual} = 'auto'
        
        % Mode for the y-limits.
        YLimitsMode (1,:) char {mustBeAutoManual} = 'auto'
    end

    properties (Access = protected)
        % Used for saving to .fig files
        ChartState = []
    end

    properties(Access = private,Transient,NonCopyable)
        % Array of parent transforms for the pies
        PieChartArray (1,:) matlab.graphics.primitive.Transform
        
        % Boolean specifying if PieData was changed since the previous call
        % to update. If true, all pies need to be redrawn.
        PieDataChanged logical = true
    end
    
    properties (Dependent)
        % List of colors to use for pie categories
        ColorOrder {validatecolor(ColorOrder, 'multiple')} = get(groot, 'factoryAxesColorOrder')
        
        % x-limits of the plot
        XLimits (1,2) double {mustBeLimits} = [0 1]
        
        % y-limits of the plot
        YLimits (1,2) double {mustBeLimits} = [0 1]
    end

    methods
        function obj = bubblePieChart(varargin)
            % Initialize list of arguments
            args = varargin;
            leadingArgs = cell(0);

            % Check if the first input argument is a graphics object to use as parent.
            if ~isempty(args) && isa(args{1},'matlab.graphics.Graphics')
                % bubblePieChart(parent, ___)
                leadingArgs = args(1);
                args = args(2:end);
            end

            % Check for optional positional arguments.
            if ~isempty(args) && numel(args) >= 3 && isnumeric(args{1}) ...
                    && isnumeric(args{2}) && isnumeric(args{3})
                if mod(numel(args),2) == 1
                    % bubblePieChart(x,y,p)
                    % bubblePieChart(x,y,p,Name,Value)
                    x = args{1};
                    y = args{2};
                    p = args{3};
                    
                    % set size automatically. The largest pie has size 50
                    % and the others are scaled relative to it
                    totals = sum(p,2);
                    ratios = totals/max(totals);
                    s = 50*ratios;
                    leadingArgs = [leadingArgs {'XData', x, 'YData', y, 'PieData', p, 'SizeData', s}];
                    args = args(4:end);
                elseif mod(numel(args),1) == 0
                    % bubblePieChart(x,y,p,s)
                    % bubblePieChart(x,y,p,s,Name,Value)
                    x = args{1};
                    y = args{2};
                    p = args{3};
                    s = args{4};
                    leadingArgs = [leadingArgs {'XData', x, 'YData', y, 'PieData', p, 'SizeData', s}];
                    args = args(5:end);
                else
                    error('bubblePieChart:InvalidSyntax', ...
                        'Specify x locations, y locations, pie data, and optionally size data.');
                end
            end
            
            % Combine positional arguments with name/value pairs.
            args = [leadingArgs args];

            % Call superclass constructor method
            obj@matlab.graphics.chartcontainer.ChartContainer(args{:});
        end

    end

    methods(Access = protected)

        function setup(obj)
            % Create the axes
            ax = getAxes(obj);
            ax.Units = 'points';
            
            % make limit mode manual so that we can control the limits
            ax.XLimMode = 'manual';
            ax.YLimMode = 'manual';
            
            % Set axes interactions
            ax.Interactions = [
                panInteraction;
                zoomInteraction;
                rulerPanInteraction];
            
            % Set restoreview button callback
            btn = axtoolbarbtn(axtoolbar(ax), 'icon', 'restoreview');
            btn.ButtonPushedFcn  = @(~,~) update(obj);
            
            % Call the load method in case of loading from a fig file
            loadstate(obj);
        end

        function update(obj)
            ax = getAxes(obj);
            
            % Verify that the data properties are consistent with one
            % another.
            showChart = verifyDataProperties(obj);
            set(obj.PieChartArray,'Visible', showChart);
            
            % Abort early if not visible due to invalid data.
            if ~showChart
                return
            end
            
            % If pie data is changed, delete and recreate all pies
            if obj.PieDataChanged
                delete(obj.PieChartArray);
                hold(ax,'on');
                   for r = 1:size(obj.PieData,1)
                       % Create new Transform
                       t = hgtransform('Parent',ax);
                       obj.PieChartArray(r) = t;
                       
                       % Create new pie with transform as parent
                       x = obj.PieData(r,:);
                       myPie(t,x);
                   end
                hold(ax,'off')
                
                obj.PieDataChanged = false;
            end
            
            % Set only the first pie chart to show in the legend
            obj.PieChartArray(1).Annotation.LegendInformation.IconDisplayStyle = 'children';
            
            % Update legend labels
            if ~isempty(obj.Labels)
                lgd = getLegend(obj);
                lgd.String = obj.Labels;
            end
            
            % Set Colormap based on ColorOrder
            ax.Colormap = obj.ColorOrder(mod(0:size(obj.PieData,2)-1,size(obj.ColorOrder,1))+1,:);
           
            % Automatically set axes limits
            if strcmp(obj.XLimitsMode,'auto')   
                obj.setAutoXLimits();
            end
            
            if strcmp(obj.YLimitsMode,'auto')
                obj.setAutoYLimits();
            end
            
            % Set position, scale, and style of each pie
            for i = 1:length(obj.PieChartArray)
               % move and scale pies
               txy = makehgtform('translate', ...
                   [obj.XData(i), obj.YData(i), 0]);
               
               % Determine scale to use
               % divide by 2 since SizeData corresponds to diameter, and
               % default pies have radius of 1
               if isscalar(obj.SizeData)
                   scale = obj.SizeData/2;
               else
                   scale = obj.SizeData(i)/2;
               end
               
               % Convert scale from axis units to data units
               sx = (ax.XLim(2) - ax.XLim(1))*scale/ax.Position(3);
               sy = (ax.YLim(2) - ax.YLim(1))*scale/ax.Position(4);
               
               sxy = makehgtform('scale',[sx, sy, 1]);
               
               obj.PieChartArray(i).Matrix = txy * sxy;
               
               patches = findall(obj.PieChartArray(i), 'Type', 'Patch');
               set(patches,'LineStyle',obj.LineStyle);
            end
            
            % Set title
            title(ax, obj.Title, obj.Subtitle);
            
            % Set axis labels
            xlabel(ax, obj.XLabel);
            ylabel(ax, obj.YLabel);
        end
        
        function showChart = verifyDataProperties(obj)
            % x and y must be the same length.
            showChart = numel(obj.XData) == numel(obj.YData);
            if ~showChart
                warning('bubblePieChart:DataLengthMismatch',...
                    'XData and YData must be the same legnth');
                return
            end
            
            % PieData must have the same number of rows as the length of x
            showChart = size(obj.PieData,1) == numel(obj.XData); 
            if ~showChart
                warning('bubblePieChart:DataLengthMismatch',...
                    'PieData must have the same number of rows as XData.');
                return
            end
            
            % SizeData must be a scalar or be the same length as x
            showChart = isscalar(obj.SizeData) || numel(obj.SizeData) == numel(obj.XData);
            if ~showChart
                warning('bubblePieChart:DataLengthMismatch',...
                    'SizeData must be a scalar or have the same number of rows as XData.');
                return
            end
        end
    end

    methods
        function data = get.ChartState(obj)
            % This method gets called when a .fig file is saved
            isLoadedStateAvailable = ~isempty(obj.ChartState);

            if isLoadedStateAvailable
                data = obj.ChartState;
            else
                data = struct;
                ax = getAxes(obj);

                % Get axis limits only if mode is manual.
                if strcmp(ax.XLimMode,'manual')
                    data.XLim = ax.XLim;
                end
                if strcmp(ax.YLimMode,'manual')
                    data.YLim = ax.YLim;
                end
            end
        end

        function loadstate(obj)
            % Call this method from setup to handle loading of .fig files
            data=obj.ChartState;
            ax = getAxes(obj);

            % Look for states that changed
            if isfield(data, 'XLim')
                ax.XLim=data.XLim;
            end
            if isfield(data, 'YLim')
                ax.YLim=data.YLim;
            end
        end
        
        function set.PieData(obj,val)
            obj.PieData = val;
            obj.PieDataChanged = true;
        end
        
        function updateNow(obj)
            update(obj);
        end
        
        function set.ColorOrder(obj, map)
            ax = getAxes(obj);
            ax.ColorOrder = validatecolor(map, 'multiple');
        end
        
        function map = get.ColorOrder(obj)
            ax = getAxes(obj);
            map = ax.ColorOrder;
        end
        
        % xlim method
        function varargout = xlim(obj,varargin)
            ax = getAxes(obj);
            [varargout{1:nargout}] = xlim(ax,varargin{:});
        end
        % ylim method
        function varargout = ylim(obj,varargin)
            ax = getAxes(obj);
            [varargout{1:nargout}] = ylim(ax,varargin{:});
        end
        
        % set and get methods for XLimits
        function set.XLimits(obj,xlm)
            ax = getAxes(obj);
            ax.XLim = xlm;
        end
        function xlm = get.XLimits(obj)
            ax = getAxes(obj);
            xlm = ax.XLim;
        end
        % set and get methods for YLimits
        function set.YLimits(obj,ylm)
            ax = getAxes(obj);
            ax.YLim = ylm;
        end
        function ylm = get.YLimits(obj)
            ax = getAxes(obj);
            ylm = ax.YLim;
        end
    end
    
    methods(Access=private)
        
        % Helper function for auotmatically setting x-limits
        function setAutoXLimits(obj)  
            ax = getAxes(obj);
            
            minX = min(obj.XData);
            maxX = max(obj.XData);
            
            if(minX==maxX)
                minX = minX-1;
                maxX = maxX+1;
            end
                
            maxRadius = min(max(obj.SizeData)/2, ax.Position(3)/3);
            
            A = [-maxRadius+ax.Position(3) maxRadius;
                 maxRadius ax.Position(3)-maxRadius];
            b = [minX*ax.Position(3); maxX*ax.Position(3)];
            xlimits = A\b;
            obj.XLimits = xlimits;
            end
        
        % Helper function for auotmatically setting y-limits
        function setAutoYLimits(obj)  
            ax = getAxes(obj);
            
            minY = min(obj.YData);
            maxY = max(obj.YData);
            
            if(minY==maxY)
                minY = minY-1;
                maxY = maxY+1;
            end
            
            maxRadius = min(max(obj.SizeData)/2, ax.Position(4)/3);
            
            A = [-maxRadius+ax.Position(4) maxRadius;
                 maxRadius ax.Position(4)-maxRadius];
            b = [minY*ax.Position(4); maxY*ax.Position(4)];
            ylimits = A\b;
            obj.YLimits = ylimits;
        end
    end
end

function mustBeLimits(a)
    if numel(a) ~= 2 || a(2) <= a(1)
         throwAsCaller(MException('densityScatterChart:InvalidLimits', 'Specify limits as two increasing values.'))
    end
end

function mustBeAutoManual(mode)
    mustBeMember(mode, {'auto','manual'})
end

% Helper function for creating pies baesd on MATLAB's pie function
function h = myPie(ax,x)

    % Normalize input data
    x = x/sum(x);

    h = [];
    theta0 = pi/2;
    maxpts = 100;

    for i=1:length(x)
        n = max(1,ceil(maxpts*x(i)));
        r = [0;ones(n+1,1);0];
        theta = theta0 + [0;x(i)*(0:n)'/n;0]*2*pi;
        [xx,yy] = pol2cart(theta,r);
        theta0 = max(theta);
        h = [h,...
            patch('XData',xx,'YData',yy,'CData',i*ones(size(xx)), ...
                'FaceColor','Flat','parent',ax)]; %#ok<AGROW>
    end
end