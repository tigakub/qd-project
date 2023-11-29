# qd-project
Quadruped robot project including STL models for 3D-Printing, BOM, and code.

## Introduction
QD is a simple robot quadruped which uses Dynamixel servos for actuation, and an Arduino MKR 1000 WIFI for on-board processing and wireless communication. The Arduino microcontroller is a bit anemic, so motion planning is performed off-board on a host computer which then sends simple joint poses as UDP packets over wifi to the microcontroller.

As of 11/29/2023, the control software is written in Swift for macOS, and is extremely rudimentary. Though the motion path is represented as a hard-coded b-spline curve, the app performs foot placement planning dynamically along this path over time, based on a specified step size and body sway magnitude. My goal in writing this software was to get a real-world idea of how QD must shift its body to maintain balance on three legs while moving the fourth, and not really to provide a viable control interface.

In real world testing, QD accomplishes linear motion with some efficacy, but angular motion is sub-par. I overestimated the accuracy of the limb poses, resulting in quite a bit of error between calculated and actual foot placement.

Based on what I have learned about foot placement interpolation, I plan to develop a new app which will allow for more direct control.
