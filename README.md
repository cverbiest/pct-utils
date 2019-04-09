# pct-utils

PCT (https://github.com/Riverside-Software/pct) utilities, intended for mostly .p files to use with PCTRun

## Introduction

Most PCT procedures I create are specific for our environment and therefore not suitable to share. Today I created a procedure to write an st file from an existing database. This is not related to the our application but only requires standard OpenEdge logic.  

## Dial purpose

When possible I try to make my procedures dual purpose so that they can be called with and without PCT.

## Procedures

### templates/procedure.p

A template to create a new PCT run procedure

### database/generate_st.p

Generates a .st file from an database connection