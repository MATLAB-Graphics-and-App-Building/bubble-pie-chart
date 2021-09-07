# Bubble Pie Chart

[![View Bubble Pie Chart on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://www.mathworks.com/matlabcentral/fileexchange/98874-bubble-pie-chart)

Version: 1.0

bubblePieChart Creates a bubble pie chart.

![Example bubblePieChart](/exampleBubblePieChart.png)

How to use:
```
bubblePieChart(x,y,p) create a bubble pie chart with the specified
pie locations and data. The sizes of the pies are determined
automatically based on the pie data.

bubblePieChart(x,y,p,s) create a bubble pie chart with
the specified size for each pie in points, where one point equals
1/72 of an inch. s can be a scalar or a vector the same length as x
and y. If s is a scalar, the same size is used for all pies.

bubblePieChart() create a bubble pie chart using only name-value
pairs.

bubblePieChart(___,Name,Value) specifies additional options for
the bubble pie chart using one or more name-value pair arguments.
Specify the options after all other input arguments.

bubblePieChart(parent,___) creates the bubble pie chart in the
specified parent.

b = bubblePieChart(___) returns the bubblePieChart object. Use b
to modify properties of the plot after creating it.
```

