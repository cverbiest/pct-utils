/*------------------------------------------------------------------------
    File        : convert.p
    Purpose     :

    Syntax      :

    Description :

    Author(s)   : mikef
    Created     : Tue Apr 12 13:28:02 CEST 2022
    Notes       :
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

BLOCK-LEVEL ON ERROR UNDO, THROW.

USING Progress.Json.ObjectModel.* FROM PROPATH.

DEFINE INPUT  PARAMETER pcSonarBackup AS CHARACTER NO-UNDO.
DEFINE INPUT  PARAMETER pcCablJson    AS CHARACTER NO-UNDO.

DEFINE TEMP-TABLE ttRule NO-UNDO
    XML-NODE-NAME "rule":U
    FIELD RuleClassName  AS CHARACTER FORMAT "x(60)":U XML-NODE-NAME "key":U
    FIELD RuleName       AS CHARACTER FORMAT "x(60)":U

    INDEX RuleClassName IS PRIMARY UNIQUE RuleClassName.

DEFINE TEMP-TABLE ttRuleParameters NO-UNDO
    XML-NODE-NAME "parameters":U
    FIELD RuleClassName  AS CHARACTER

    INDEX RuleClassName IS PRIMARY UNIQUE RuleClassName .

DEFINE TEMP-TABLE ttRuleParameter NO-UNDO
    XML-NODE-NAME "parameter":U
    FIELD RuleClassName     AS CHARACTER FORMAT "x(30)":U
    FIELD ParameterName     AS CHARACTER FORMAT "x(30)":U XML-NODE-NAME "key":U
    FIELD ParameterValue    AS CHARACTER FORMAT "x(60)":U XML-NODE-NAME "value":U

    INDEX RuleClassName IS PRIMARY UNIQUE RuleClassName ParameterName.

DEFINE DATASET dsRuleRuleParameter
    XML-NODE-NAME "rules":U
    FOR ttRule, ttRuleParameters, ttRuleParameter

    DATA-RELATION relParameters FOR ttRule, ttRuleParameters
        NESTED FOREIGN-KEY-HIDDEN
        RELATION-FIELDS (RuleClassName, RuleClassName)

    DATA-RELATION relParameter FOR ttRuleParameters, ttRuleParameter
        NESTED FOREIGN-KEY-HIDDEN
        RELATION-FIELDS (RuleClassName, RuleClassName) .

DEFINE VARIABLE hDocument   AS HANDLE     NO-UNDO.
DEFINE VARIABLE hRoot       AS HANDLE     NO-UNDO.
DEFINE VARIABLE hRules      AS HANDLE     NO-UNDO.

DEFINE VARIABLE i           AS INTEGER    NO-UNDO .

DEFINE VARIABLE oJson       AS JsonObject NO-UNDO .
DEFINE VARIABLE oRules      AS JsonArray  NO-UNDO .
DEFINE VARIABLE oRule       AS JsonObject NO-UNDO .
DEFINE VARIABLE oParameters AS JsonArray  NO-UNDO .
DEFINE VARIABLE oParameter  AS JsonObject NO-UNDO .
DEFINE VARIABLE iValue      AS INTEGER    NO-UNDO .

/* ***************************  Main Block  *************************** */

CREATE X-DOCUMENT hDocument .
CREATE X-NODEREF hRoot .
CREATE X-NODEREF hRules .

hDocument:LOAD("file":U,
               pcSonarBackup,
               FALSE) .

hDocument:GET-DOCUMENT-ELEMENT(hRoot) .

rules-loop:
DO i = 1 TO hRoot:NUM-CHILDREN:
    hRoot:GET-CHILD(hRules, i) .

    IF hRules:NAME = "rules":U THEN
        LEAVE rules-loop.
END.

DATASET dsRuleRuleParameter:READ-XML ("handle":U, hRules,
                                      "empty":U,
                                      ?, ?, ?, ?).

rules-loop:
FOR EACH ttRule BY ttRule.RuleClassName:
    IF NOT ttRule.RuleClassName BEGINS "eu.rssw.":U THEN DO:
        DELETE ttRule.
        NEXT rules-loop .
    END.

    ASSIGN ttRule.RuleName = ENTRY (NUM-ENTRIES (ttRule.RuleClassName, ".":U), ttRule.RuleClassName, ".":U) .
END.

oJson = NEW JsonObject () .
oRules = NEW JsonArray () .

oJson:Add ("activeRules":U, oRules) .

FOR EACH ttRule BY ttRule.RuleName:
    ASSIGN oRule = NEW JsonObject () .

    oRules:Add (oRule) .

    oRule:Add ("name":U, ttRule.RuleName) .
    oRule:Add ("class":U, ttRule.RuleClassName) .

    IF CAN-FIND (FIRST ttRuleParameter WHERE ttRuleParameter.RuleClassName = ttRule.RuleClassName) THEN DO:
        oParameters = NEW JsonArray () .

        oRule:Add ("parameters":U, oParameters) .

        FOR EACH ttRuleParameter WHERE ttRuleParameter.RuleClassName = ttRule.RuleClassName:
            oParameter = NEW JsonObject () .

            oParameters:Add (oParameter) .

            oParameter:Add ("name":U, ttRuleParameter.ParameterName) .

            IF ttRuleParameter.ParameterValue = "true":U THEN
                oParameter:Add ("value":U, TRUE) .
            ELSE IF ttRuleParameter.ParameterValue = "false":U THEN
                oParameter:Add ("value":U, FALSE) .
            ELSE DO:
                {&_proparse_ prolint-nowarn(avoidnoerror)}
                ASSIGN iValue = INTEGER (ttRuleParameter.ParameterValue) NO-ERROR .

                IF ttRuleParameter.ParameterValue = "":U OR ERROR-STATUS:NUM-MESSAGES > 0 THEN
                    oParameter:Add ("value":U, ttRuleParameter.ParameterValue) .
                ELSE
                    oParameter:Add ("value":U, iValue) .
            END.
        END.
    END.
END.

oJson:WriteFile (pcCablJson, TRUE) .

FINALLY:
    IF VALID-HANDLE (hRules) THEN
        DELETE OBJECT hRules.

    IF VALID-HANDLE (hRoot) THEN
        DELETE OBJECT hRoot.

    IF VALID-HANDLE (hDocument) THEN
        DELETE OBJECT hDocument .
END FINALLY.