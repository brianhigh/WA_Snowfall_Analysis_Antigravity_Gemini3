# WA Snowfall Analysis

## Overview

This analysis explores the relationship between ENSO (El Niño/La Niña) climate patterns and snowfall in the Washington Cascades. We analyzed data from 4 SNOTEL sites over the last ~40 years.

## Results

### Monthly Snowfall by ENSO Phase

![Monthly Snowfall by ENSO Phase](plots/snowfall_by_enso_month.png)

This plot shows the average monthly snowfall (approximated from daily snow depth changes) for each site, categorized by ENSO phase.

#### Observations:

- La Niña years generally show higher snowfall across most sites and months.

### Percentage Difference (vs Neutral)

![Percentage Difference (vs Neutral)](plots/snowfall_pct_diff_strong_weak.png)

This plot compares the percentage difference in annual snowfall for Strong/Weak ENSO phases relative to Neutral years.

#### Observations:

- Strong La Niña consistently shows a positive percentage difference (more snow than neutral).
- At many sites, Weak La Niña shows a greater positive percentage difference than Strong La Niña.
- Both Weak and Strong El Niño show a widely varying percentage difference (sometimes more snow, sometimes less snow than neutral).
- Overall, the magnitude of the effect varies by site, with some sites showing more sensitivity than others.

## Methodology

### Data Sources:

- Snowfall: USDA NRCS SNOTEL (Stevens Pass, Olallie Meadows, Paradise, Wells Creek).
- ENSO: NOAA PSL Oceanic Niño Index (ONI).

### Processing:

- Snow Season defined as Nov-Apr.
- ENSO Phase classified using average ONI during the winter months (Nov-Mar).
- Snowfall approximated from daily snow depth increases.

---

See: [prompt.md](prompt.md) for the prompt used to generate this analysis in Antigravity using Gemini 3 Pro. No manual editing was done to the code. The README was made from the Walkthrough produced by Antigravity. Other than this paragraph, and correcting some of the interpretations of the results, only minor formatting changes were made to the README.

