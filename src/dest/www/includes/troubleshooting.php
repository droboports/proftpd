<p><strong>Connection timeout when opening a directory, uploading/downloading a file, or any of the following errors:<br/>
425 Can&apos;t build data connection: Connection timed out<br/>
425 Can&apos;t open data connection<br/>
426 Connection closed; transfer aborted<br/>
503 No port command Issued first</strong></p>
<p>The FTP client is trying to establish an active connection while only passive connections are supported. Please check the FTP client documentation to swtich to passive mode.</p>
<p>In some cases additional changes to <?php echo $appname; ?>&apos; configuration may be necessary. See the <a href="http://www.proftpd.org/docs/howto/NAT.html" target="_new"><?php echo $appname; ?> documentation</a> for more information.</p>