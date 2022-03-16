## GallicaPix data model ##

The model is document driven:
- a GallicaPix database is composed of documents, described through their bibliographical metadata,
- a document is a list of ordered pages,
- a pages may include illustrations,
- an illustration is characterised by several descriptors of different types (technical: size, position, color mode...; iconographic: technique, function, genre...; semantic: caption, subject, theme...). An illustration may include visual contents or textual contents,
- a visual content is related to an object, a concept or a color present in the illustration,
- a textual content describes the texts present in the illustration or arranged around the illustration and linked to it,
- some of these elements may have a geometric positioning in relation to the page or the illustration.

Bibliographical metadata are extracted from the Gallica OAI-PMH repository are stored at the document level. The generally are Dublin Core like metadata.

Illustration related metadata are either surfaced by the BnF catalog, infered from other metadata or infered with trained ML models. They are stored at the illustration level:
- technique used to produce the illustration (in the BnF catalog, Intermarc zone #285)
- function of the illustration (#646)
- genre of the illustration (#641)

[Intermarc reference](https://www.bnf.fr/fr/referentiels-intermarc) 

The infered metadata are also characterised by their source (human production, models or tools) and their confidence score.
