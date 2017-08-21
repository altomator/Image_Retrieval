### Synopsis
This work uses an ETL (extract-transform-load) approach to help image retrieval in multicollection digital librairies.
Specs are: 
1. Identify and extract iconography wherever it may be found, in image collections but also in printed materials (newspapers, magazines, books); 
2. Transform, harmonize and enrich the image descriptive metadata (in particular with machine learning classification tools: IBM Watson for Visual Recognition, Google TensorFlow Inception-V3 for image classification)
3. Load all the medatada into a web app dedicated to image retrieval. 

A proof of concept has been implemented on the WW1 theme, using the BnF (Bibliotheque national de France) digital collections (gallica.bnf.fr) of heritage materials (photos, drawings, engravings, maps, etc.).


### Articles, blogs
["Image Retrieval in Digital Libraries"](http://www.euklides.fr/blog/altomator/Image_Retrieval/000-moreux-chiron_EN-final.pdf) (article), IFLA News Media section 2017 (Dresden, August 2017)

### Datasets
Soon

### Installation & misc.
<b>Note</b>: the scripts have not been written by a professional coder. They have been designed for the Gallica digital documents and digital repositories, but this can be easily fixed.

The metadata are stored thanks to an in-house XML schema (IR_schema.xsd).

Sample documents are generally stored in the "DOCS" folder. Output samples are stored in OUT folders.

#### Extract
We've used Perl scripts. The extract step can be performed form OAI-PHM, SRU or OCR sources. 

##### OAI-PHM
The OAI-PHM Gallica repository can be harvested for sets or documents.
Perl script extractMD_OAI.pl can handled 2 methods:
- harvesting a complete OAI Set
- harvesting a document from its ark (or a list of documents).

Usage: 
> perl extractMD_OAI.pl gallica:corpus:1418 OUT xml 

where "gallica:corpus:1418" is the set and xml the (only) output format

This script also performs (using the available metadata):
- topic classification (considering the WW1 theme)
- image genres classification (photo/drawing/map...)

It outputs one XML file per document, describing each page (and included illustrations) of the document.

##### SRU
SRU requesting of Gallica digital library can be done with extractARKs_SRU.pl.
The request must be copy/paste in the script.

It outputs a text file (one ark per line). This output can then be used as the input of the OAI-PHM script.

Usage:
>perl extractARKs_SRU.pl OUT.txt

##### OCR
OCRed documents can be analysed using the 

#### Transform
##### Image recognition
We've used IBM Watson Visual Recognition API. 

##### Image classification


#### Load
An XML database (BaseX.org) is used. Querying the metadata is done with XQuery (see https://github.com/altomator/EN-data_mining for   details)
The web app uses IIIF API and Mansory JavaScript library for image display.


