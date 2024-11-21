# TV Store Mode
11/20/24

## Summary of Failure
We missed the Black Friday/Christmas release of our operating system app because the store mode basically didn't work as designed. The panel would not boot up to the correct power state and the _previously playing_ item (HDMI, Demo Video, USB Asset) would not relaunch. This relaunch to the previously playing item was a new feature developed during this release. The "boot to correct power state" hasn't been working for 3 years and only through this process of testing the "return previously playing item" over the course of 6 days did we discover that things weren't working.

There is a 6 day reboot built into the device, that will force reboot the panel. This is precautionary measure that if the device has been running for 6 days straight, clear the memory and reset everything (Reasonable safeguard). In stores that may be playing the demo video or something like that for consecutive days on end, when they hit this threshold and reboot, they should be returned to that same screen the left from. This was not happening.

## Root Cause
 * There were 2 reboot timers, one managed by the operating system app, and one by the lower-level application. No one knew about the duplicate timers and so we didn't know _who_ was causing the reboot and assumed it was us (race condition - turns out, 99% of the time it was actually them, since they started up first and started their timer first). This is because over time, the tribal knowledge of the implementation was lost.
 * The "reasons" that the lower-level provided the operating system app, which helped determine the startup power state, did not line up with what was expected.
 * The operating system wrote the old power state to local storage, and under certain reboot conditions, this value would get over written (I believe this had to do with receiving the the shutdown power state before unsubscribing to it). So this value was not the expected value when being read, which also occurred when determining the startup power state.
 * There was no way to test this scenario, as the typical test we did at the operating system level would be to override the 6 day timer to a shorter time frame (20 min) and so, the OS app would always be the one to call the reboot, providing a _more predictable _ and _expected_ experience during testing.
 * There was no way to override the lower-level reboot timer, so we needed to run for a full 6 days in order to run into this scenario

## Lessons Learned
1. I now have a point of contact with the lower-level app. Just because code was written 3 years ago and worked then (maybe), doesn't mean that it's behaving as expected. *Confirm with interfacing applications that their 'contract' works as expected.*
2. Testing: There should be a way to test anything so that it doesn't require _waiting for a timer_ to be validated. *Know the critical path for what you're trying to test.*