# RISM MARCXML-Tools

RISM MARCXML-Tools is a set of command line utilities for managing MARCXML-files. 

This set contains

* marcxml-analyze: gives report about tags and occurrances of a MARCXML-file
* marcxml-filter: building a subset of records from the complete XML open dataset of sources at http://opac.rism.info. 
* marcxml-merge: merging multiple MARCXML-files into one file
* marcxml-split: splitting large files into chunks
* marcxml-transform: transforms MARCXML-files
* marcxml-validate: validates a MARCXML-file

## marcxml-filter
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

## marcxml-transform
Replaces Marc21 datafield tags and subfield codes according to rules defined by an YAML-file. Structure of the file is:

```yaml
#transform.yaml
"rename datafields":
 #- "old_tag": "new_tag" eg.
 - "035": "136"
"rename subfields":
 #- "tag$old_code": "new_code" eg.
 - "031$r": "g"
"move subfield":
 - "035$h": "100"
```

## Installation

###Requirements

* Ruby

## Links and tutorials
* RISM Opendata: https://opac.rism.info/index.php?id=8&L=0
* MARC21 Documentation: http://www.loc.gov/marc/bibliographic/  
* Regular Expression: https://en.wikipedia.org/wiki/Regular_expression


##How to use Record Filter

First of all Ruby has to be installed. Then download the program file from github:

git clone https://github.com/rism-t3/record_filter.git

Inside the download you will find the file query.yaml. This yaml file contains configuration fields you will adjust for you search queries. Next you need the file which you want to browse. Normally this will be the XML file you downloaded from this link:

https://opac.rism.info/index.php?id=8&L=1

You can start with the file rismAllMARCXMLexample.zip for test purposes, because this file is much smaller than the original file. Unpack this file in your record filter folder. Let's assume you want to find all records from the library US-CA. Therefor you need to know the Marc21 field for libraries which is 852$a. So you type in the query.yaml file and save it:

852$a: "US-CA"

Back in the terminal you put in the command 

ruby record_filter.rb -i rism_130616_example.xml

With „-i“ you determine the input file. The default output file is called „out.xml“.  

The command

ruby record_filter.rb -h

will show you more options we'll discuss later. In your output file out.xml there are now data sets which contains US-CA in field 852. This means it contains data sets with US-CAe for example as well. The reason for this is that the record finder works with regular expression. If you only want "US-CA" and nothing more you need to write:

852$a: "US-CA$"

Of course you can combine your queries. This will find all records with „Boccherini“ an „Us-CA“:

100$a: "Boccherini"
852$a: "US-CA$"

The formula of MARC21 field 110$a is „familyname, first name“ so that you wouldn't get results with „Luigi Boccherini“. But „Boccherini, Luigi“ will work. Example:

100$0: "Boccherini, Luigi"
852$a: "US-CA"

As mentioned above you'll get an option overview with the command

ruby record_filter.rb -h

Here the options in detail:

-q: You can choose your own yaml file. Default file is query.yaml.
-c: If there are connected individual entries they will be collected.
-d: Shows additional error messages
-i: Specify the name of your input file.
-o: You can name your output file. Default file is out.xml
-z: Compresses your file with zip.
-v: Shows the recent version number of Record filter.


