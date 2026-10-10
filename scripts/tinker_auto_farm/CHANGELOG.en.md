**update v1.0.3**

- Added a 3-second window after respawn: the camp is not declared empty due to a check at the exact moment the creeps spawn. Waiting at the safe spot ends at the nearest check after respawn.
- Adjusted the mana evaluation for going to the camp: Rearm is now taken into account if it will be needed before the first March. This should prevent situations where the hero flies in and leaves without starting to farm.
- March now chooses its direction based on the actual location of the creeps in the selected camp, including the ancient camp, instead of a fixed direction toward the center.
- Removed the timer-based launch of March when no living creeps are detected in the lane, so as not to waste it on nothing.
- Increased the farming priority of the double camp under the outpost.
- Improved overall performance and speed.
