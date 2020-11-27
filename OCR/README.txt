
Folder: OCR-EN-BnF
-------------
Content: newspapers
Producer: Europeana Newspapers project
Manifest format: METS (UIBK)
OCR FORMAT: ALTO v2.0
Sample: BnF, L'Humanité, 1904-04-18
https://gallica.bnf.fr/ark:/12148/bpt6k250186x/f1.planchecontact

Notes :
- $typeDoc parameter must be set to "P"
- to compute BNF Ark IDs at document level, newspaper title parameter must be set on the command line and the title's record ID must be known in %hashNotices
- output: 8 illustrations (actually text blocks)

# with Ark IDs:
>perl extractMD.pl -LI ocren Humanite OCR-EN-BnF OUT-OCR-EN-BnF xml
# without Ark IDs:
>perl extractMD.pl -L ocren foo OCR-EN-BnF OUT-OCR-EN-BnF xml



Folder: OCR-EN-SBB
-------------
Content: newspapers
Producer: Europeana Newspapers project
Manifest format: METS (UIBK)
OCR FORMAT: ALTO v2.0
Sample: SB Berlin, Volkszeitung (1890-1904)/Berliner Volkszeitung (1904-1930), 1930-01-01
Notes :
- $typeDoc parameter must be set to "P"
- ALTO files names must be parametrized for SBB OCR in the Perl script:
$numFicALTOdebut = -6 # default: -8
$numFicALTOlong = 3; # default: 4

>perl extractMD.pl -L ocren foo OCR-EN-SBB OUT-OCR-EN-SBB xml


Folder: OLR-EN
-------------
Content: newspapers
Producer: Europeana Newspapers project
Manifest format: METS (CCS profile) with logical structure
OCR FORMAT: ALTO v2.0
Samples: BnF, Le Petit Journal illustré Supplément du dimanche, 10.10.1891
https://gallica.bnf.fr/ark:/12148/bpt6k7159330/f1.planchecontact
https://gallica.bnf.fr/ark:/12148/bpt6k716604p/f1.planchecontact

Note :
- $typeDoc parameter must be set to "P"
- output: 10 illustrations

>perl extractMD.pl -LI olren PJI OLR-EN OUT-OLR-EN xml



Folder: OLR-BnF
-------------
Content: newspapers
Producer: BnF
Manifest format: METS (BnF) with logical structure
OCR FORMAT: ALTO BnF v2.0
Samples: Excelsior, 1910
https://gallica.bnf.fr/ark:/12148/bpt6k46000007/f1.planchecontact
https://gallica.bnf.fr/ark:/12148/bpt6k46000341/f1.planchecontact

Note :
- $typeDoc parameter must be set to "P"
- newspaper title parameter must be set with the command line
- output: 38 illustrations + 18 illustrated ads

>perl extractMD.pl -LI olrbnf Excelsior OLR-BnF OUT-OLR-BnF xml



Folder: OCR-BnF-magazines-legacy
-----------------
Content: magazines
Producer: BnF
Manifest format: refNum (BnF, http://bibnum.bnf.fr/ns/refNum)
OCR FORMAT: ALTO BnF (http://bibnum.bnf.fr/ns/alto_prod)
Sample: La Restauration maxillo-faciale, 1919
https://gallica.bnf.fr/ark:/12148/bpt6k65199707/f1.planchecontact

Note :
- $typeDoc parameter must be set to "R"
- Output: 120 illustrations

>perl extractMD.pl -LI ocrbnflegacy foo OCR-BnF-magazines-legacy OUT-OCR-BnF-magazines-legacy  xml



Folder: OCR-BnF-mono-legacy
--------------------
Content: monographs
Producer: BnF
Manifest format: refNum (BnF, http://bibnum.bnf.fr/ns/refNum)
OCR FORMAT: ALTO BnF (http://bibnum.bnf.fr/ns/alto_prod)
Sample: Historique du 13e régiment d'artillerie coloniale pendant la guerre 1914-1918
https://gallica.bnf.fr/ark:/12148/bpt6k62168707/f1.planchecontact

Note:
- the ark IDs must be defined in arks-mono.pl file
- $typeDoc parameter must be set to "M"
- output: 1 illustration

>perl extractMD.pl -LI ocrbnflegacy foo OCR-BnF-mono-legacy OUT-OCR-BnF-mono-legacy xml



Folder: OCR-BnF-mono 
--------------------
Content: monographs
Producer: BnF
Manifest format: METS (BnF)
OCR FORMAT: ALTO BnF v2.0 (http://bibnum.bnf.fr/ns/alto_prod)
Sample: Faune entomologique française
https://gallica.bnf.fr/ark:/12148/bpt6k9612399b/f1.planchecontact


Note:
- the ark IDs must be defined in arks-mono.pl file
- $typeDoc parameter must be set to "M" 
- $dpi must be set to 400
- output: 21

>perl extractMD.pl -LI ocrbnf foo OCR-BnF-mono OUT-OCR-BnF-mono xml


Folder: OCR-BnF-magazines 
--------------------
Content: magazines
Producer: BnF
Manifest format: METS (BnF)
OCR FORMAT: ALTO BnF v1 or v2 (http://bibnum.bnf.fr/ns/alto_prod)
Sample: Vogue


Note:
- the title must be defined on the line command
- $typeDoc parameter must be set to "R" 
- $dpi must be set to 600
- $altoBnf must be set to v1 or v2
- output: 155

>perl extractMD.pl -LI ocrbnf Vogue OCR-BnF-magazines OUT-OCR-BnF-magazines xml
