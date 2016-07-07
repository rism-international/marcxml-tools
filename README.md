# RISM MARCXML-Tools

RISM Marcxml is a command line utility for managing MARCXML-files.

This prgram has the following options:

 * --analyze: gives report about tags and occurrances of a MARCXML-file
 * --filter: building a subset of records (e.g. from the complete XML open dataset of sources at http://opac.rism.info). 
 * --help: see help text
 * --merge: merging multiple MARCXML-files into one file
 * --report: creates a report
 * --split: splitting large files into chunks
 * --transform: transforms MARCXML-files
 * --validate: validates a MARCXML-file

## marcxml --analyze
Creates a report of all fields in the input-file.  
Optional: --with-content: add sample content at end of line  
Example call: `marcxml -i input.xml -c config.yaml -o output.txt --with-content`  
 
Example output: 


## marcxml --filter
Creating a subset of records from the complete XML open dataset of sources at http://opac.rism.info. 
Required: -c [Yaml-config-file]  
Optional: --with-linked: select also linked parent/child entries  
Optional: --with-disjunct: select with logical disjunction  
Example call: `marcxml --filter -i input.xml -c config.yaml --with-disjunct`  

Filtering rules are defined by key-value pairs in an YAML-configuration file (default: conf/query.yaml). 
It is possible to look also for dependend records in a collection with the '--with-linked' flag. 
Query parameters (one per line) are combined with __"AND"__ logic by default. Take '--with-disjunct' to use the disjunction logic instead. 

__Example__: Yaml-config for all new records from Bach in Berlin, State Library in 2015: 
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

## marcxml --merge
Merging an array of marcxml-files to one output-file.  
Required: -i [list of input files]. 
Example call: `marcxml --merge -i input1.xml input2.xml -o result.xml`

## marcxml --report
Creates report of the inputfile to stdout. Output can be xls- or csv-format too.  
Optional: --with-tag: define the marcfield for aggregation.  
Example call: `marcxml -i input-xml --xls --with-tag='100$a'`

## marcxml --split
Splitting input-file in chunks. Size is declared with the '--with-limit'-flag. Out are files in sequence 000000+.xml  
Optional: --with-limit: Specify record size for splitting  
Example call : `marcxml --split -i input.xml --with-limit=10000`  

## marcxml --transform
Replaces Marc21 datafield tags and subfield codes according to rules defined by an YAML-file.  
Required: -c [Yaml-config-file]  
Example: `marcxml --transform -i input.xml -c config.yaml -o output.xml`  
 
Structure of the Yaml-conf is:

```yaml
#Optional
Class: MuscatSource
Mapping:
  # Moving 772 to 762 
  - "772": "762"
  # Dropping 772$a
  - "772$a": ~
  # Moving subfield $a to subfield $d
  - "690$a": "d"
  # Moving subfield $d to datafield 852
  - "591$d": "852"
```
You can build much more transform logic with your own classes defined in the lib-folder. Then you have to declare the class-name in the Yaml-conf.

## marcxml --validate
Validating input-file according to the official standard.  
Example call: `marcxml --validate -i input.xml`

# Installation
Clone this repository with `git clone https://github.com/rism-t3/marcxml-tools.git` and execute 'bundle install'. 
Define enviroment variables if you like to use the --muscat-flag (using Oracle-DB).

###Requirements
* Probably Linux / Ubuntu 
* Ruby

## Links and tutorials
* RISM Opendata: https://opac.rism.info/index.php?id=8&L=0
* MARC21 Documentation: http://www.loc.gov/marc/bibliographic/  
* Regular Expression: https://en.wikipedia.org/wiki/Regular_expression

