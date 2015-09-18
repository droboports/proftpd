<?php 
$app = "proftpd";
$appname = "ProFTPD";
$appversion = "1.3.5a-1";
$appsite = "http://www.proftpd.org/";
$apphelp = "http://www.proftpd.org/docs/howto/index.html";

$applogs = array("/tmp/DroboApps/".$app."/log.txt",
                 "/tmp/DroboApps/".$app."/proftpd.log",
                 "/tmp/DroboApps/".$app."/auth.log",
                 "/tmp/DroboApps/".$app."/xferlog",
                 "/tmp/DroboApps/".$app."/tls.log",
                 "/tmp/DroboApps/".$app."/access.log",
                 "/tmp/DroboApps/".$app."/error.log");
$appconf = "/mnt/DroboFS/Shares/DroboApps/".$app."/etc/".$app.".conf";
$appautoconf = $appconf.".auto";
$appshares = "/mnt/DroboFS/Shares/DroboApps/".$app."/etc/shares.conf";

$appprotos = array("http", "tcp");
$appports = array("8021", "21");
$droboip = $_SERVER['SERVER_ADDR'];
$apppage = $appprotos[0]."://".$droboip.":".$appports[0]."/";
if ($publicip != "") {
  $publicurl = "ftp://".$publicip.":".$appports[1]."/";
} else {
  $publicurl = "ftp://public.ip.address.here:".$appports[1]."/";
}
$portscansite = "http://mxtoolbox.com/SuperTool.aspx?action=scan%3a".$publicip."&run=toolpage";
?>
