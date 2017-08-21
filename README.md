### Synopsis
This work uses an ETL (extract-transform-load) approach to help image retrieval in multicollection digital librairies.
Specs are: 
1. Identify and extract iconography wherever it may be found, in image collections but also in printed materials (newspapers, magazines, books); 
2. Transform, harmonize and enrich the image descriptive metadata (in particular with machine learning classification tools: IBM Watson for Visual Recognition, Google TensorFlow Inception-V3 for image classification)
3. Load all the medatada into a web app dedicated to image retrieval. 

### Articles, blogs
["Image Retrieval in Digital Libraries"](http://www.euklides.fr/blog/altomator/Image_Retrieval/000-moreux-chiron_EN-final.pdf) (article), IFLA News Media section 2017 (Dresden, August 2017)

### Datasets
Soon

### Installation & misc.
####Extract
We've used Perl scripts. 

These scripts have been designed for the BnF (Bibliotheque national de France) digital documents and digital repositories, but this can be easily fixed. The metadata are stored thanks to an in-house XML format.

Sample documents are generally stored in the "DOCS" folder. 

####Transform
We've used Perl and Python scripts (for image classification). 

####Load
An XML database (BaseX.org) is used. Querying the metadata is done with XQuery (see https://github.com/altomator/EN-data_mining for   details)
The web app uses IIIF API and Mansory JavaScript library for image display.


