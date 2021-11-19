# autoRG
# Initial Developers: Braxton Goodnight, Rameen Forghani, Charles Latchoumane, Lohitash Karumbaiah
Includes all software code (GUI1 and GUI_scale_calibration), firmware (Arduino IDE), STL files for 3D printing, bill of commercial materials, and SOPs for the assembly of the autoRG system, downloading and initializing software, calibrating the system, and executing the assay.

# Requirements
* Matlab 2020a or newer (Earlier versions may be able to run system, but is not guaranteed)
* Windows 10 Computer
* Circuit Playground Express (CPX) (Adafruit Industries) and all other commercial electronics (see AutoRG_Assembly_SOP and Electronics_Bill_of_Materials) for CPX bootloading and assay execution

# Purpose
The autoRG system was developed to assist researchers in neurological studies of rat motor behavior. The system's hardware, software, and firmware was developed to be user-friendly, modular, reproducible, and low-cost to maximize objectivity and access to in vivo functional assessments. 

# Version 1
autoRG v1 utilizes a discrete, 7-stage training system that requires the user to manually determine when the rat has passed the criteria for that stage and select the correct stage for each rat in the menu options prior to each session. Modulation of the handle location, trigger threshold, and pellet dispenses is controlled by the update_param function. Current criterion for stage advancement using default training protocol: 
* Stage 1 - 60 successes each in two consecutive sessions
* Stage 2 - 45 successes in single session
* Stage 3 - 30 successes in single session
* Stage 4 - 30 successes in single session
* Stage 5 - 30 successes in single session
* Stage 6 - 30 successes in single session
* Stage 7 - 30 successes in single session, or until desired efficiency (# of successes / total # of reaches) is reached

# Contributions
Users can contribute to this repository by customizing the update_param function to introduce their own training schemes that train the rats more rapidly or reinforce a slightly different behavior. Further, fixes to any bugs that may arise across operating systems are encouraged. Potential training schemes to implement: 
* Continuous stage advancement - System advances rat to next stage automatically by automated measurement of some metric(s)
* Adaptive Training - System automatically progresses or modulates the trigger threshold (e.g., median of prior 10 reaches) and handle location with upper and lower boundaries
* Machine Learning - System learns which metrics are predictive of future successes or future failures and uses this information to modulate the assay parameters (handle location, trigger threshold, pellet dispenses)
