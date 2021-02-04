### Synopsis
This work uses an ETL (extract-transform-load) approach and deep learning technics to implement image retrieval functionalities in digital librairies.

Specs are: 
1. Identify and extract iconography wherever it may be found, in the still images collection but also in printed materials (newspapers, magazines, books).
2. Transform, harmonize and enrich the image descriptive metadata (in particular with deep learning classification tools: IBM Watson for visual recognition, Google TensorFlow Inception-V3 for image types classification).
3. Load all the medatada into a web app dedicated to image retrieval. 

A proof of concept, [GallicaPix](http://demo14-18.bnf.fr:8984/rest?run=findIllustrations-form.xq) has been implemented on the World War 1 theme. All the contents have been harvested from the BnF (Bibliotheque national de France) digital collections [Gallica](gallica.bnf.fr) of heritage materials (photos, drawings, engravings, maps, posters, etc.). This PoC is referenced on [Gallica Studio](http://gallicastudio.bnf.fr/), the Gallica online participative platform dedicated to the creative uses that can be made from Gallica. 



![GallicaPix](https://github.com/altomator/Image_Retrieval/blob/master/Images/gpix.jpg)

*Looking for [Georges Clemenceau](http://demo14-18.bnf.fr:8984/rest?run=findIllustrations-app.xq&filter=1&start=1&action=first&module=0.5&similarity=&corpus=1418-v2&keyword=clemenceau&kwTarget=&kwMode=&title=&fromDate=&toDate=&iptc=00&persType=00&classif=&operator=and&colName=00&illType=&size=31&density=26) iconography in GallicaPix*


### Articles, blogs, conferences
- ["Image Retrieval in Digital Libraries"](http://www.euklides.fr/blog/altomator/Image_Retrieval/000-moreux-chiron_EN-final.pdf) (EN article, [FR article](http://www.euklides.fr/blog/altomator/Image_Retrieval/000-moreux-chiron_FR-final.pdf), [presentation](http://www.euklides.fr/blog/altomator/Image_Retrieval/MOREUX-CHIRON-presentation-final.pdf)), IFLA News Media section 2017 (Dresden, August 2017). 
- ["Hybrid Image Retrieval in Digital Libraries"](https://fr.slideshare.net/Europeana/hybrid-image-retrieval-in-digital-libraries-by-jeanphilippe-moreux-europeanatech-conference-2018), EuropeanaTech 2018 (Rotterdam). Poster, TPDL 2018 (Porto)

- ["HYBRID IMAGE RETRIEVAL IN DIGITAL LIBRARIES: EXPERIMENTATION OF DEEP LEARNING TECHNIQUES"](https://pro.europeana.eu/page/issue-10-innovation-agenda), EuropeanaTech Insight, Issue 10, 2018

- ["EXPLORER DES CORPUS D’IMAGES. L’IA AU SERVICE DU PATRIMOINE"](https://bnf.hypotheses.org/2809), projet CORPUS, atelier BnF, 18 avril 2018

- ["Using IIIF for Image Retrieval in Digital Libraries: Experimentation of Deep Learning Techniques"](https://drive.google.com/open?id=1jsxT5lW3bR-582UX7a9oeOc5nGQjoQnb), [presentation], 2019 IIIF Conference (Göttingen, June 2019). 

- ["Intelligence artificielle et fouille de contenus iconographiques patrimoniaux"](https://adbu.fr/retour-sur-la-journee-detude-du-congres-adbu2019-tous-bibl-ia-thecaires-lintelligence-artificielle-vers-un-nouveau-service-public/), [video & presentation], Congrès ADBU 2019 (Bordeaux, septembre 2019). 

- ["Plongez dans les images de 14-18 avec notre nouveau moteur de recherche iconographique GallicaPix"](http://gallicastudio.bnf.fr/bo%C3%AEte-%C3%A0-outils/plongez-dans-les-images-de-14-18-en-testant-un-nouveau-moteur-de-recherche) (FR blog post)
- ["Towards new uses of cultural heritage online: Gallica Studio"](http://pro.europeana.eu/post/towards-new-uses-of-cultural-heritage-online-gallica-studio) (EN blog post)
- [Tutorial on images classification](https://github.com/CENL-Network-Group-AI/Recipes/wiki/Images-Classification-Recipe)
 
### Datasets
The datasets are available as metadata files (one XML file/document) or JsonML dumps of the BaseX database. Images can be extracted from the metadata files thanks to [IIIF Image API](http://iiif.io/api/image/2.0/): 
- Complete WW1 dataset (222k illustrations): [XML](ftp://ftp.bnf.fr/api/jeux_docs_num/Images/GallicaPix/1418-data.zip)
- Illustrated WW1 ads dataset (65k illustrations): [XML](ftp://ftp.bnf.fr/api/jeux_docs_num/Images/GallicaPix/1418ads-data.zip)
- Persons ground truth (4k illustrations): [XML](http://www.euklides.fr/blog/altomator/Image_Retrieval/GT-Persons_xml.zip), [JSON](http://www.euklides.fr/blog/altomator/Image_Retrieval/GT-Persons_json.zip)

More thematic datasets have been produced:
- [Vogue magazine](https://gallica.bnf.fr/ark:/12148/cb343833568/date), French edition, 1920-1940 (35k illustrations): [XML](https://github.com/altomator/Image_Retrieval/blob/master/vogue-data.zip)
- Zoology samples (8.7k illustrations): [XML](https://github.com/altomator/Image_Retrieval/blob/master/zoology-data.zip)
- Wallpapers and fabric designs, BnF and [TNA](https://www.nationalarchives.gov.uk/) collections (3.7k illustrations): [XML](https://github.com/altomator/Image_Retrieval/blob/master/designs.zip)


### Installation & misc.
<b>Note</b>: All the scripts have been written by an amateur developer. They have been designed for the Gallica digital documents and repositories but could be adapted to other contexts.

Some Perl or Python packages may need to be installed first. Sample documents are generally stored in a "DOCS" folder and output samples in a "OUT" folder.

### A. Extract
The global workflow is detailled bellow.

![Workflow: extract](https://github.com/altomator/Image_Retrieval/blob/master/Images/worflow.jpg)

The extract step can be performed from the catalog metada (using OAI-PMH and SRU protocols) or directly from the digital documents files (and their OCR). 

#### OAI-PMH
The OAI-PMH Gallica repository ([endpoint](http://oai.bnf.fr/oai2/OAIHandler?verb=Identify)) can be used to extract still image documents (drawings, photos, posters...) The extractMD_OAI.pl script harvests sets of documents or documents. Note: this script needs a Web connection (for Gallica OAI-PMH and Gallica APIs).

Europeana OAI is also supported (see EDM.pl for the Europeana Data Model mapping).

Perl script extractMD_OAI.pl can handled 3 methods which needs to be choosen within the script:
- harvesting a complete OAI Set, from its name:
```perl
getOAI($set);
```
- harvesting a document from its ID:
```perl
getRecordOAI("ark:/12148/bpt6k10732244");
```
- harvesting a list of documents from a file of IDs:
```perl
require "arks.pl";
```

Usage: 
>perl extractMD_OAI.pl oai_name oai_set out_folder format 


where: 
- oai_name: gallica/europeana
- oai_set:  the OAI set title
- out_fodler: the output folder
- format: the only output format supported is xml

Example:
>perl extractMD_OAI.pl gallica gallica:corpus:1418 OUT xml 


This script also performs (using the available metadata):
- IPTC topic classification (considering the WW1 theme)
- image genres classification (photo/drawing/map...)

It outputs one XML metadata file per document, describing the document (title, date...), each page of the document and the included illustrations. Some illustrations are "filtered" due to their nature (empty page, bindings) thanks to the Gallica Pagination API.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<analyseAlto>
<metad>
	<type>I</type>
	<ID>bpt6k3850489</ID>
	<titre>Nos alliés du ciel : cantique-offertoire : solo &amp; choeur à l_unisson avec accompagnement d'orgue / paroles du chanoine S. Coubé   musique de F. Laurent-Rolandez</titre>
	<dateEdition>1916</dateEdition>
	<nbPage>10</nbPage>
	<descr>Chants sacrés acc. d_orgue -- 20e siècle -- Partitions et parties</descr>
</metad>
<contenus  ocr="false" toc="false">
	<largeur>135</largeur>
	<hauteur>173</hauteur>
	<pages>
		<page  ordre="1"><blocIllustration>1</blocIllustration>
			<ills>
				<ill  h="4110" taille="6" couleur="gris" y="1" w="3204" n="1-1" x="1"><genre  CS="1">photo</genre>
				<genre  CS="0.95">partition</genre>
				<theme  CS="0.8">01</theme>
				<titraille>Nos alliés du ciel : cantique-offertoire : solo &amp; choeur à l_unisson avec accompagnement d'orgue / paroles du chanoine S. Coubé   musique de F. Laurent-Rolandez</titraille>
				</ill>
			</ills>
		</page>
	</pages>
</contenus>
</analyseAlto>
```


#### SRU (Search/Retrieve via URL)
SRU requesting of Gallica digital library can be done with the extractARKs_SRU.pl script.
The SRU request can be tested within gallica.bnf.fr and then copy/paste directly in the script:

```perl
$req="%28gallica%20all%20%22tank%22%29&lang=fr&suggest=0"
```

It outputs a text file (one ark ID per line). This output can then be used as the input of the OAI-PMH script.

Usage:
>perl extractARKs_SRU.pl OUT.txt


#### OCR
Printed collections (with OCR) can be analysed using extractMD.pl script. 
It can handle various types of digital documents (books, newspapers) produced by BnF digitization programs or during the Europeana Newspapers project. Samples are available (see readme.txt).

Regarding the newspapers type, the script can handle raw ALTO OCR mode or OLR mode (articles recognition described with a METS/ALTO format):
- <b>ocrbnf</b>: to be used with BnF documents (monographies, serials) described with a METS manifest
- <b>ocrbnflegacy</b>: to be used with BnF documents (monographies, serials) described with a refNum manifest
- <b>olrbnf</b>: to be used with BnF serials described with a METS manifest and an OLR mode (BnF METS profil) 
- <b>ocren</b>: to be used with Europeana Newspapers serials described with a METS manifest
- <b>olren</b>: to be used with Europeana Newspapers serials described with a METS manifest and an OLR mode (&copy;CCS METS profil)

The script can handle various dialects of ALTO (ALTO BnF, ALTO LoC...) which may have different ways to markup the illustrations and to express the blocks IDs. This script is the more BnF centered and it may be complex to adapt to other context. An attempt has been made with a sample delivered by the SB Berlin library.

Some parameters must be set in the Perl script, the remaining via the command line options (see readme.txt in the OCR folder).

Usage:
>perl extractMD.pl [-LI] mode title IN OUT format

where:
- -L : extraction of illustrations is performed: dimensions, caption...
- -I : BnF ARK IDs are computed
- mode : types of documents (ocren, olren, ocrbnf, olrbnf)
- title: some newspapers titles need to be identified by their title
- IN : digital documents input folder 
- OUT : output folder
- format: XML only

Example for the Europeana Newspapers subdataset *L'Humanité*, with ark IDs computation and illustrations extraction:
>perl extractMD.pl -LI ocren Humanite OCR-EN-BnF OUT-OCR-EN-BnF xml


Note: some monoline OCR documents may need to be reformatted before running the extraction script, as it does not parse the XML content (for efficiency reasons) but use grep patterns at the line level.
Usage:
>perl prettyprint.pl IN

The script exports the same image metadata than before but also texts and captions surrounding illustrations: 
```xml
<ill  w="4774" n="4-5" couleur="gris" filtre="1" y="3357" taille="0" x="114" derniere="true" h="157"><leg> </leg>
<txt>Fans— Imprimerie des Arts et Manufactures» S.rue du Sentier. (M. Baunagaud, imp.) </txt>
```

Some illustrations are filtered according to their form factor (size, localization on the page). In such cases, the illustrations are exported but they are reported with a filtered attribute ("filtre") set to true.

After this extraction step, the metadata can be enriched (see next section, B.) or directly be used as the input of BaseX XML databases (see. section C.).

For newspapers and magazines collections, another kind of content should be identified (and eventually filtered), the illustrated ads (reported with a "pub" attribute set to true). 


#### External sources
Raw images files or other digital catalogs can be used as sources to the GallicaPix database.
For these use cases, the images file are locally stored (no use of IIIF).

This first Perl script takes a folder of TNA images as input and populates a GallicaPix metadata template file, based on the file names and some parameters:

>perl extractMD_TNA_noMD.pl IN_TNA/

If metadata can be extracted first from a catalog (https://discovery.nationalarchives.gov.uk, see the crawl_TNA.py script), this script aggregates metadata from the file names and the metadata:

>perl extractMD_TNA.pl IN_TNA/ MD-BT43.xml

### B. Transform & Enrich

The toolbox.pl Perl script performs basic operations on the illustrations XML metadata files and the enrichment processing itself. This script supports the enrichment workflow as detailled bellow.

![Workflow: extract](https://github.com/altomator/Image_Retrieval/blob/master/Images/workflow2.jpg)

All the treatments described in the following sections enrich the  metadata illustrations and set some attributes on these new metadata: 
- `classif`: the treatment applied (CC: content classification, DF: face detection)
- `source`: the source of the treatment (IBM Watson, Google Cloud Vision, OpenCV/dnn, Tensorflow/Inception-v3)
- `CS`: the confidence score
- `lang`: the tag's language 
...

(See the XML schema for a detailled presentation of the data model.)

```xml
<ill classif="CCibm" ... >
            <contenuImg CS="0.598" lang="en" source="ibm">clothing</contenuImg>
            <contenuImg CS="0.5" lang="en" source="ibm">sister</contenuImg>
            <contenuImg CS="0.5" lang="en" source="ibm">nurse</contenuImg>
            <contenuImg CS="0.501" lang="en" source="ibm">mason</contenuImg>
            <contenuImg CS="0.502" lang="en" source="ibm">indoors</contenuImg>
	    <genre CS="0.88" source="TensorFlow">photo</genre>
```


#### Image genres classification
[Inception-v3](https://www.tensorflow.org/tutorials/image_recognition) model (Google's convolutional neural network, CNN) has been retrained on a multiclass ground truth datasets (photos, drawings, maps, music scores, comics... 12k images). Three Python scripts (within the Tensorflow framework) are used to train (and evaluate) a model:
- split.py: the GT dataset is splited in a training set (e.g. 2/3) and an evaluation set (1/3). The GT dataset path and the training/evaluation ratio must be defined in the script.
- retrain.py: the training set is used to train the last layer of the Inception-v3 model. The training dataset path and the generated model path must be defined.
- label_image.py: the evaluation set is labeled by the model. The model path and the input images path must be defined.

>python3 split.py 

>python3 retrain.py 

>python3 label_image.py 

To classify a set of images, the following steps must be chained:

1. Extract the image files from a documents metadata folder thanks to the IIIF protocol:
>perl toolbox.pl -extr IN_md

Mind to set a reduction factor in the "facteurIIIF" parameter (eg: `$factIIIF`=50) as the CNN resizes all images to a 299x299 matrix.

2. Move the OUT_img folder to a place where it will be found by the next script.

3. Classify the images with the CNN trained model:
>python3 label_image.py > data.csv

This will output a line per classified image:

```csv
bd	carte	dessin	filtrecouv	filtretxt	gravure	photo	foundClass	realClass	success	imgTest
0.01	0.00	0.96	0.00	0.00	0.03	0.00	dessin	OUT_img	0	./imInput/OUT_img/btv1b10100491m-1-1.jpg
0.09	0.10	0.34	0.03	0.01	0.40	0.03	gravure	OUT_img	0	./imInput/OUT_img/btv1b10100495d-1-1.jpg
...
```

Each line describes the best classified class (according to its probability) and also the probability for all the other classes.

4. The classification data must then be reinjected in the metadata files:
- Copy the data.csv file at the same level than the toolbox.pl script (or set a path in the `$dataFile` var)
- Set some parameters in toolbox.pl: 
  - `$TFthreshold`: minimal confidence score for a classification to be used
  - `$lookForAds`: for newspapers, say if the ads class must be used 
  - `$dataFile`: the CSV file name 

- Use the toolbox.pl script to import the CNN classification data in the illustrations metadata files:

>perl toolbox.pl -importTF IN_md 

>perl toolbox.pl -importTF IN_md -p # for newspapers

After running the script, a new `genre` metadata is created:
```xml
<genre CS="0.52" source="TensorFlow">gravure</genre>
```
Example: [caricatures](http://demo14-18.bnf.fr:8984/rest?run=findIllustrations-app.xq&filter=1&start=1&action=first&module=0.5&similarity=&corpus=1418-v2&keyword=clemenceau&kwTarget=&kwMode=&title=&fromDate=&toDate=&iptc=00&persType=00&classif=&operator=and&colName=00&illType=dessin&size=31&density=26) of George Clemenceau can be found using the Genre facet.

The filtering classes (text, blank pages, cover...) are handled later (see section "Wrapping up the metadata").

#### Wrapping up the metadata 
The illustrations may have been processed by multiple enrichment technics and/or described by catalogs metadata. For some metadata like topic and image genre, a "final" metadata is computed from these different sources and is described as the "final" data to be queried by the web app.

For image genre, first, a parameter must be set:
- `$forceTFgenre`: force TF classifications to supersed the metadata classifications

Usage:
>perl toolbox.pl -unify IN 

The same approach can be used on the topic metadata (`unifyTheme` option).

All the sources are preserved but a new "final" metadata is generated, via a rules-based system. In the following example, the Inception CNN found a photo but this result has been superseded by a human correction. E.g. for image genres:
```xml
<genre source="final">drawing</genre>
<genre CS="0.88" source="TensorFlow">photo</genre>
<genre CS="0.95" source="hm">drawing</genre>
```

The noise classes for genres classification are also handled during the unify processing. If an illustration is noise, the `filtre` attribute is set to true.

#### Image recognition

Various APIs or open sources frameworks can be tested and their results be requested within the web app thanks to the CBIR criteria (see screen capture below).


##### IBM Watson
We've used IBM Watson [Visual Recognition API](https://www.ibm.com/watson/developercloud/doc/visual-recognition/index.html). The toolbox.pl script calls the API to perform visual recognition of content or human faces. 

Some parameters should be set before running the script:
- `$ProcessIllThreshold`: max number of illustrations to be processed (Watson allows a free amount of calls per day)
- `$CSthreshold`: minimum confidence score for a classification to be used
- `$genreClassif`: list of illustration genres to be processed (drawing, pictures... but not maps)
- `$apiKeyWatson`: your API key

Usage for content recognition:
>perl toolbox.pl -CC IN -ibm

Usage for face detection:
>perl toolbox.pl -DF IN -ibm

Note: the image content is sent to Watson as a IIIF URL.

The face detection Watson API also outputs cropping and genre detection:
```xml
<contenuImg CS="0.96" h="2055" l="1232" sexe="M" source="ibm" x="1900" y="1785">face</contenuImg>
```
Example: looking for  ["poilus"](http://demo14-18.bnf.fr:8984/rest?run=findIllustrations-app.xq&filter=1&start=1&action=first&module=0.5&similarity=&corpus=1418-v2&keyword=poilu&kwTarget=&kwMode=&title=&fromDate=&toDate=&iptc=00&persType=face&classif=&operator=and&colName=00&size=31&density=26) faces.

##### Google Cloud Vision
The very same visual content indexing can be performed with the Google Cloud Vision API.
Just mind to set your key in `$apiKeyGoogle`.

Usage for content recognition:
>perl toolbox.pl -CC IN -google

Note: The Google face detection API outputs cropping but doesn't support genre detection.


###### OCR 
The Google Vision OCR can be applied to illustrations for which no textual metadata are available.

>perl toolbox.pl -OCR -IN_md


##### Face and object detection 
A couple of Python scripts are used to apply face and objet detection to the illustrations. They output CSV data that must then be imported in the XML metadata files.



###### OpenCV/dnn module
The [dnn](https://github.com/opencv/opencv/tree/master/modules/dnn) module can be used to try some pretrained neural network models imported from frameworks as Caffe or Tensorflow.

The detect_faces.py script performs face detection based on a ResNet network (see this [post](https://www.pyimagesearch.com/2018/02/26/face-detection-with-opencv-and-deep-learning/) for details).

1. Extract the illustration files from a collection:
>perl toolbox.pl -extr IN_md

Note: mind to set the size factor for IIIF image exportation in $factIIIF

2. Process the images:
>python detect_faces.py --prototxt deploy.prototxt.txt --model res10_300x300_ssd_iter_140000.caffemodel --dir IN_img

Note: the minimum confidence probability for a classification to be exported can be set via the command line.

It outputs a CSV file per input image, what can be merged in one file:
>cat OUT_csv/*.csv > ./data.csv
or
>find . -name "*.csv" -maxdepth 1  -exec cat {} >data.csv  \;

3. Finally import the classification in the metadata files. Mind to set the classification source as a parameter: 
>perl toolbox.pl -importDF IN_md dnn

Note: to have consistent bounding boxes, mind to keep the same size factor in $factIIIF.

![faces](https://github.com/altomator/Image_Retrieval/blob/master/Images/faces.jpg)

An object_detection.py script performs in a similar way to make content classification, thanks to a GoogLeNet network (see this [post](https://www.pyimagesearch.com/2017/08/21/deep-learning-with-opencv/) for details). It can handle a dozen of classes (person, boat, aeroplane...):

>python object_detection.py --prototxt MobileNetSSD_deploy.prototxt.txt --model MobileNetSSD_deploy.caffemodel --dir IN_img

###### Yolo v3 model
The yolo.py Python script performs object detection on a 80 classes model (see this [post](https://www.pyimagesearch.com/2018/11/12/yolo-object-detection-with-opencv/) for details).

>python3 yolo.py --dir images --yolo yolo-coco

#### Color analysis
Color names can be extracted from the colors palette (RVB) produced by the Google Cloud Vision API (done with the -CC option).
Colors may also be extracted from images thanks to the RoyGBiv Python package (based on the Colorific package).

>ls IMG/*.jpg | python3 extract_colors.py

This script generates a .csv data file and small image palette (one palette for each image) which may be displayed on top of the illustration. (The script can also detect the background color.)

The CSV color data can then be imported:
>perl toolbox.pl -importColors IN no_bckg/bckg

```xml
<contenuImg b="20" coul="1" g="26" ordre="4" r="37" source="colorific" type="bckg">#251a14</contenuImg>
```
![Colors](http://www.euklides.fr/blog/altomator/Image_Retrieval/colors.png)
*Looking for wallpaper patterns with a specific color background*


#### Languages
The GallicaPix Web app offers 2 languages (FR, EN). Classification tags from the IBM or Google APIs can be translated from English to any other language with the -translateCC option. Bilingual lexicons must be set in $googleDict or $ibmDict vars.

>perl toolbox.pl -translateCC IN ibm

```xml
<contenuImg CS="0.67" lang="en" source="google">Cathedral</contenuImg>
<contenuImg CS="0.67" lang="fr" source="google">cathédrale</contenuImg>
```


### C. Load
An XML database (BaseX.org) is the back-end. Querying the metadata is done with XQuery (setting up the HTTP BaseX server is detailled [here](https://github.com/altomator/EN-data_mining)). All the XQuery files and the other support files (.css, .jpg) must be stored in a `$RESTPATH` folder.

Note: the web app is minimalist and BaseX is not an effective choice for searching in large databases.

The web app uses [IIIF Image API](http://iiif.io/api/image/2.0/) and [Mansory](https://masonry.desandro.com/) grid layout JavaScript library for image display. The web app is builded around 2 files, a HTML form and a results list page. The business logic is implemented with JavaScript and XQuery FLOWR.

The form (`findIllustrations-form.xq`) exposes databases to users. It can be switch in DEBUG mode to access more databases and to add filtering features, which can be helpful when a complete database is implemented (mixing illustrations and illustrated ads).

![gallicaPix](http://www.euklides.fr/blog/altomator/Image_Retrieval/formv3.png)

The results list (`findIllustrations-app.xq`) has a DEBUG mode which implements a filtering functionality (for ads and filtered illustrations) and  more admin tools (display, edit, annotate).  These functions call XQuery scripts which perform updates on the database (thanks to the XQuery Update facility). These functionalities may be usefull for crowdsourcing experimentations.

![gallicaPix](http://www.euklides.fr/blog/altomator/Image_Retrieval/boats.png)
*Looking for [boats](http://demo14-18.bnf.fr:8984/rest?run=findIllustrations-app.xq&filter=1&start=1&action=first&module=0.5&similarity=&corpus=1418-v2&keyword=&kwTarget=&kwMode=&title=&fromDate=&toDate=&iptc=00&persType=00&classif=boat&operator=and&colName=00&size=31&density=26)*

A faceting functionality is also available.

![gallicaPix](http://www.euklides.fr/blog/altomator/Image_Retrieval/facettes.png)





