# Training zones and charts

Both heart-rate and cycling power zones appear on the main workout screen. Swipe left to see the individual metric's chart and scroll for time in each zone. Saved summaries and History retain the same charts and distributions.

## Your profile

Open **Training zones** from Home or Settings. Explicitly save your measured maximum heart rate and cycling functional threshold power (FTP). The picker offers a starting position, but no value becomes a personal setting until you press Save. Clear a value to disable that zone scale. There is no age-based estimate or silent default for real workouts.

Each workout captures the profile at its start. Later changes do not reclassify old workouts. The demo uses an explicitly simulated 190 bpm maximum and 240 W FTP, independently of personal settings, and never writes its data to Health or history.

## Boundaries

Heart rate uses percentages of configured maximum heart rate:

| Band | Range |
| --- | --- |
| Below Z1 | Below 50% |
| Z1 · Recovery | 50% to below 60% |
| Z2 · Endurance | 60% to below 70% |
| Z3 · Aerobic | 70% to below 80% |
| Z4 · Threshold | 80% to below 90% |
| Z5 · Maximum | 90% and above |

Cycling power uses a seven-band FTP scale:

| Band | Range |
| --- | --- |
| Z1 · Recovery | 0% through 55% |
| Z2 · Endurance | Above 55% through 75% |
| Z3 · Tempo | Above 75% through 90% |
| Z4 · Threshold | Above 90% through 105% |
| Z5 · VO₂ max | Above 105% through 120% |
| Z6 · Anaerobic | Above 120% through 150% |
| Z7 · Sprint | Above 150% |

These comparisons are continuous, including fractional watts or bpm. Range labels use inequality symbols to make inclusion explicit. Values above the configured maximum heart rate remain in Z5. A genuine zero-watt sample is Z1; a missing power sample is not. Zero heart rate is invalid.

The heart-rate percentages follow [Bevel's maximum-heart-rate method](https://www.bevel.health/blog/heart-rate-zones). The FTP thresholds use the conventional seven-band scheme based on [Andrew Coggan's power training levels](https://www.trainingpeaks.com/blog/power-training-levels/), with a numeric >150% boundary for the highest display band. These labels organize recorded intensity; the app does not prescribe training or calculate Bevel's proprietary scores. Visual inspiration: [Bevel](https://www.bevel.health/). No Bevel assets or code are bundled.

## Time and signal coverage

- Time runs on the workout's active clock and excludes pauses.
- Each observation holds its value until the next observation, pause/disconnect, or freshness expiry: 20 seconds for heart rate and 5 seconds for power. Delayed heart-rate notifications retain the original sample's expiry and do not backfill unknown time.
- Zone percentages use recorded time for that metric. Unobserved active time appears separately as **No signal**. The two metrics can have different coverage.
- Pause, disconnect, and process recovery clear held values. New samples begin a new chart segment; the chart does not draw a line across the gap.
- Chart averages are weighted by observed time. HealthKit's own sample-based average is still retained in the workout summary data and can differ from this chart average.
- Peak is the highest accepted observation, including short samples. There is no smoothing that could introduce values above measured peaks.

## Storage

Analytics are included in the existing atomic, protected workout checkpoint and local history. Recovery restores accrued totals and the original profile without extending a previous reading across a process interruption. Older saved summaries remain readable and show their original summary metrics; they do not invent a chart.

Each metric chart retains at most 600 display points. Long series are progressively thinned while preserving their start and latest point. Zone totals, weighted averages, and peaks are accumulated separately and are unaffected by display thinning. Local history remains capped at 100 workouts. Detailed chart data stays on the Watch; HealthKit receives the original supported workout measurements through the existing recording flow.
