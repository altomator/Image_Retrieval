# Image_Retrieval
*Image Retrieval in Digital Libraries - Multicollection Experimentation of Machine Learning techniques*

### Synopsis
This work use an ETL (extract-transform-load) approach to help image retrieval in multicollection digital librairies. 
That aims to: 
1. Identify and extract iconography wherever it may be found, in image collections but also in printed materials (newspapers, magazines, books); 
2. Transform, harmonize and enrich the image descriptive metadata (in particular with machine learning classification tools: IBM Watson for Visual Recognition, Google TensorFlow Inception-V3 for image classification)
3. Load all the medatada into a web app dedicated to image retrieval. 

[Detailled presentation](http://altomator.github.io/EN-data_mining/)

### Installation & misc.
####Extract
We've used Perl scripts. 

These scripts have been designed for the BnF (Bibliotheque national de France) digital documents and digital repositories, but this can be easily fixed. The metadata are stored thanks to an in-house XML format.

Sample documents are generally stored in the "DOCS" folder. 

####Transform
We've used Perl and Python scripts (for image classification). 

####Load
An XML database (BaseX.org) is used. Querying the metadata is done with XQuery.
The web app uses IIIF API and Mansory JavaScript library for image display.

### Datasets
Soon
