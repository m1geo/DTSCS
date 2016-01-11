/*  ____ _____    ____   ____ ____     _     _       _     _   
 * |  _ \_   _|  / ___| / ___/ ___|   | |   (_) __ _| |__ | |_ 
 * | | | || |____\___ \| |   \___ \   | |   | |/ _` | '_ \| __|
 * | |_| || |_____|__) | |___ ___) |  | |___| | (_| | | | | |_ 
 * |____/ |_|    |____/ \____|____/   |_____|_|\__, |_| |_|\__|
 *                                             |___/           
 * DTSCS_light.c
 * 
 * Project:		https://github.com/m1geo/DTSCS
 * 
 * Author:		http://www.george-smart.co.uk/wiki/DTSCS
 * 				http://wwws.ee.ucl.ac.uk/~zceed42/
 * 
 * George Smart <g.smart@ee.ucl.ac.uk> (PhD Student)
 * Yiannis Andreopoulos <iandreop@ee.ucl.ac.uk> (Supervisor)
 * 
 * Monday 08 January 2016. Copyright.
 * 
 * Telecommunications Research Group Office, Room 7.06.
 * Malet Place Engineering Buidling
 * Department of Electronic & Electrical Engineering
 * University College London
 * Malet Place, London, WC1E 7JE, United Kingdom.
 * 
 * Issues:
 * 	- election favours the higher node, instead of random roll
 *  - nodes are hard coded per channel (no balancing in light version)
 *  - code is a little buggy
 * 
 */

 /*
  * LEDS
  * 	RED		Transmitting packet
  * 	GREEN	Received packet
  * 	BLUE	Sync Node (also voting on sync)
  */

/**
 * \file
 *         DT-SCS Light : Desync with Election & Sync.
 * \author
 *         George Smart <g.smart@ee.ucl.ac.uk>
 */

// Includes
#include "contiki.h"
#include "net/rime.h"
#include "random.h"
#include "dev/button-sensor.h"
#include "dev/leds.h"
#include "sys/rtimer.h"
#include "sys/ctimer.h"
#include "dev/cc2420.h"
#include "net/netstack.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h> 

// Allows replacing/editing rtimer
#define rtimer_set_george	rtimer_set
#define TRUE 1
#define FALSE 0

typedef int bool;

// Compile Time Parameters
#define 				 	rtPERIOD_DESYNC 		((RTIMER_SECOND/10)-89) // 100ms (89 is desync code delay trim value, measured 22/07/15 DESYNC)
#define 				  	rtPERIOD_SYNC 			((RTIMER_SECOND/10)-73) // 100ms (73 is sync code delay trim value, measured 22/07/15 SYNC)
#define 					Chans					4 // number of channels in use for (wrapping with C+1)
#define 					RADIOPWR   				CC2420_TXPOWER_MAX	// Radio transmitter power: Between 1 and 31.  Min to Max. CC2420_TXPOWER_MIN / CC2420_TXPOWER_MAX
const double 				alpha = 				0.6; // desync coupling
const double 				beta = 					1.1150; // sync coupling
rtimer_clock_t				tConvergedGuard = 		5; // timing variation convergence threshold (b_thres) (30.5176 microsecond ticks)
rtimer_clock_t				tGuard = 				164; // listening guard time (t_guard) 2.5 milliseconds each side (164 total) (30.5176 microsecond ticks)
unsigned short				NC = 					40; // consecutive periods of convergence before entering limimted listening
unsigned short				NL = 					10; // consecutive periods of lost beacon packets, before returning from limited listening (as unconverged)
unsigned short				NE = 					10; // consecutive periods without SYNC node before calling election.
const clock_time_t 			cListeningTicks = 		8;  // 128 = second. 6 works, 7 better alignment with 4 channels, random
const unsigned int			SyncListenNativeChan = 	(RTIMER_SECOND/35);  // amount of time SYNC listens in own channel for collisins, etc.
const int 					procoffset = 			44;  // limited listening timer set delay tweak parameter (best left alone)
#define 					RANDOMLISTEN 			0 // 0=listen to next channel, 1=listen to random channel
#define						RTIMER_OVERFLOW			65535

// Timers
struct rtimer 				maintimer;
struct rtimer 				syncradioofftimer;
static struct ctimer 		listentimer; // note, this is a ctimer (all others are real-time)

// Time Variables
rtimer_clock_t  			rtPERIOD = rtPERIOD_DESYNC;
rtimer_clock_t  			tFire = 0;
rtimer_clock_t  			tNext = 0;
rtimer_clock_t  			tPrev = 0;
rtimer_clock_t  			tPrevOld = 0;
rtimer_clock_t  			tNextFire = 0;
rtimer_clock_t  			tFireOld = 0;
rtimer_clock_t  			tInterFiringOld = 0;
rtimer_clock_t  			tInterFiring = 0;
rtimer_clock_t  			tDiff = 0;
rtimer_clock_t  			tOffset = 0;
rtimer_clock_t 				tListen = 0;
rtimer_clock_t  			tReceived = 0;

// 
unsigned short 				sJustFired = 0;
unsigned short 				sJustVoted = 0;
unsigned short 				sConverged = 0;
unsigned short 				sLostBeacons = 0;
unsigned short 				sHeardPrev = 0;
unsigned short 				sHeardNext = 0;
unsigned short				sHeardSync = 0;
unsigned int   				PacketsHeardDuringLI = 0;

uint8_t		   				NodeChannelState;
uint8_t		   				ThisNodeType = 0;
rimeaddr_t	   				ChannelSyncNode;
unsigned short 				NEcount = 0;
uint8_t		   				HighestElectionRoll = 0;
char           				arrived[130];
bool 		   				isSelfJustVoted = 0;
bool		   				isVoteReceived = 0;
uint16_t 	   				channelTX = 20;
uint16_t 	   				channelRX = 20;
uint8_t						W = 0;
unsigned long long int		AFN = 0; 
uint8_t 					Roll = 0;
uint8_t  					rtimer_ret = 0;


// Contiki Application Process Definitions
PROCESS(example_desync_process, "DT-SCS Light");
AUTOSTART_PROCESSES(&example_desync_process);

// Function Definitions
static unsigned short NodeType(void);
static unsigned short IAmSync(void);
static void FireCallback (void *ptr);
static void RadioPowered(int a);
static void CheckConvergence(clock_time_t new, clock_time_t old);
static void broadcast_recv(struct broadcast_conn *c, const rimeaddr_t *from);
static unsigned short Converged(void);
static unsigned short IAmSync(void);
static rtimer_clock_t rtimer_difference(rtimer_clock_t tCur, rtimer_clock_t tPre);
static void ReceiverOnNextCallback (void *ptr);
static void ReceiverOffNextCallback (void *ptr);
static void ReceiverOnPrevCallback (void *ptr);
static void ReceiverOffPrevCallback (void *ptr);
static void processElectionVote(rimeaddr_t castID, uint8_t castVOTE);
static void ListenCallback(void *ptr);
static void SyncProcess(rtimer_clock_t rxtime, rtimer_clock_t txtime);

// Receiver callback
static const struct broadcast_callbacks broadcast_call = {broadcast_recv};
static struct broadcast_conn broadcast;

// Node Types
enum node_type_enum {
	SYNCNODE,
	DESYNCNODE
};

// Channel States
enum chan_mode_enum{
	ELECTION,
	CONVERGING,
	CONVERGED
};

// Beacon Packet Structure
struct beacon_packet {
	uint8_t			node_type;
	uint8_t			chan_mode;
	rimeaddr_t		chan_sync;
	uint8_t  		chan_nodes;
	uint8_t  		chan_native;
};

// Returns TRUE if channel converged, FALSE if not
static unsigned short
Converged(void)
{
	return (sConverged > NC);
}

// Returns TRUE if reported SYNC is me and the channel isn't in election mode
static unsigned short 
IAmSync(void)
{
	// NOTE: (rimeaddr_cmp returns non-zero if the addresses are the same, zero if they are different)
	return ( (rimeaddr_cmp(&ChannelSyncNode, &rimeaddr_node_addr) != 0) && (NodeChannelState != ELECTION) );
}

// Returns self's node type
static unsigned short 
NodeType(void)
{
	if (IAmSync() == TRUE) {
		return SYNCNODE;
	} else {
		return DESYNCNODE;
	}
}

// calculate the number of nodes in each channel, based on the time 
// difference between the previous node's firing, and ours.
//   Sometimes outputs erroneous values.
uint8_t
NodesInChannel(rtimer_clock_t curr, rtimer_clock_t prev)
{
	uint8_t Wt = 0;
	rtimer_clock_t diff = rtimer_difference(curr, prev);
		float ans = (((float) rtPERIOD) / ((float) diff));
		Wt = (unsigned int)(ans + 0.5);
	return Wt;
}

// calculate if we have converged based on our previous and current fire
// times. Must handle rtimer overflow every 2 seconds.
static void
CheckConvergence(clock_time_t new, clock_time_t old)
{	
	tInterFiringOld = tInterFiring;
	tInterFiring = rtimer_difference(new, old);
	
	if (tInterFiring > tInterFiringOld) {
		tDiff = (tInterFiring - tInterFiringOld);
	} else {
		tDiff = (tInterFiringOld - tInterFiring);
	}
	
	if (tDiff <= tConvergedGuard) {
		sConverged++;
		if (sConverged > (NC+1)) {
			sConverged = (NC+1);
		}
	}
	
	// not converged if we've lost more than NL beacons
	if (sLostBeacons > NL) {
		sConverged = 0;
	}
}

// calculate our new fire time for DESYNC. Either update based on DESYNC
// or just fire on next T if we've missed a packet.
// Must Handle overflows and missed tPrev/tNext. 
static void
calculateFireTimer(void)
{
	rtimer_clock_t  tempP = 0;
	rtimer_clock_t  tempC = 0;
	rtimer_clock_t  tempN = 0;
	
	// move tPrev to 0
	if (tNext > tPrev) {
		tempC = tFire - tPrev;
		tempN = tNext - tPrev;
		tempP = 0;
	} else { // rtimer overflowed
		tempC = tFire + (RTIMER_OVERFLOW - tPrev) + 0;
		tempN = tNext + (RTIMER_OVERFLOW - tPrev) + 0;
		tempP = 0;
	}
	
	// DESYNC update equation
	tNextFire = rtPERIOD + (1.0-alpha) * tempC + alpha * ( (tempP/2) + (tempN/2) );
	
	// rescale to abosolute tPrev
	tNextFire += tPrev;

	// If we heard both tNext and tPrev
	if (sHeardNext && sHeardPrev) {
		// And the new fire time isn't crazy (more than 2 periods away (this may want optimising)
		if ((tNextFire-tFire) <= (2*rtPERIOD)) {
			if (!Converged()) {
				rtimer_set_george(&maintimer, tNextFire, 1, (rtimer_callback_t) FireCallback, NULL);  // update when not converged
			} else {
				// nothing here
			}
		} else { // tNextFire More than 2 periods away, so fire on T
			tNextFire = tFire + rtPERIOD;
		}
	} else { // missed either tNext or tPrev
		tNextFire = tFire + rtPERIOD;
	}
}

// calculate our new fire time for SYNC. Either update based on SYNC
// or just fire on next T if we've missed a packet.
// Must Handle overflows and missed rxtime/txtime. 
static void
SyncProcess (rtimer_clock_t rxtime, rtimer_clock_t txtime)
{
	rtimer_clock_t lastheard = rxtime;
	rtimer_clock_t lastfired = txtime;
	
	// calculate the phase difference between us and who we heard
	unsigned int phi = lastfired - lastheard; // requires correct size varibles to ignore offset.
	
	// calculate new-phase-of-sync from the phi and the beta parameter.
	unsigned long int npos = (((long double) beta) * ((unsigned long int) phi));
	
	// cap 'new-phase-of-sync' at one period.
	if (npos > rtPERIOD) {
		npos = rtPERIOD;
	}
	
	// calculate new fire time.
	tNextFire = lastfired + npos - phi + rtPERIOD + procoffset;
}

// The receiver interupt callback
// run every time a packet is received on channel
static void
broadcast_recv(struct broadcast_conn *c, const rimeaddr_t *from)
{
	// save reception time
	rtimer_clock_t rRXtime = RTIMER_NOW();
	
	// green debug led on
	leds_on(LEDS_GREEN);

	// random seed
	random_init(rRXtime);

	// copy received beacon from packetbuf_dataptr() into structure r (type beacon_packet)
	struct beacon_packet r;
	memcpy(&r, packetbuf_dataptr(), sizeof(r));

	// if we hear another unconverged mote, then we unconverge too
	rimeaddr_t ReportedSyncNode = r.chan_sync;
	uint8_t    ReportedChanMode = r.chan_mode;
	
	// wait for 1 period before claiming this node as SYNC node
	if(IAmSync() && !isSelfJustVoted) { // If I'm the SYNC
		// SYNC node (me) must only react to other SYNC nodes on our channel
		if ((r.node_type == SYNCNODE) && (cc2420_get_channel() == channelRX))  {  // if beacon packet
				PacketsHeardDuringLI++;
				tReceived = rRXtime; // doing this in two steps ensures time is correct but negates time to read the channel from radio
		} else if(r.chan_mode != ELECTION && !rimeaddr_cmp(&ReportedSyncNode, &rimeaddr_node_addr) && r.chan_native == channelTX) { // if more than 1 sync per channel
			if(rimeaddr_node_addr.u8[0] < ReportedSyncNode.u8[0]){
				rimeaddr_copy(&ChannelSyncNode, &ReportedSyncNode);
			}
		}
	} else { // DESYNC Code
		// If channel is converged.
		if (Converged()) {
			// turn the radio off after packet RX
			RadioPowered(0);
		}
		
		// If I was the last to transmit, the next person to TX is my next neigbour
		if (sJustFired > 0) {
			sJustFired = 0;
			sHeardNext = 1;
			tNext = rRXtime;
			calculateFireTimer();
			tPrevOld = tPrev;
			//tPrev = tNext; // just 2 nodes in channel (breaks limited listening, as difference = 0)
		} else { // if I haven't just transmitted, always update the prev on every reception.
			sHeardPrev = 1;
			tPrevOld = tPrev;
			tPrev = rRXtime;
		}
		
		// Does the received packet have a channel SYNC node (non NULL)
		if (rimeaddr_cmp(&ReportedSyncNode, &rimeaddr_null) == 0) {
			sHeardSync = 1; //heard sync
		}
		
		// If we haven't had a Sync for NE, call election.
		if (NEcount >= NE) {
			NodeChannelState = ELECTION;
			sJustVoted = 0;
			NEcount = 0;
		}
		
		// If the received node is in election mode
		if (ReportedChanMode == ELECTION) {	
			processElectionVote(*from, ReportedSyncNode.u8[0]);
			isVoteReceived = TRUE; // anticipate if collision occurs
			// If I haven't voted in the election, make me.
			if (sJustVoted == 0) {
				NodeChannelState = ELECTION;
			}
		}
	}
	leds_off(LEDS_GREEN);
}

// calculate rtimer ticks between two times, irrespective of overflows
static rtimer_clock_t
rtimer_difference(rtimer_clock_t a, rtimer_clock_t b)
{	
	rtimer_clock_t diff = 0;
	if (a < b) { // rtimer overflowed
		diff = RTIMER_OVERFLOW - b + a;
	} else {
		diff = a - b;
	}
	return diff;
}

// wrapper to turn the radio on or off
static void
RadioPowered(int a)
{
	if (a > 0) {
		NETSTACK_MAC.on();	// radio on
	} else {
		NETSTACK_MAC.off(0);	// radio off
	}
}

// turn the radio on for the DESYNC Next Packet
static void
ReceiverOnNextCallback (void *ptr)
{	
	sHeardNext = 0;	// clear heard variable
	RadioPowered(1); // radio on
	rtimer_set_george(&maintimer, RTIMER_NOW() + (2*tGuard), 1, (rtimer_callback_t) ReceiverOffNextCallback, NULL); // wait twice guard time
}

// turn the radio off after the DESYNC Next Packet
static void
ReceiverOffNextCallback (void *ptr)
{	
	RadioPowered(0); // radio off
	if (sHeardNext == 0) { // missed next packet reception (DESYNC Limited Listening)
		tPrevOld += rtPERIOD + 75; // so do it here. (+75 offset for timer delay, empircally found)
		tNext += rtPERIOD + 75; // move on a period (+75 offset for timer delay, empircally found)
		sLostBeacons++;
	}
	
	sJustFired = 0;
	rtimer_clock_t testtime =  rtPERIOD + tPrevOld - tGuard;
	rtimer_set_george(&maintimer, testtime, 1, (rtimer_callback_t) ReceiverOnPrevCallback, NULL); // RX guard ticks before expected.
}

// turn the radio on for the DESYNC Previous Packet
static void
ReceiverOnPrevCallback (void *ptr)
{	
	sHeardPrev = 0; // clear heard variable
	RadioPowered(1); // radio on
	rtimer_set_george(&maintimer, RTIMER_NOW() + (2*tGuard), 1, (rtimer_callback_t) ReceiverOffPrevCallback, NULL); // wait twice guard time
}

// turn the radio off after the DESYNC Previous Packet
static void
ReceiverOffPrevCallback (void *ptr)
{	
	RadioPowered(0); // radio off
	if (sHeardPrev == 0) { // missed previous packet reception (DESYNC Limited Listening)
		tPrev += rtPERIOD + 75; // move on a period (+75 offset for timer delay, empircally found)
		sLostBeacons++;
	}
	
	// iff we missed either of the next or previous, fire on next period
	if ( (sHeardPrev == 0) || (sHeardNext == 0) ) {
		tNextFire = tFire + rtPERIOD;
	}
	
	rtimer_set_george(&maintimer, tNextFire, 1, (rtimer_callback_t) FireCallback, NULL);
}

// Turn the receiver off after the sync listening period
static void
ListenCallback(void *ptr)
{   
	// Note current time
    rtimer_clock_t time_now = RTIMER_NOW();
	
	// Add an extra receiving time for sync to listen in it's own channel
	// for conflicting sync nodes, etc.
	cc2420_set_channel(channelTX); // avoid use a blocking while?
	while(RTIMER_CLOCK_LT(RTIMER_NOW(), time_now + SyncListenNativeChan));
	RadioPowered(0); // radio off
}

// Each time someone votes, we need to check if their vote is bigger than the previous max.
static void
processElectionVote(rimeaddr_t castID, uint8_t castVOTE)
{
	// 	If it is, we make them the SYNC.
	if (castVOTE > HighestElectionRoll) {
		rimeaddr_copy(&ChannelSyncNode, &castID); // (dest, src)
		HighestElectionRoll = castVOTE;
	} else if (castVOTE == HighestElectionRoll) { // If not, are they equal
		// if they're equal, the higher u8[0] ID is chosen.
		if (ChannelSyncNode.u8[0] >= castID.u8[0]) {
			rimeaddr_copy(&ChannelSyncNode, &castID); // (dest, src)
		}
	}
}

// This code does the beacon firing for SYNC and DESYNC
static void
FireCallback (void *ptr)
{
	struct beacon_packet b;
	int PacketBuffCopied = 0;
	
	leds_on(LEDS_RED);

	// save old fire time for examining offsets.
	tFireOld = tFire;

	RadioPowered(1); // turn the transceiver on
	
	// check if we're converged - this updates NodeChannelState
	Converged();

	// create beacon packet, b.
	b.node_type = NodeType(); // function returns DESYNCNODE or SYNCNODE
	b.chan_mode = NodeChannelState;
	b.chan_sync = ChannelSyncNode;
	b.chan_native = channelTX;
	b.chan_nodes = W;
	
	sJustVoted = 0;
	isSelfJustVoted = FALSE; 
	
	// if we're going to vote for an election, run this...			
	if (NodeChannelState == ELECTION) {
		//uint8_t Roll = (random_rand() & 0xFF);
		rimeaddr_t RolledDice = rimeaddr_null;
		RolledDice.u8[0] = Roll;
		RolledDice.u8[1] = Roll;
		
		b.chan_mode = ELECTION;
		b.chan_sync = rimeaddr_node_addr;
		rimeaddr_copy(&ChannelSyncNode, &RolledDice); // (dest, src)
		processElectionVote(rimeaddr_node_addr, RolledDice.u8[0]); // process my own vode
		isSelfJustVoted = TRUE;
		
		NodeChannelState = CONVERGING; // once we have voted, return to converging mode.
		sJustVoted = 1; // we have voted now, so stop doign it again.
	}
	
	// move the beacon over to the transmitter
	PacketBuffCopied = packetbuf_copyfrom(&b, sizeof(struct beacon_packet));
	
	if (PacketBuffCopied != sizeof(struct beacon_packet)) {
		// We've not copied all of the data!
		printf("****Transmit buffer copy failed! Copied %d of %d bytes\n", PacketBuffCopied, sizeof(struct beacon_packet));
	}
	
	cc2420_set_channel(channelTX);
	broadcast_send(&broadcast); // Transmit beacon.
	tFire = RTIMER_NOW();
	AFN++; // update absoloute fire number!
	W = NodesInChannel(tFire, tPrev); // update the nodes in each channel
	
	// guess mext fire time, based on current plus period T.
	tNextFire = tFire + rtPERIOD;
	sJustFired = 1;
	
	// Check if we lost a packet - we must re-calculate p
	if ( (rtimer_difference(RTIMER_NOW(), tNext) > rtPERIOD) || (rtimer_difference(RTIMER_NOW(), tPrev) > rtPERIOD) || (sHeardPrev == 0) || (sHeardNext == 0) ) {
		if (NodeType() == DESYNCNODE) {
			sLostBeacons++;
		}
	} else {
		sLostBeacons = 0;
	}

	CheckConvergence(tFire, tFireOld);
	Converged();
    
    // ensure to wait for 1 period before self-claiming this node as SYNC node
	if(IAmSync() && !isSelfJustVoted && isVoteReceived) {
		// SYNC Code
		rtPERIOD = rtPERIOD_SYNC;
		leds_on(LEDS_BLUE);
		if (PacketsHeardDuringLI == 0) {
			tNextFire = tFire + rtPERIOD;
			//printf("no sync heard tFire=%u\n", tNextFire);
		} else {
			SyncProcess(tReceived, tFire);
		}
		//Randomise sync listening channel (if requested)
		#if RANDOMLISTEN
			channelRX = 11+(random_rand()%Chans);
		#else
			channelRX = channelTX + 1; // restore the RX channel to one up
			if (channelRX > (11 + Chans - 1)) {
				channelRX = 11;
			}
		#endif
		//printf("Listening on channel %u\n", channelRX);
		PacketsHeardDuringLI = 0;
		cc2420_set_channel(channelRX);
		// set timer to turn off receiver after cListeningTicks.
		ctimer_set(&listentimer, cListeningTicks, ListenCallback, NULL);
		
		if ((tNextFire - ((rtimer_clock_t) RTIMER_NOW())) > (1.5*((double)rtPERIOD))) {  // needs 16 bit values to ensure this works correctly
			printf("*** ERROR rtimer_set more than 1.5 period away: %u -> %u\n", tNextFire, RTIMER_NOW());
			//tNextFire -= rtPERIOD;
		}
		rtimer_ret = rtimer_set_george(&maintimer, tNextFire, 1, (rtimer_callback_t) FireCallback, NULL);
	} else {
		// DESYNC Code
		rtPERIOD = rtPERIOD_DESYNC;
		leds_off(LEDS_BLUE);
		channelRX = channelTX; // restore the RX channel
		cc2420_set_channel(channelRX); // make sure we're RX on correct channel for DESYNC (in case we dropped SYNC priv).
		if (Converged()) {
			RadioPowered(0);
			rtimer_clock_t testtime =  rtPERIOD + tNext - tGuard;
			rtimer_set_george(&maintimer, testtime, 1, (rtimer_callback_t) ReceiverOnNextCallback, NULL); // RX guard ticks before expected.
		} else {
			rtimer_set_george(&maintimer, tNextFire, 1, (rtimer_callback_t) FireCallback, NULL);
		}
		
		if (sHeardSync == 0) { // did we hear a sync node this period (or, did any of our neighbours)
			NEcount++;
		} else {
			NEcount = 0;
		}
		sHeardSync = 0; // reset
	}

	leds_off(LEDS_RED);
}

static void
setChannels (rimeaddr_t naddr)
{	
	if ( (1 <= naddr.u8[0]) && (naddr.u8[0] <= 4) ) {
		channelTX = 11;
		channelRX = 11;
		return;
	}
		
	if ( (5 <= naddr.u8[0]) && (naddr.u8[0] <= 8) ) {
		channelTX = 12;
		channelRX = 12;
		return;
	}
	
	if ( (9 <= naddr.u8[0]) && (naddr.u8[0] <= 12) ) {
		channelTX = 13;
		channelRX = 13;
		return;
	}
	
	if ( (13 <= naddr.u8[0]) && (naddr.u8[0] <= 16) ) {
		channelTX = 14;
		channelRX = 14;
		return;
	}
	
	printf("Can't match Node: %d\n", naddr.u8[0]);
}

PROCESS_THREAD(example_desync_process, ev, data)
{
	PROCESS_EXITHANDLER(broadcast_close(&broadcast);)
	PROCESS_BEGIN();
	
  	// start the realtime scheduler
	rtimer_init();

	isSelfJustVoted = FALSE;
	isVoteReceived = FALSE;
	
	Roll = (random_rand() & 0xFF);

	// Set sync node to 0.0 (NULL)
	ChannelSyncNode = rimeaddr_null;
	
	// Set to DESYNC in CONVERGING state to begin
	NodeChannelState = CONVERGING;
	ThisNodeType = DESYNCNODE;
	
	setChannels(rimeaddr_node_addr);  // setup TX and RX channel based on node ID (needs to be dynamic later)
	
	printf("DT-SCS Light - https://github.com/m1geo/DTSCS\n");
	printf("Node (%d.%d) on Channels %u/%u\n",  rimeaddr_node_addr.u8[0], rimeaddr_node_addr.u8[1], channelTX, channelRX);
	printf("Compilation Timestamp %s - %s:  %s\n", __TIME__, __DATE__,  __FILE__);
	printf("Period=%u, RTIMER_SECOND=%u (%u bytes)\n", rtPERIOD, RTIMER_SECOND, sizeof(rtimer_clock_t));

	random_init((rimeaddr_node_addr.u8[0]+rimeaddr_node_addr.u8[1]));

	broadcast_open(&broadcast, 129, &broadcast_call);
	
	cc2420_set_channel(channelRX);

	// start randomly through the period by calling the previous listening interval
	tNextFire = (RTIMER_NOW() + (random_rand() % (rtPERIOD/10)));
	rtimer_set_george(&maintimer, tNextFire, 1, (rtimer_callback_t) FireCallback, NULL);
	
	PROCESS_END();
}











