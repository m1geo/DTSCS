DT-SCS Light - Contiki-OS
=========================

This folder containts a light implementation of the *Decentralized Time-Synchronized Channel Swapping (DT-SCS)* MAC protocol for Ad-Hoc Wireless Networks. The code is written in C for [Contiki open source operating system](http://www.contiki-os.org/), version 2.7, for TelosB (T-mote Sky) wireless sensor motes.  Other variations of Contiki and mote are not guaranteed compatible.

This code is built as an application layer program inside Contiki-OS for ease of implementation and future understanding.  To this end, we disable the standard Contiki MAC and radio duty cycler (RDC) [[here](http://dunkels.com/adam/dunkels11contikimac.pdf)] and, instead, handle these functions inside the DT-SCS application code.  To allow this pass-through behaviour, we use the *nullmac* and *nullrdc* drivers, which are selected inside `project-conf.h`.

>&#35;define NETSTACK_CONF_RDC nullrdc_driver
>&#35;define NETSTACK_CONF_MAC nullmac_driver

More on the MAC and RDC settings of Contiki-OS [can be found here](https://github.com/contiki-os/contiki/wiki/Change-mac-or-radio-duty-cycling-protocols).  The `Makefile` further contains a `CFLAG` to instruct the compiler to include the `project-conf.h` file.

>CFLAGS += -DPROJECT_CONF_H=\"project-conf.h\"

In order to update and revise the firing times of the motes, we have had to modify the Contiki-OS Rtimer library. Provided is a small patch file, `rtimer_patch.diff` which will perform the patch for you. This is covered more in the subsequent *Compiling DT-SCS Light* section.

## Compiling DT-SCS Light
In order to build DT-SCS Light in Contiki-OS 2.7, you will need to first need to ensure you have downloaded the Contiki-OS source, and placed the contiki root folder inside your users Linux home folder.  Here, this is assumed to be `/home/<username>/contiki` . You will need to change *username* to match your environment, and this will need to be reflected in the `Makefile` (detailed below).

The second step is to patch the rtimer file to allow for successive updates in firing time. The file requiring patching is `contiki/core/sys/rtimer.c`. We provide a patch file, `rtimer_patch.diff` which will perform the modifications for you. This must be done before compiling, otherwise the protocol will not work correctly.  Use `make clean` if you have compiled without this patch.

> patch /home/*username*/contiki/core/sys/rtimer.c < rtimer_patch.diff

The third step is to edit the `Makefile` to reflect the location of Contiki-OS, as in the first paragraph.  The default location is in as with here.  Edit `Makefile` and change the following line to match your username and Contiki location.

> CONTIKI=/home/george/contiki

The target device, typically TelosB, also called T-mote Sky, is hard-coded inside the `Makefile`, but may also be specified on the command line.

>TARGET = sky

Several other configuration flags & libraries are included in the `Makefile` which should remain untouched.

Building DT-SCS Light is fairly straightforward, but the compilation process will generate some warnings due to our overriding of the default MAC and RDC layers.  To initiate the build process, run the following command from inside the DT-SCS Light source code root folder.  Notice, there is no '.c' required.

>make DTSCS_light TARGET=sky

A successful compile will result in the creation of `DTSCS_light.sky` binary file in the current folder.

## Flashing Hardware
The code may be flashed onto TelosB (or T-mote Sky) mote using, with the addition of the `.upload` flag on the make command, as follows.

>make DTSCS_light.upload TARGET=sky

The code has only been tested on TelosB motes. If you decide to flash DT-SCS Light onto other hardware platforms, the upload command may be different, and the functionality may vary.

## Cooja Simulation
As an alternative to flashing DT-SCS Light onto hardware, you may prefer to use Contiki-OS's Cooja simulator [[here](http://www.contiki-os.org/start.html#start-cooja)].

> **About Cooja**
Cooja is the Contiki network simulator. Cooja allows large and small networks of Contiki motes to be simulated. Motes can be emulated at the hardware level, which is slower but allows precise inspection of the system behavior, or at a less detailed level, which is faster and allows simulation of larger networks. --- [http://www.contiki-os.org/start.html](http://www.contiki-os.org/start.html#start-cooja)

The Cooja simulator is started as per instructions [here](http://www.contiki-os.org/start.html#start-cooja).  Essentially, this is to `cd` into `/home/<username>/contiki/tools/cooja/` (or wherever you have put Contiki-OS) and run the command `ant run` to load the Cooja simulator.  The Cooja simulator start screen looks like this:

![Cooja Home Screen](http://www.george-smart.co.uk/files/git/dtscs/cooja_home.png)

From here, you can create a new simulation or load one of the existing DT-SCS Light example simulations.

### Creating a New Simulation
To create a new simulation in Cooja, click `File` and then `New Simulation...` from the toolbar. Give the simulation a name, and set any parameters you desire (the defaults are usually fine). It's often worth using a new random seed each reload.

![Cooja New Simulation](http://www.george-smart.co.uk/files/git/dtscs/cooja_new_simulation.png)

You will get an empty simulation window to start experimenting with.

![Cooja Empty Simulation](http://www.george-smart.co.uk/files/git/dtscs/cooja_empty_simulation.png)

From this point, you are able to add motes to the simulation. This is done by selecting `Mote` from the toolbar, then `Add Motes`, then `Create new mote type`, and finally `Sky mote...`.  Give the mote type a suitable description, and browse to the `DTSCS_light.c` source file (not the `.sky` file). This ensures that Cooja recompiles the source automatically on changes. Press `Compile`, and once built, press `Create`.

![Cooja New Mote Type](http://www.george-smart.co.uk/files/git/dtscs/cooja_new_mote_type.png)

You can then add as many instances of the newly created mote as you like.  The `DTSCS_light.c` code is (by default) expecting 16 notes balanced across 4 channels, but this can be changed inside the source.  See the *Code Parameters* section for more about this.

Here, we select 16 nodes, to be linearly distributed in a 2-dimensional grid (between 0 to 3 metres)

![Cooja Mote Positioning](http://www.george-smart.co.uk/files/git/dtscs/cooja_mote_positions.png)

The resulting layout is shown in the Network window of the Cooja Simulator.

![Cooja Simulation Ready](http://www.george-smart.co.uk/files/git/dtscs/cooja_simulation_nodes_positioned.png)

From here, progress on to the *Simulating DT-SCS Light* section.

### Loading an Existing Simulation
If you chose to open an existing simulation, you should select `File`, then `Open and Reconfigure` and finally `Browse...`.  On the Open window, you should select the simulation you wish to open. With Cooja, simulations are given a `csc` file extension.  We provide a copy of the simulation we created above, called `DTSCS_Light_Example.csc`, for your convenience.  You can use the default options, since they are loaded from the saved file, but you will need to update the location the source file, `DTSCS_light.c`, since this will change depending on the location of the files on your computer.

The file will load, and you will see the simulation window with motes already added, as before in the last image of *Creating a New Simulation*.

You should now continue to the *Simulating DT-SCS Light* section.

### Simulating DT-SCS Light

The process of running the simulation is straight forward.  The main Cooja window is enlarged to use maximum screen space. The simulation speed can be controlled from the Simulation Control window, using `Speed limit`  from the toolbar and selecting a suitable speed.  Pressing `Start` will begin the simulation.

You should see the motes start at different times in the Timeline window. This ensures motes don't start in a synchronised state. The Network window shows the direction of packet flow between network nodes. This does not mean that the code acts on the received data, merely that it was received.

In these examples, nodes 1-4 are in channel 11, nodes 5-8 are in channel 12, nodes 9-12 are in channel 13 and nodes 13-16 are in channel 14. In this version of DT-SCS Light, this is hard-coded in the `setChannels (rimeaddr_t)` function inside `DTSCS_light.c` .

![Cooja Motes Booting](http://www.george-smart.co.uk/files/git/dtscs/cooja_motes_booting.png)

After a few more moments, it can be seen from the Timeline window that the motes have all booted, and are now starting to desynchronise within each channel.  We see voting is taking place (as indicated by the blue LED being powered, visible on the Timeline).

![Cooja Motes Booting](http://www.george-smart.co.uk/files/git/dtscs/cooja_motes_electing.png)

Allowing the simulation to run further, we see that the nodes have desynchronised within each channel, as well as having elected 4 synchronisation nodes which have subsequently aligned their firings across channels -- the SYNC nodes are shown with the blue LED illuminated in the Timeline.  The SYNC nodes for each channel have been randomly elected as follows: Ch{11}=4, Ch{12}=8, Ch{13}=12, and Ch{14}=15.

![Cooja Motes Booting](http://www.george-smart.co.uk/files/git/dtscs/cooja_motes_steady_state.png)

Finally, if allowed to continue, the DESYNC nodes will fall into a *Limited-Listening* state, where they turn their radio transceivers off (transceiver power is indicated by the grey bar) when not required, and re-power the transceiver some moments before they are expecting to receive data. 

![Cooja Motes Booting](http://www.george-smart.co.uk/files/git/dtscs/cooja_motes_limited_listening.png)

In the example below, a new network has again been allowed to reach the limited listening steady state. After some moments, we remove a node (here, node 16), and observe that the channel with the missing node (here, channel 14, containing nodes 13, 14, 15 and previously node 16) has returned to the converging state with full listening enabled.

![Cooja Motes Booting](http://www.george-smart.co.uk/files/git/dtscs/cooja_motes_remove_node16.png)

Allowing more time for the network to recover, we see that channel 14 has returned to the limited listening steady state, with the SYNC nodes aligned and the time period equally shared between the 3 participating nodes.  The remaining 2 DESYNC nodes are not aligned with other channels, since the channels are no longer balanced.  The process of re-converging does not effect any of the other channels.

![Cooja Motes Booting](http://www.george-smart.co.uk/files/git/dtscs/cooja_motes_node16_limited_listening.png)

A comprehensive legend for the Timeline is available in the Cooja Help files, and the LED behaviour is defined in the `DTSCS_light.c` source file. More events can be displayed on the Timeline using the `Events` menu.

## Code Parameters
The full list of code parameters is clearly labelled in the top of the source C file, `DTSCS_light.c`.  You are also able to adjust any of the hard-coded channel allocations, and force certain nodes to become SYNC nodes.
Key values & functions are:


`rtPERIOD` - period, T

`Chans` - number of channels in use

`alpha` - DESYNC coupling parameter

`beta` - SYNC coupling parameter

`tConvergedGuard` - the convergence threshold (b_thres)

`NC`, `NE` and `NL` - the number of periods before convergence, elections and full listening, respectively

`setChannels(rimeaddr_t)` -  takes node ID; returns the TX and RX channel numbers - no balancing.


## DT-SCS Light Code Notes
The code timing is quite tight in places. Printing to the serial port for debugging can be done, but it must be done carefully, and in a part of the program where the time requirements are not tight. At present, the balancing and channel swap features of the code are still being explored, and so, are not included in the light version of the protocol.  Channel assignments are hard coded as a result, see `setChannels(rimeaddr_t)` in the source file`DTSCS_light.c`.  The election process is a little buggy, and prefers the highest node ID.  Restarting the network again usually produces a working simulation.

## Authors
George Smart (<g.smart@ee.ucl.ac.uk>) --- PhD Student

Yiannis Andreopoulos (<iandreop@ee.ucl.ac.uk>) --- Supervisor


Telecommunications Research Group Office

Department of Electronic & Electrical Engineering

University College London

Malet Place, London

WC1E 7JE

United Kingdom


January 2016.
