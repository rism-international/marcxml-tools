# RISM Record filter

RISM record filter is a small command line utility for building a subset of records from the 
complete XML open dataset of sources at http://opac.rism.info. 

Filtering rules are defined by key-value pairs in an YAML-configuration file (default: query.yaml). 

__Example__: Query for all new records from Bach in Berlin, State Library in 2015:

```yaml
# query.yaml
"005": "^2015"
"100$a":
  - "Bach, Johann Sebastian"
"852$a": "^D-B$"

```
gives an output-XML-file with a subset of 476 records (as of October 2015). 


Semantic structure:
* Key is the Marc21 field (e.g. "100$a" or "005")
* Value is a regular expression (e.g. "Mozart.\*"). Hint: regular expression for negative matching (e.g. `^(?!.*term).*$`), see: http://www.regular-expressions.info/lookaround.html. 

Query parameters (one per line) are combined with __"AND"__ logic.

It is possible to look also for dependend records in a collection with the '-c' parameter.

For more options see `record_filter --help`.

## Installation

###Requirements

* Ruby

## Links and tutorials
* RISM Opendata: https://opac.rism.info/index.php?id=8&L=0
* MARC21 Documentation: http://www.loc.gov/marc/bibliographic/  
* Regular Expression: https://en.wikipedia.org/wiki/Regular_expression


