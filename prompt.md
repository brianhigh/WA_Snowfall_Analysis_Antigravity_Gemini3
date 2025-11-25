[ Antigravity prompt settings:  ^Planning  ^Gemini 3 Pro (High) ]

Write an R script which reproduces the following analysis, including generation of 
all plots, as well as the web scraping steps needed to download and import 
real data from respected sources. Use pacman::p_load() for loading R packages.
Produce an implementation plan in Markdown, write the code, then test and debug. 
Plots should show the data year range in the title and data source in the caption.
The full path to Rscript.exe is: "C:\Program Files\R\R-4.5.1\bin\Rscript.exe".
Save data as CSV files in "data" folder and plots as PNG files in "plots" folder.

- Science question:
  - How do El Niño & La Niña climate patterns relate to snowfall in WA Cascades?
- Create a plot comparing snowfall during El Niño and La Niña years for WA Cascade 
  sites (mountain passes, resorts, or other notable locations), by site and month.
- Consider a snow season as starting in Nov. and ending in April of the next year.
  - When plotting by month, order the months as: Nov, Dec, Jan, Feb, Mar, Apr.
- Compare snowfall in strong vs weak intensities for both La Niña and El Niño years 
  and show percentage snowfall difference from neutral years by site in a new plot.
- When plotting, use these climate patterns (and colors), in order
    - Strong La Nina (blue), Weak La Nina (light blue), Neutral (light purple), 
      Weak El Nino (light red), Strong El Nino (red)
