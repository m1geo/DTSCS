// George Smart, Jan 2016
// https://github.com/contiki-os/contiki/wiki/Change-mac-or-radio-duty-cycling-protocols
// http://www.sics.se/contiki/wiki/index.php/Change_MAC_or_Radio_Duty_Cycling_Protocols (old)

// Change the RDC and MAC to null_drivers.
#define NETSTACK_CONF_RDC nullrdc_driver
#define NETSTACK_CONF_MAC nullmac_driver
