# RISM Record filter

Helpful links and tutorials
* RISM Opendata: https://opac.rism.info/index.php?id=8&L=0
* Regular Expression:  https://en.wikipedia.org/wiki/Regular_expression

## Description

RISM record filter is a small ruby utility program for filtering records from the 
complete XML open dataset of sources at http://opac.rism.info. 

Filtering rules are defined by key-value pairs in a YAML-configuration file (default: query.yaml): 

* Key is the Marc21 field (e.g. "100$a" or "005")
* Value is a regular expression (e.g. "Mozart.*")

Query parameters (one per line) are combined with "AND" logic.

## Installation

Requirements

* Ruby

