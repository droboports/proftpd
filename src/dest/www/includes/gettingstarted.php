<p><?php echo $appname; ?> is a self-configuring app. It retrieves a list of all the shares in the Drobo, and allows anonymous access to them automatically unless manual configuration is requested.</p>
<p>Anonymous access to autoconfigured shares is read/write or read-only based on the level of access given to &quot;Everyone&quot; in Drobo Dashboard.</p>
<p>Each autoconfigured share has its own URL. The URL for the Public share is <a href="ftp://Public@<?php echo $droboip; ?>:<?php echo $appports[1]; ?>/" target="_new">ftp://Public@<?php echo $droboip; ?>:<?php echo $appports[1]; ?>/</a>. Other shares will follow the pattern ftp://ShareNameHere@<?php echo $droboip; ?>:<?php echo $appports[1]; ?>/</p>
<?php if (file_exists($appautoconf)) { ?>
  <p><?php echo $appname; ?> is currently automatically configured. This is the content of <code><?php echo $appconf; ?></code>:</p>
  <pre class="pre-scrollable">
<?php echo htmlentities(file_get_contents($appconf), ENT_QUOTES|ENT_SUBSTITUTE); ?>
  </pre>
  <p>This is the content of <code><?php echo $appshares; ?></code>:</p>
  <pre class="pre-scrollable">
<?php echo htmlentities(file_get_contents($appshares), ENT_QUOTES|ENT_SUBSTITUTE); ?>
  </pre>

<?php $lines = file($appshares, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
  foreach ($lines as $line_num => $line) {
    $tokens = explode(" ", $line);
    if ($tokens[1]) { ?>
  <p>This is the content of <code><?php echo $tokens[1]; ?></code>:</p>
  <pre class="pre-scrollable">
<?php echo htmlentities(file_get_contents($tokens[1]), ENT_QUOTES|ENT_SUBSTITUTE); ?>
  </pre>
<?php } } ?>

  <p>To disable the automatic configuration, please remove the file <code><?php echo $appautoconf; ?></code>.</p>
  <p>The &quot;Rescan&quot; button will force an update of the share list.</p>
  <a role="button" class="btn btn-default" href="?op=reload" onclick="$('#pleaseWaitDialog').modal(); return true"><span class="glyphicon glyphicon-refresh"></span> Rescan</a>
<?php } elseif (file_exists($appconf)) { ?>
  <p><?php echo $appname; ?> is currently manually configured. This is the content of <code><?php echo $appconf; ?></code>:</p>
  <pre class="pre-scrollable">
<?php echo htmlentities(file_get_contents($appconf), ENT_QUOTES|ENT_SUBSTITUTE); ?>
  </pre>
  <p>To enable automatic configuration, please create an empty file named <code><?php echo $appautoconf; ?></code>.</p>
<?php } else { ?>
  <p><?php echo $appname; ?> is currently not configured. Please click the &quot;Rescan&quot; button to generate an automatic configuration.</p>
  <a role="button" class="btn btn-default" href="?op=reload" onclick="$('#pleaseWaitDialog').modal(); return true"><span class="glyphicon glyphicon-refresh"></span> Rescan</a>
<?php } ?>
