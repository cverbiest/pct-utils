/*------------------------------------------------------------------------
    File        : generate_st.p
    Purpose     : Generate st file for connected database

    PCT Syntax:
        <PCTRun procedure="generate_st.p" dlcHome="${progress.DLC}" graphicalMode="false" cpstream="utf-8">
            <PCTConnection refid="${dbName}" />
            <Parameter name="Filename" value="${dumptemp}/dump/${dbName}/${dbName}.st" />
        </PCTRun>

    Non PCT syntax:
        _progres -b -db database -p generate_st.p


    Notes       : All parameters are optional
        * FileName : The name for the st file, default ldbame + ".st"
        * AiExtentDirectory : The directory for AI extent files, default "."
        * BiExtentDirectory : The directory for BI extent files, default "."
        * DataExtentDirectory : The directory for data extent files, default "."

        Adds only 1 file per area, current size and number of files ignored on purpose.
        If you want to extend this to include current sizes add a parameter that defaults to the current behaviour.

    Author(s)   : Carl Verbiest
    Created     : Tue Sep 26 17:20:22 CEST 2017
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

block-level on error undo, throw.

/* PCT support variables */
define variable CalledFromPct as logical no-undo.
define variable lReturnString as character no-undo initial "20".
define variable hPCTRun as handle no-undo.
define new global shared variable pctVerbose as logical no-undo initial no. /* new global allows for usage without PCT */

/* Parameter variables */
define variable lFileName as character no-undo.
define variable lAiExtentDirectory as character no-undo.
define variable lBiExtentDirectory as character no-undo.
define variable lDataExtentDirectory as character no-undo.

/* local variables */
define stream StStream.
/* Set by the PCT environment based on the verbose attribute */

{&_proparse_ prolint-nowarn(source-procedurekeywordmatch)} /* added by cvb */
hPCTRun = source-procedure.

run init.
run Main.
lReturnString = "0".

catch e as progress.lang.error:
   lReturnString = string(e:GetMessageNum(1)).
   put unformatted e:getMessage(1) skip.
end catch.

finally:
    /*  Make sure lReturnString is always returned */
    {&_proparse_ prolint-nowarn(returnfinally)}
    return lReturnString. /* Any non-zero value is an error */
end finally.


/**
 * Purpose:
 * Notes:
 */
procedure Main:
    if num-dbs ne 1
    then undo, throw new Progress.Lang.AppError("Only one database can be connected", 14).

    output stream StStream to value(lFileName).
    for each _Area
        where _Area._Area-number > 1 /* skip Control Area */
        no-lock:
        case  _Area._Area-type:
            when 3
            then run StStreamWriteLine(substitute ('b &1', lBiExtentDirectory)).
            when 7
            then run StStreamWriteLine(substitute ('a &1', lAiExtentDirectory)).
            when 6
            then run StStreamWriteLine(substitute ('d "&1":&2,&3,&4 &5',
                _Area._Area-name, _Area._Area-number, integer(exp(2, _Area._Area-recbits)), _Area._Area-clustersize, lDataExtentDirectory)).
            otherwise put unformatted
                substitute ('Unknown _Area-type &1 on "&2":&3 ignored', _Area._Area-type, _Area._Area-name, _Area._Area-number)
                skip.
        end case.
    end.
    output stream StStream close.

end procedure.


/**
 * Purpose: Write line to st file and echo to stdout if verbose
 * Notes:
 */
procedure StStreamWriteLine:

    define input parameter iLine as character no-undo.

    if pctVerbose then put unformatted iLine skip.
    put stream StStream unformatted iLine skip.

end procedure.


/**
 * Purpose: Get Parameters when called from command line
 * Notes:
 */
procedure GetCommandLineParameters:

    lFileName = substitute ("&1.st", ldbname(1)).
    lAiExtentDirectory = ".".
    lBiExtentDirectory = ".".
    lDataExtentDirectory = ".".

end procedure.


/**
 * Purpose: Get Parameters when called from PCT
 * Notes:
 */
procedure GetPctParameters:

    lFileName = dynamic-function('getParameter' in hPCTRun, 'FileName').
    if lFileName > ""
    then /* Ok, NOOP */ .
    else lFileName = substitute ("&1.st", ldbname(1)).

    lAiExtentDirectory = dynamic-function('getParameter' in hPCTRun, 'AiExtentDirectory').
    if lAiExtentDirectory > ""
    then /* Ok, NOOP */ .
    else lAiExtentDirectory = ".".

    lBiExtentDirectory = dynamic-function('getParameter' in hPCTRun, 'BiExtentDirectory').
    if lBiExtentDirectory > ""
    then /* Ok, NOOP */ .
    else lBiExtentDirectory = ".".

    lDataExtentDirectory = dynamic-function('getParameter' in hPCTRun, 'DataExtentDirectory').
    if lDataExtentDirectory > ""
    then /* Ok, NOOP */ .
    else lDataExtentDirectory = ".".

end procedure.


/**
 * Purpose: Initialization
 * Notes:   Determines CalledFromPct and runs GetPctParameters or GetCommandLineParameters.
 */
procedure Init private:

    CalledFromPct = valid-handle(hPCTRun) and lookup('getParameter', hPCTRun:internal-entries) > 0.
    if CalledFromPct
    then run GetPctParameters.
    else run GetCommandLineParameters.

end procedure.
