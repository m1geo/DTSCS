// George Smart, Thu 9 Aug 2012.
// http://www.sics.se/contiki/wiki/index.php/Change_MAC_or_Radio_Duty_Cycling_Protocols

// Change the RDC and MAC to null_drivers.
#define NETSTACK_CONF_RDC nullrdc_driver
#define NETSTACK_CONF_MAC nullmac_driver
