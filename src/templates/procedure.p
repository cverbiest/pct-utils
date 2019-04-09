/*------------------------------------------------------------------------
    File        : procedure.p
    Purpose     : template for .p that can be called from PCT and commandline

    PCT Syntax:
        <PCTRun procedure="generate_st.p" dlcHome="${progress.DLC}" graphicalMode="false" cpstream="utf-8">
            <PCTConnection refid="${dbName}" />
        </PCTRun>

    Non PCT syntax:
        _progres -b -p generate_st.p

    Notes       : 
    Author(s)   : Carl Verbiest
    Created     : Tue Sep 26 17:20:22 CEST 2017
  ----------------------------------------------------------------------*/

block-level on error undo, throw.

/* PCT support variables */
define variable CalledFromPct as logical no-undo.
define variable lReturnString as character no-undo initial "20".
define variable hPCTRun as handle no-undo.
/* pctVerbose is set by the PCT environment based on the verbose attribute, new global allows for usage without PCT */
define new global shared variable pctVerbose as logical no-undo initial no. 

/* Parameter variables */
define variable lMyParameter as character no-undo.

/* local variables */

{&_proparse_ prolint-nowarn(source-procedurekeywordmatch)}
hPCTRun = source-procedure.

run init.
run Main.
lReturnString = "0".

catch e as Progress.Lang.Error:
   lReturnString = string(e:GetMessageNum(1)).
   put unformatted e:getMessage(1) skip.
end catch.

finally:
    /*  Make sure lReturnString is always returned */
    {&_proparse_ prolint-nowarn(returnfinally)}
    return lReturnString. /* Any non-zero value is an error */
end finally.


/**
 * Purpose: The actual workload
 * Notes:
 */
procedure Main:

end procedure.


/**
 * Purpose: Get Parameters when called from command line
 * Notes:
 */
procedure GetCommandLineParameters:

    lMyParameter = "value when called from commandline e.g. session:parameter".

end procedure.


/**
 * Purpose: Get Parameters when called from PCT
 * Notes:
 */
procedure GetPctParameters:

    lMyParameter = dynamic-function('getParameter' in hPCTRun, 'MyParameter').
    if lMyParameter > ""
    then /* Ok, NOOP */ .
    else lMyParameter = "default when not set in PCTRun".

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
