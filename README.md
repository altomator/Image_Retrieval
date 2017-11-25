### Synopsis
This work uses an ETL (extract-transform-load) approach and machine learning technics to help image retrieval in multicollection digital librairies.

Specs are: 
1. Identify and extract iconography wherever it may be found, in image collections but also in printed materials (newspapers, magazines, books); 
2. Transform, harmonize and enrich the image descriptive metadata (in particular with machine learning classification tools: IBM Watson for visual recognition, Google TensorFlow Inception-V3 for image classification)
3. Load all the medatada into a web app dedicated to image retrieval. 

A proof of concept has been implemented on the World War 1 theme. All the contents have been harvested from the BnF (Bibliotheque national de France) digital collections (gallica.bnf.fr) of heritage materials (photos, drawings, engravings, maps, posters, etc.).

### GitHub
[Repository](https://github.com/altomator/Image_Retrieval/)

### Articles, blogs
["Image Retrieval in Digital Libraries"](http://www.euklides.fr/blog/altomator/Image_Retrieval/000-moreux-chiron_EN-final.pdf) (EN article, [FR article](http://www.euklides.fr/blog/altomator/Image_Retrieval/000-moreux-chiron_FR-final.pdf), [presentation](http://www.euklides.fr/blog/altomator/Image_Retrieval/MOREUX-CHIRON-presentation-final.pdf)), IFLA News Media section 2017 (Dresden, August 2017). 
 
### Datasets (soon)
The datasets are available as metadata files (one XML file/document). Images can be extracted from the metadata files thanks to [IIIF Image API](http://iiif.io/api/image/2.0/): 
- Complete dataset (300k illustrations)
- Person dataset
- Gender dataset

This dataset has been used for the image genres classification training: 
- Image genres classification dataset (10k images) 

### Installation & misc.
<b>Note</b>: All the scripts have been written by an amateur coder. They have been designed for the Gallica BnF digital documents and digital repositories, but this can be easily fixed.

The metadata are stored thanks to an in-house XML schema (IR_schema.xsd).

Sample documents are generally stored in the "DOCS" folder. Output samples are stored in OUT folders.

#### A. Extract
We've used Perl scripts. The extract step can be performed from OAI-PHM, SRU or OCR sources. 

##### OAI-PHM
The OAI-PMH Gallica repository ([endpoint](http://oai.bnf.fr/oai2/OAIHandler?verb=Identify)) can be harvested for sets or documents.
Perl script extractMD_OAI.pl can handled 2 methods:
- harvesting a complete OAI Set
- harvesting a document from its ark (or a list of documents).

Usage: 
>perl extractMD_OAI.pl gallica:corpus:1418 OUT xml 

where: 
- "gallica:corpus:1418" is the OAI set name
- "OUT" the output folder
- "xml" the (only) output format

This script also performs (using the available metadata):
- topic classification (considering the WW1 theme)
- image genres classification (photo/drawing/map...)

It outputs one XML metadata file per document, describing each page (and included illustrations) of the document.


##### SRU
SRU requesting of Gallica digital library can be done with extractARKs_SRU.pl.
The SRU request must be copy/paste directly in the script.

It outputs a text file (one ark ID per line). This output can then be used as the input of the OAI-PMH script.

Usage:
>perl extractARKs_SRU.pl OUT.txt

##### OCR
OCRed documents can be analysed using extractMD.pl script. This script is the more BnF centered of this github and it will be difficult to adapt to other context... It can handle various types of digital documents (books, newspapers) produced by the BnF or during the Europeana Newspapers.
Regarding the newspapers type, the script can handle raw OCR production or OLR production (article recognition with METS/ALTO).

Usage:
>perl extractMD.pl [-LI] mode title IN OUT format

where:
-L : extraction of illustrations is performed: dimensions, caption...
-I : BnF ark IDs are computed
mode : types of BnF documents (olren, ocren, olrbnf, ocrbnf)
title: some newspapers titles need to be identified by their title
IN : input folder
OUT : output folder
format: XML only

#### B. Transform

##### Image recognition
We've used IBM Watson [Visual Recognition API](https://www.ibm.com/watson/developercloud/doc/visual-recognition/index.html). The script calls the API to perform visual recognition of content or human faces. 

##### Image genres classification
[Inception-v3](https://www.tensorflow.org/tutorials/image_recognition) model (Google's convolutional neural network) has been retrained on a 12 classes (photos, drawings, maps, music scores, comics...) ground truth datasets (10k images). 3 Python scripts are used:
- split.py: the GT dataset is splited in a training set (2/3) and an evaluation set (1/3)  
- retrain.py: the training set is used to train the last layer of the Inception-v3 model
- label.py: the evaluation set is labeled by the model


##### Image toolkit
This script performs basic operations on the documents metadata files:
- deletion
- renumbering
- ...

#### C. Load
An XML database (BaseX.org) is used. Querying the metadata is done with XQuery (see https://github.com/altomator/EN-data_mining for   details). The web app uses [IIIF Image API](http://iiif.io/api/image/2.0/) and [Mansory](https://masonry.desandro.com/) grid layout JavaScript library for image display.


