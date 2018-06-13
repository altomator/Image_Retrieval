### Synopsis
This work uses an ETL (extract-transform-load) approach and deep learning technics to implement image retrieval functionalities in digital librairies.

Specs are: 
1. Identify and extract iconography wherever it may be found, in the still images collection but also in printed materials (newspapers, magazines, books).
2. Transform, harmonize and enrich the image descriptive metadata (in particular with deep learning classification tools: IBM Watson for visual recognition, Google TensorFlow Inception-V3 for image types classification).
3. Load all the medatada into a web app dedicated to image retrieval. 

A proof of concept, [GallicaPix](http://demo14-18.bnf.fr:8984/rest?run=findIllustrations-form.xq) has been implemented on the World War 1 theme. All the contents have been harvested from the BnF (Bibliotheque national de France) digital collections [Gallica](gallica.bnf.fr) of heritage materials (photos, drawings, engravings, maps, posters, etc.). This PoC is referenced on [Gallica Studio](http://gallicastudio.bnf.fr/), the Gallica online participative platform dedicated to the creative uses that can be made from Gallica. 



![GallicaPix](http://gallicastudio.bnf.fr/sites/default/files/clemenceau_gallicastudio.JPG)
*Looking for Georges Clemenceau iconography in GallicaPix*

### GitHub
[Repository](https://github.com/altomator/Image_Retrieval/)

### Articles, blogs
- ["Image Retrieval in Digital Libraries"](http://www.euklides.fr/blog/altomator/Image_Retrieval/000-moreux-chiron_EN-final.pdf) (EN article, [FR article](http://www.euklides.fr/blog/altomator/Image_Retrieval/000-moreux-chiron_FR-final.pdf), [presentation](http://www.euklides.fr/blog/altomator/Image_Retrieval/MOREUX-CHIRON-presentation-final.pdf)), IFLA News Media section 2017 (Dresden, August 2017). 
- ["Hybrid Image Retrieval in Digital Libraries"](https://fr.slideshare.net/Europeana/hybrid-image-retrieval-in-digital-libraries-by-jeanphilippe-moreux-europeanatech-conference-2018), EuropeanaTech 2018 (Rotterdam, May 2018). 
- ["Plongez dans les images de 14-18 avec notre nouveau moteur de recherche iconographique GallicaPix"](http://gallicastudio.bnf.fr/bo%C3%AEte-%C3%A0-outils/plongez-dans-les-images-de-14-18-en-testant-un-nouveau-moteur-de-recherche) (FR blog post)
- ["Towards new uses of cultural heritage online: Gallica Studio"](http://pro.europeana.eu/post/towards-new-uses-of-cultural-heritage-online-gallica-studio) (EN blog post)
 
### Datasets
The datasets are available as metadata files (one XML file/document) or JsonML dumps of the BaseX database. Images can be extracted from the metadata files thanks to [IIIF Image API](http://iiif.io/api/image/2.0/): 
- Complete dataset (200k illustrations): [XML](http://www.euklides.fr/blog/altomator/Image_Retrieval/1418_xml.zip), [JSON](http://www.euklides.fr/blog/altomator/Image_Retrieval/1418_json.zip)
- Illustrated ads dataset (63k illustrations): [XML](http://www.euklides.fr/blog/altomator/Image_Retrieval/1418-Ads_xml.zip), [JSON](http://www.euklides.fr/blog/altomator/Image_Retrieval/1418-Ads_json.zip)
- Persons ground truth (4k illustrations): [XML](http://www.euklides.fr/blog/altomator/Image_Retrieval/GT-Persons_xml.zip), [JSON](http://www.euklides.fr/blog/altomator/Image_Retrieval/GT-Persons_json.zip)

One can leverage the complete dataset to produce other ground truths.

### Installation & misc.
<b>Note</b>: All the scripts have been written by an amateur developer. They have been designed for the Gallica digital documents and repositories but could be adapted to other contexts.

Some Perl or Python packages may need to be installed first. Sample documents are generally stored in a "DOCS" folder and output samples in a "OUT" folder.

### A. Extract
The global workflow is detailled bellow.

![Workflow: extract](http://www.euklides.fr/blog/altomator/Image_Retrieval/wf1.png)

The extract step can be performed from the catalog metada (using OAI-PMH and SRU protocols) or directly from the digital documents files (and their OCR). 

#### OAI-PMH
The OAI-PMH Gallica repository ([endpoint](http://oai.bnf.fr/oai2/OAIHandler?verb=Identify)) can be used to extract still image documents (drawings, photos, posters...) The extractMD_OAI.pl script harvests sets of documents or documents. Note: this script needs a Web connection (for Gallica OAI-PMH and Gallica APIs)

Perl script extractMD_OAI.pl can handled 3 methods:
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
>perl extractMD_OAI.pl gallica:corpus:1418 OUT xml 

where: 
- "gallica:corpus:1418" is the OAI set title
- "OUT" the output folder
- "xml" the (only) output format

This script also performs (using the available metadata):
- IPTC topic classification (considering the WW1 theme)
- image genres classification (photo/drawing/map...)

It outputs one XML metadata file per document, describing the document (title, date...), each page of the document and the included illustrations. Some illustrations are "filtered" due to their nature (empty page, bindings).

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
Printed collections (with OCR) can be analysed using extractMD.pl script. This script is the more BnF centered and it will be tricky to adapt to other context... It can handle various types of digital documents (books, newspapers) produced by the BnF or during the Europeana Newspapers project.

Regarding the newspapers type, the script can handle raw ALTO OCR mode or OLR mode (articles recognition described with a METS/ALTO format):
- ocrbnf: to be used with BnF documents (monographies, serials) described with a refNum manifest
- olrbnf: to be used with BnF serials described with a METS manifest and an OLR mode (BnF METS profil) 
- ocren: to be used with Europeana Newspapers serials described with a METS manifest
- olren: to be used with Europeana Newspapers serials described with a METS manifest and an OLR mode (&copy;CCS METS profil)

The script can handle various dialects of ALTO (ALTO BnF, ALTO LoC...) which may have different ways to markup the illustrations and to express the blocks IDs.

Some parameters must be set in the Perl script, the remaining via the command line options.

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
>perl extractMD.pl -LI ocren Humanite OCR-EN OUT-OCR-EN xml


Note: some monoline OCR documents may need to be reformatted before running the extraction script, as it does not parse the XML content (for efficiency reasons) but use grep patterns at the line level.
Usage:
>perl prettyprint.pl IN

The script exports the same metadata than before but also texts and captions surrounding illustrations: 
```xml
<ill  w="4774" n="4-5" couleur="gris" filtre="1" y="3357" taille="0" x="114" derniere="true" h="157"><leg> </leg>
<txt>Fans— Imprimerie des Arts et Manufactures» S.rue du Sentier. (M. Baunagaud, imp.) </txt>
```

Some illustrations are filtered according to their characteristics (size, form). In such cases, the illustrations are exported but they are reported with a "filtre" attribute set to true.

After this extraction step, the metadata can be enriched (see next section, B.) or directly be used as the input of BaseX XML databases (see. section C.).

For newspapers and magazines collections, another kind of content should be identified (and eventually filtered), the illustrated ads (reported with a "pub" attribute set to true). 


### B. Transform & Enrich

The toolbox.pl Perl script performs basic operations on the illustrations metadata files and the enrichment processing itself. This script supports the enrichment workflow as detailled bellow.

![Workflow: extract](http://www.euklides.fr/blog/altomator/Image_Retrieval/wf2.png)

All the treatments described in the following sections enrich the  metadata illustrations and set some attributes on these new metadata: 
- `classif`: the processing applied (CC: content classification, DF: face detection)
- `source`: the source of the processing (IBM Watson, Google Cloud Vision, OpenCV/dnn, Tensorflow/Inception-v3)
- `CS`: the metadata confidence score

```xml
<ill classif="CCibm CCgoogle" ... >
            <contenuImg CS="0.8137588" source="google">black and white</contenuImg>
            <contenuImg CS="0.8162437" source="google">weapon</contenuImg>
            <contenuImg CS="0.85856307" source="google">churchill tank</contenuImg>
            <contenuImg CS="0.9450831" source="google">vehicle</contenuImg>
            <contenuImg CS="0.94837654" h="2560" l="3534" source="google" x="466.6" y="352.8">combat vehicle</contenuImg>
            <contenuImg CS="0.9654834" h="2560" l="3534" source="google" x="466.6" y="352.8">motor vehicle</contenuImg>
            <contenuImg CS="0.98043555" h="2560" l="3534" source="google" x="466.6" y="352.8">tank</contenuImg>
            <contenuImg CS="1.0" source="ibm">gray color</contenuImg>
            <contenuImg CS="0.53" source="ibm">tracked vehicle</contenuImg>
            <contenuImg CS="0.812" source="ibm">vehicle</contenuImg>
            <contenuImg CS="0.592" source="ibm">amphibious vehicle</contenuImg>
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

- Use the toolbox.pl script to import the CNN classification data in the illustrations metadata files:
>perl toolbox.pl -importTF IN_md 
>perl toolbox.pl -importTF IN_md -p # for newspapers

After running the script, a new `genre` metadata is created:
```xml
	<genre CS="0.52" source="TensorFlow">gravure</genre>
```

The filtering classes (text, blank pages, cover...) are handled later (see section "Wrapping up the metadata").


#### Image recognition
We've used IBM Watson [Visual Recognition API](https://www.ibm.com/watson/developercloud/doc/visual-recognition/index.html). The script calls the API to perform visual recognition of content or human faces. 

Usage:
>perl toolbox.pl -CC IN 



#### Wrapping up the metadata 
The illustrations may have been processed by multiple enrichment technics and/or described by catalogs metadata. For some metadata like topic and image genre, a "final" metadata is computed from these different sources and is described as the "final" data to be queried by the web app.

First, some parameters must be set:
$`forceTFgenre`: force TF classifications to supersed the metadata classifications

Usage:
>perl toolbox.pl -unify IN 

All the sources are preserved but a new "final" metadata is generated, via a rules-based system. In the following example, the Inception CNN found a photo but this result has been superseded by a human correction:
E.g. for image genres:
```xml
  	<genre source="final">drawing</genre>
        <genre CS="0.88" source="TensorFlow">photo</genre>
        <genre CS="0.95" source="hm">drawing</genre>
```

The noise classes for genres classification are also handled during the unify processing. If an illustration is noise, the `filtre` attribute is set to true.


### C. Load
An XML database (BaseX.org) is the back-end. Querying the metadata is done with XQuery (setting up the HTTP BaseX server is detailled here: https://github.com/altomator/EN-data_mining). All the XQuery files and the other support files (.css, .jpg) must be stored in a $RESTPATH folder.

Note: the web app is minimalist and BaseX is not an effective choice for searching in large databases.

The web app uses [IIIF Image API](http://iiif.io/api/image/2.0/) and [Mansory](https://masonry.desandro.com/) grid layout JavaScript library for image display. The web app is builded around 2 files, a HTML form and a results list page. The business logic is implemented with JavaScript and XQuery FLOWR.

The form (findIllustrations-form.xq) exposes 2 databases to users: general illustrations and illustrated ads. It can be switch in DEBUG mode to access more databases and to add filtering features, which can be helpful when a complete database is implemented (mixing illustrations and illustrated ads).


![gallicaPix](http://www.euklides.fr/blog/altomator/Image_Retrieval/form.png)


The results list (findIllustrations-app.xq) also has a DEBUG mode which implements a filtering functionality (for ads and filtered illustrations) and some more minor tools (display, edit). 

The results list page also call some XQuery scripts which perform updates on the database (thanks to the XQuery Update Facility).

![gallicaPix](http://www.euklides.fr/blog/altomator/Image_Retrieval/boat.png)
* Looking for boat *

