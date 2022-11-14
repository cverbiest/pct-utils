/*------------------------------------------------------------------------
    File        : generate_riverside_vscodeconfig.p
    Purpose     : builds config files for vscode Riverside ABL plugin
    Syntax      : Run within progress session that has correct path & db connections
    Author(s)   : Carl Verbiest
    Created     : Sun Nov 13 08:49:01 CEST 2022
    Notes       :
  ----------------------------------------------------------------------*/

using Progress.Json.ObjectModel.JsonArray from propath.
using Progress.Json.ObjectModel.JsonObject from propath.

block-level on error undo, throw.

define variable ConfigJson as JsonObject no-undo.
define variable PropathArray as JsonArray  no-undo .
define variable DbArray as JsonArray  no-undo .
define variable SettingsJson as JsonObject no-undo.
define variable SearchArray as JsonObject  no-undo .
define variable EntryObject as JsonObject  no-undo .
define variable AliasArray as JsonArray  no-undo .
define variable PathEntry as character no-undo.
define variable DirName as character no-undo.

define variable Count as integer no-undo.
define variable aCount as integer no-undo.

define variable lConfigFile as character no-undo.
define variable TargetDir as character no-undo format "x(65)".
define variable ApplDir as character no-undo format "x(65)".
define variable CablProfileBackup as character no-undo format "x(65)" initial "C:\Users\cvb\Downloads\oe-ccesmarttools-70105.xml".

file-information:file-name = ".".
TargetDir = file-information:full-pathname.

if not session:batch-mode
then update TargetDir CablProfileBackup.

if TargetDir > ""
then /* Ok **/.
else TargetDir = ".".
file-information:file-name = TargetDir.
TargetDir = replace(file-information:full-pathname, "~\", "/").

lConfigfile = substitute ("&1/openedge-project.json", TargetDir).
os-create-dir value(substitute ("&1/.vscode", TargetDir)).

/* openedge-project.json */
ConfigJson = new JsonObject().

file-information:file-name = ".".
ApplDir = replace(file-information:full-pathname, "~\", "/").

ConfigJson:Add("name", "application").
ConfigJson:Add("version", "1.0").
ConfigJson:Add("oeversion", proversion).
ConfigJson:Add("graphicalMode", (session:display-type = "gui")).
ConfigJson:Add("charset", session:cpstream).

/* TODO parse session:startup-parameters to extact extraParameters
 * Caveats :
 * - db connection parameters are there
 * - pf files are expanded and may be nested, only the top pf references should be used
 *
 */

if opsys ne "unix"
then ConfigJson:Add("extraParameters", "-basekey ini").

ConfigJson:Add("workingDirectory", ApplDir).
ConfigJson:Add("numThreads", 1).

PropathArray = new JsonArray () .
ConfigJson:Add ("buildPath":U, PropathArray) .
PathLoop: do Count = 1 to num-entries(propath):
    EntryObject = new JsonObject () .

    PathEntry = replace(entry(Count, propath), "~\", "/"). /* use unix-style path */
    DirName = entry(num-entries(PathEntry, "/"), PathEntry, "/").
    if DirName matches "*.pl"
    then do:
        /* Do not add standard OE pl's to propath, except for OpenEdge.net.pl */
        // { "type": "propath", "path": "${DLC}/tty/netlib/OpenEdge.net.pl", "documentation": "openedge.json" }
        if DirName = "OpenEdge.net.pl"
        then do:
            EntryObject:Add ("type", "propath") .
            EntryObject:Add ("path", "$~{DLC~}/tty/netlib/OpenEdge.net.pl") .
            EntryObject:Add ("documentation":U, "openedge.json") .
        end.
        else next PathLoop.
    end.
    else do:
        if PathEntry begins TargetDir
        then substring(PathEntry, 1, length(TargetDir)) = ".".

        if PathEntry matches "*src"
        then EntryObject:Add ("type":U, "source") .
        else EntryObject:Add ("type":U, "propath") .
        EntryObject:Add ("path":U, PathEntry) .
    end.
    PropathArray:Add(EntryObject).
end.


DbArray = new JsonArray () .
ConfigJson:Add("dbConnections", DbArray).

DbLoop: do Count = 1 to num-dbs:
    EntryObject = new JsonObject () .
    EntryObject:Add ("name":U, ldbname(Count)) .
    EntryObject:Add ("connect":U, replace(dbparam(Count), ",", " ")) .
    EntryObject:Add ("dumpFile", substitute ("dump/&1.df", ldbname(Count))).
    AliasArray = new JsonArray().
    EntryObject:Add ("aliases", AliasArray).
    do aCount = 1 to num-aliases:
        if ldbname(alias(aCount)) = ldbname(Count)
        then AliasArray:Add(alias(aCount)).
    end.
    DbArray:Add(EntryObject).
end.

ConfigJson:WriteFile(lConfigFile, true).


/* settings.json
{
    "search.exclude": {
        "** /.pct": true,
        "** / *.r": true,
        "** /preprocessed": true
    },
    "terminal.integrated.env.linux": {
        "APPL":"/usr2/cce/build/test22"
        }

    }
*/

SettingsJson = new JsonObject().

SearchArray = new JsonObject () .
SettingsJson:Add ("files.exclude":U, SearchArray) .
SearchArray:Add("**/*.r", true).

SearchArray = new JsonObject () .
SettingsJson:Add ("search.exclude":U, SearchArray) .
SearchArray:Add("**/.pct", true).
SearchArray:Add("**/*.r", true).
SearchArray:Add("**/preprocessed", true).

if opsys = "unix"
then do:
    EntryObject = new JsonObject () .
    SettingsJson:Add ("terminal.integrated.env.linux":U, EntryObject) .
    EntryObject:Add("APPL", ApplDir).
end.

SettingsJson:WriteFile(substitute ("&1/.vscode/settings.json", TargetDir), true).


{&_proparse_ prolint-nowarn(messagekeywordmatch)}
message
    lConfigFile skip
    substitute ("&1/.vscode/settings.json", TargetDir) skip
    .


/**
 * Purpose: Run the export-cabl.p procedure if found in same directory as this-procedure.
 * Notes: All credit for that procedure to Mike Fechner
 */
procedure ConvertSonarProfile:

    define variable lExportProcedure as character no-undo.

    if CablProfileBackup > ""
    then do:
        lExportProcedure = replace(this-procedure:file-name, "~\", "/").
        entry(num-entries(lExportProcedure, "/"), lExportProcedure, "/") = "export-cabl.p".
        file-information:file-name = lExportProcedure.
        if file-information:full-pathname > ""
        then run value(lExportProcedure) (CablProfileBackup, substitute ("&1/.vscode/cabl.json", TargetDir)).
        else message lExportProcedure "not found" view-as alert-box.
    end.

end procedure.
