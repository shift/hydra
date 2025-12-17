Improve Frontend Rendering of Large Datasets
Problem Analysis: For builds with thousands of steps, the initial HTML payload can be enormous, leading to slow rendering and an unresponsive UI.

Proposed Solution: Lazy-load the "Build Steps" and "RunCommand Logs" tabs. The content will only be fetched and rendered when the user clicks on these tabs.

Estimated Performance Gain: 50-90% reduction in initial page load time for builds with a large number of build steps.

Patches for Lazy-Loading Tabs
First, add the new controller actions to src/lib/Hydra/Controller/Build.pm.

--- a/src/lib/Hydra/Controller/Build.pm
+++ b/src/lib/Hydra/Controller/Build.pm
@@ -531,6 +531,21 @@
     $c->stash->{template} = 'build-deps.tt';
 }

+sub build_steps : Chained('buildChain') PathPart('build-steps') {
+    my ($self, $c) = @_;
+    $c->stash->{steps} = [$c->stash->{build}->buildsteps->search({}, {order_by => "stepnr desc"})];
+    $c->stash->{template} = 'build-steps.tt';
+    $c->stash->{seen} = {};
+}
+
+sub runcommand_logs : Chained('buildChain') PathPart('runcommand-logs') {
+    my ($self, $c) = @_;
+    $c->stash->{runcommandlogs} = [$c->stash->{build}->runcommandlogs->search({}, {order_by => ["id DESC"]})];
+    $c->stash->{runcommandlogProblem} = undef;
+    # We don't need to re-check if dynamic run command is enabled, because the tab wouldn't be visible in the first place.
+    $c->stash->{template} = 'runcommand-logs.tt';
+}
+

 sub runtime_deps : Chained('buildChain') PathPart('runtime-deps') {
     my ($self, $c) = @_;


Next, create the new template files src/root/build-steps.tt and src/root/runcommand-logs.tt.

[% PROCESS "common.tt" %]
[% PROCESS "build.tt" %]
[% INCLUDE renderBuildSteps type="All" %]

[% PROCESS "common.tt" %]
[% PROCESS "build.tt" %]
<div id="tabs-runcommandlogs" class="tab-pane active">
  [% IF runcommandlogProblem %]
    <div class="alert alert-warning" role="alert">
      [% IF runcommandlogProblem == "disabled-server" %]
        This server does not enable Dynamic RunCommand support.
      [% ELSIF runcommandlogProblem == "disabled-project" %]
        This project does not enable Dynamic RunCommand support.
      [% ELSIF runcommandlogProblem == "disabled-jobset" %]
        This jobset does not enable Dynamic RunCommand support.
      [% ELSE %]
        Dynamic RunCommand is not enabled: [% HTML.escape(runcommandlogProblem) %].
      [% END %]
    </div>
  [% END %]
  <div class="d-flex flex-column">
  [% FOREACH runcommandlog IN runcommandlogs %]
    <div class="p-2 border-bottom">
      <div class="d-flex flex-row">
        <div class="d-flex flex-column" style="padding: 10px; width: 50px;">
          [% IF runcommandlog.did_succeed() %]
            <img src="[% c.uri_for("/static/images/emojione-check-2714.svg") %]" height="30" width="30" title="Succeeded" alt="Succeeded" class="build-status" />
          [% ELSIF runcommandlog.is_running() %]

          [% ELSE %]
            <img src="[% c.uri_for("/static/images/emojione-red-x-274c.svg") %]" height="30" width="30" title="Failed" alt="Failed" class="build-status" />
          [% END %]
        </div>

        <div class="d-flex flex-column mr-auto align-self-center">
          <div><tt>[% runcommandlog.command | html %]</tt></div>
          <div>
            [% IF not runcommandlog.is_running() %]
              [% IF runcommandlog.did_fail_with_signal() %]
                Exit signal: [% runcommandlog.signal | html %]
                [% IF runcommandlog.core_dumped %]
                  (Core Dumped)
                [% END %]
              [% ELSIF runcommandlog.did_fail_with_exec_error() %]
                Exec error: [% runcommandlog.error_number | html %]
              [% ELSIF not runcommandlog.did_succeed() %]
                Exit code: [% runcommandlog.exit_code | html %]
              [% END %]
            [% END %]
          </div>
        </div>

        <div class="d-flex flex-column  align-items-end">
          [% IF runcommandlog.start_time != undef %]
            <div>Started at [% INCLUDE renderDateTime timestamp = runcommandlog.start_time; %]</div>
            <div class="d-flex flex-column align-items-end">
              [% IF runcommandlog.end_time != undef %]
                Ran for [% INCLUDE renderDuration duration = runcommandlog.end_time - runcommandlog.start_time %]
              [% ELSE %]
                Running for [% INCLUDE renderDuration duration = curTime - runcommandlog.start_time %]
              [% END %]
              [% IF runcommandlog.uuid != undef %]
                [% runLog = c.uri_for('/build', build.id, 'runcommandlog', runcommandlog.uuid) %]
                <div>
                  <a class="btn btn-secondary btn-sm" [% HTML.attributes(href => runLog) %]>pretty</a>
                  <a class="btn btn-secondary btn-sm" [% HTML.attributes(href => runLog _ '/raw') %]>raw</a>
                  <a class="btn btn-secondary btn-sm" [% HTML.attributes(href => runLog _ '/tail') %]>tail</a>
                </div>
              [% END %]
            </div>
          [% ELSE %]
            <div>Pending</div>
          [% END %]
        </div>
      </div>
    </div>
  [% END %]
  </div>
</div>

Finally, update src/root/build.tt to lazy-load the tabs.

--- a/src/root/build.tt
+++ b/src/root/build.tt
@@ -107,20 +107,17 @@
   <li class="nav-item"><a class="nav-link" href="#tabs-constituents" data-toggle="tab">Constituents</a></li>[% END %]
   <li class="nav-item"><a class="nav-link" href="#tabs-details" data-toggle="tab">Details</a></li>
   <li class="nav-item"><a class="nav-link" href="#tabs-buildinputs" data-toggle="tab">Inputs</a></li>
-  [% IF steps.size() > 0 %]<li class="nav-item"><a class="nav-link" href="#tabs-buildsteps" data-toggle="tab">Build Steps</a></li>[% END %]
+  [% IF steps.size() > 0 %]<li class="nav-item"><a class="nav-link" href="#tabs-buildsteps" data-toggle="tab" data-lazy-load="[% c.uri_for('/build', build.id, 'build-steps') %]">Build Steps</a></li>[% END %]
   [% IF build.dependents %]<li class="nav-item"><a class="nav-link" href="#tabs-usedby" data-toggle="tab">Used By</a></li>[% END %]
   [% IF drvAvailable %]<li class="nav-item"><a class="nav-link" href="#tabs-build-deps" data-toggle="tab">Build Dependencies</a></li>[% END %]
-
   [% IF localStore && available %]<li class="nav-item"><a class="nav-link" href="#tabs-runtime-deps" data-toggle="tab">Runtime Dependencies</a></li>[% END %]
   [% IF runcommandlogProblem ||
-  runcommandlogs.size() > 0 %]<li class="nav-item"><a class="nav-link" href="#tabs-runcommandlogs" data-toggle="tab">RunCommand Logs[% IF runcommandlogProblem %] <span class="badge badge-warning">Disabled</span>[% END %]</a></li>[% END %]
+  runcommandlogs.size() > 0 %]<li class="nav-item"><a class="nav-link" href="#tabs-runcommandlogs" data-toggle="tab" data-lazy-load="[% c.uri_for('/build', build.id, 'runcommand-logs') %]">RunCommand Logs[% IF runcommandlogProblem %] <span class="badge badge-warning">Disabled</span>[% END %]</a></li>[% END %]
 </ul>

 <div id="generic-tabs" class="tab-content">

   <div id="tabs-summary" class="tab-pane active">
-
     <table>
       <tr>
         <td>
@@ -370,55 +367,7 @@
   [% END %]

   [% IF steps %]
-    <div id="tabs-buildsteps" class="tab-pane">
-      [% INCLUDE renderBuildSteps type="All" %]
-    </div>
+    [% INCLUDE makeLazyTab tabName="tabs-buildsteps" uri=c.uri_for('/build', build.id, 'build-steps') %]
   [% END %]

   [% IF build.dependents %]
@@ -432,54 +381,7 @@
   [% END %]

   [% IF available %]
-    [% INCLUDE makeLazyTab tabName="tabs-runtime-deps" uri=c.uri_for('/build'
-    build.id 'runtime-deps') callback="makeTreeCollapsible" %]
+    [% INCLUDE makeLazyTab tabName="tabs-runtime-deps" uri=c.uri_for('/build', build.id, 'runtime-deps') callback="makeTreeCollapsible" %]
   [% END %]

-  <div id="tabs-runcommandlogs" class="tab-pane">
-    [% IF runcommandlogProblem %]
-      <div class="alert alert-warning" role="alert">
-        [% IF runcommandlogProblem == "disabled-server" %]
-          This server does not enable Dynamic RunCommand support.
-        [% ELSIF runcommandlogProblem == "disabled-project" %]
-          This project does not enable Dynamic RunCommand support.
-        [% ELSIF runcommandlogProblem == "disabled-jobset" %]
-          This jobset does not enable Dynamic RunCommand support.
-        [% ELSE %]
-          Dynamic RunCommand is not enabled: [% HTML.escape(runcommandlogProblem) %].
-        [% END %]
-      </div>
-    [% END %]
-    <div class="d-flex flex-column">
-    [% FOREACH runcommandlog IN runcommandlogs %]
-      <div class="p-2 border-bottom">
-        <div class="d-flex flex-row">
-          <div class="d-flex flex-column" style="padding: 10px; width: 50px;">
-            [% IF runcommandlog.did_succeed() %]
-              <img src="[% c.uri_for("/static/images/emojione-check-2714.svg") %]" height="30" width="30" title="Succeeded" alt="Succeeded"
-               class="build-status" />
-            [% ELSIF runcommandlog.is_running() %]
-
-            [% ELSE %]
-              <img src="[% c.uri_for("/static/images/emojione-red-x-274c.svg") %]" height="30" width="30" title="Failed" alt="Failed" class="build-status" />
-            [% END %]
-          </div>
-
-          <div class="d-flex flex-column mr-auto align-self-center">
-
-           <div><tt>[% runcommandlog.command | html %]</tt></div>
-            <div>
-              [% IF not runcommandlog.is_running() %]
-                [% IF runcommandlog.did_fail_with_signal() %]
-                  Exit signal: [% runcommandlog.signal |
-                   html %]
-                  [% IF runcommandlog.core_dumped %]
-                    (Core Dumped)
-                  [% END %]
-                [% ELSIF runcommandlog.did_fail_with_exec_error() %]
-
-                   Exec error: [% runcommandlog.error_number | html %]
-                [% ELSIF not runcommandlog.did_succeed() %]
-                  Exit code: [% runcommandlog.exit_code |
-                   html %]
-                [% END %]
-              [% END %]
-            </div>
-          </div>
-
-          <div class="d-flex flex-column  align-items-end">
-            [% IF runcommandlog.start_time != undef %]
-
-             <div>Started at [% INCLUDE renderDateTime timestamp = runcommandlog.start_time;
-             %]</div>
-              <div class="d-flex flex-column align-items-end">
-                [% IF runcommandlog.end_time != undef %]
-                  Ran for [% INCLUDE renderDuration duration = runcommandlog.end_time - runcommandlog.start_time %]
-                [% ELSE %]
-
-                 Running for [% INCLUDE renderDuration duration = curTime - runcommandlog.start_time %]
-                [% END %]
-                [% IF runcommandlog.uuid != undef %]
-                  [% runLog = c.uri_for('/build', build.id, 'runcommandlog', runcommandlog.uuid) %]
-                  <div>
-
-                     <a class="btn btn-secondary btn-sm" [% HTML.attributes(href => runLog) %]>pretty</a>
-                    <a class="btn btn-secondary btn-sm" [% HTML.attributes(href => runLog) %]/raw">raw</a>
-                    <a class="btn btn-secondary btn-sm" [% HTML.attributes(href => runLog) %]/tail">tail</a>
-                  </div>
-
-                   [% END %]
-              </div>
-            [% ELSE %]
-              <div>Pending</div>
-            [% END %]
-          </div>
-        </div>
-      </div>
-    [% END
-     %]
-    </div>
-  </div>
+  [% INCLUDE makeLazyTab tabName="tabs-runcommandlogs" uri=c.uri_for('/build', build.id, 'runcommand-logs') %]
 </div>

 <div id="reproduce" class="modal hide fade" tabindex="-1" role="dialog" aria-hidden="true">

