(:
 Recherche de pages illustrees par les annotations
:)

import module namespace gp = "http:/gallicapix.bnf.fr/" at "../webapp/utils.xqm";

declare namespace functx = "http://www.functx.com";

declare option output:method 'html';

(: Arguments avec valeurs par defaut :)

(: nom de la base BaseX :)
declare variable $corpus as xs:string external := "vogue";
declare variable $locale as xs:string external := "fr" ; (: langue :)
(: requete :)
declare variable $q as xs:string external := "";
(: requete :)
declare variable $CS as xs:decimal external := 0.2;
declare variable $mode as xs:string external := "ibm";

declare variable $title as xs:string external := 'Vogue';
declare variable $monthly as xs:string external := ""; 

(: URL Gallica de base :)
declare variable $rootURL as xs:string external := 'http://gallica.bnf.fr/ark:/12148/';
declare variable $rootIIIFURL as xs:string external := 'http://gallica.bnf.fr/iiif/ark:/12148/';

declare variable $mois := ("-01", "-02","-03","-04","-05","-06","-07","-08","-09","-10","-11", "-12"); 

(: declare variable $annees := ("1920","1921","1922","1923","1924","1925","1926","1927","1928","1929","1930","1931","1932","1933","1934","1935","1936","1937","1938","1939","1940");
:)
   
declare function local:evalQuery($query) {
    let $hits := xquery:eval($query)
    for $ill in $hits order by $ill/../../../../../metad/dateEdition ascending
    return $ill
};

declare function functx:mmddyyyy-to-date
  ( $dateString as xs:string? )  as xs:date? {

   if (empty($dateString))
   then ()
   else if (not(matches($dateString,
                        '^\D*(\d{2})\D*(\d{2})\D*(\d{4})\D*$')))
   then error(xs:QName('functx:Invalid_Date_Format'))
   else xs:date(replace($dateString,
                        '^\D*(\d{2})\D*(\d{2})\D*(\d{4})\D*$',
                        '$3-$2-$1'))
 } ;


(: construction de la page HTML :)
declare function local:createOutput($data) {

<html>
{
let $dataset := collection($corpus) 
let $totalDataset := count(collection($corpus)//ill)
let $totalData := count($data)

let $firstDate := fn:substring($data[1]/../../../../../metad/dateEdition,1,4)
let $lastDate := fn:substring($data[last()]/../../../../../metad/dateEdition,1,4)
let $firstYear :=  if (gp:is-a-number($firstDate)) then ($firstDate)
else ("1910")
let $lastYear := if (gp:is-a-number($lastDate)) then ($lastDate) else ("1920")
(: let $years := (for $y in ($firstYear to $lastYear) 
   return $y) :)
let $dates := (if ($monthly) then (
   (for $y in (xs:integer($firstYear) to xs:integer($lastYear))
    for $m in ("-01", "-02","-03","-04","-05","-06","-07","-08","-09","-10","-11", "-12")
   return concat($y,$m))
) else (
  (for $y in (xs:integer($firstYear) to xs:integer($lastYear))
   return $y)))

let $title := if ($locale='fr') then (concat ("Base : ",$corpus," &#x2014; illustrations résultats : ",$totalData,"  (", $firstYear,"-",$lastYear,")")) else (concat ("Database: ",$corpus," &#x2014; illustrations results : ",$totalData,"  (", $firstYear,"-",$lastYear,")"))
let $other := if ($locale='fr') then ('autres') else ('other')
let $mean := if ($locale='fr') then ('moyenne') else ('mean')
   
let $illsData := for $y in ($dates)   
    let $nills := count($data[../../../../../metad[matches(dateEdition,xs:string($y))]])
  return $nills 
let $illsTotData := for $y in ($dates)   
    let $nills := count($dataset/analyseAlto/metad[matches(dateEdition,xs:string($y))]/../contenus/pages/page/ills/ill)
  return $nills 
let $meansData := for $nills at $count in ($illsData) 
     let $nillsTot := $illsTotData[$count]
     let $mean := if ($nillsTot = 0) then (0) else ($nills div $nillsTot) 
     return string(concat(data(fn:round($mean,3)),',',codepoints-to-string(10)))  
return  
<head>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.css"></link>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"></meta>
<title lang="fr">Base : {$corpus}</title>
<title lang="en">Database : {$corpus}</title>
<script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/1.8.2/jquery.min.js"></script>
<script type="text/javascript">

function launchFct() {{
 // localize((navigator.language) ? navigator.language : navigator.userLanguage);
 localize('{$locale}');
}}

// localisation / localize function
function localize (language)
{{
  console.log("localize : "+language);
  if (language.includes('fr')) {{
     lang = ':lang(fr)';
     cacher = '[lang]:not(' + lang + ')';
     montrer = '[lang]' + lang;
   }}
   else
    {{
     lang = ':lang(en)';
     cacher = '[lang]:not(' + lang + ')';
     montrer = '[lang]' + lang;
   }}
    console.log("lang : "+lang);
    Array.from(document.querySelectorAll(cacher)).forEach(function (e) {{
      e.style.display = 'none';
    }});
    Array.from(document.querySelectorAll(montrer)).forEach(function (e) {{
      e.style.display = 'unset';
    }});
}}

$(function () {{
    $('#container').highcharts({{
        chart: {{
            type: 'spline'
        }},
        title: {{
            text: '{$title}'
        }},
        subtitle: {{
            text: 'Source : <a href="https://gallica.bnf.fr">Gallica</a>, BnF'
        }},
        xAxis: {{
            categories: [{string-join($dates, ',')}],
            tickmarkPlacement: 'on',
            title: {{
                enabled: false
            }}
        }},
				legend: {{ enabled: true

        }},
				yAxis:
				[{{ // Primary yAxis

								labels: {{
									formatter: function () {{
											return this.value / 1;
									}},
				            style: {{
				                color: "gray"
				            }}
				        }},
				        title: {{
				            text: 'total',
				            style: {{
				                color: "gray"
				            }}
				        }}
				    }}, {{ // Secondary yAxis
				        title: {{
				            text: '{$mean} (illustrations/total)',
				            style: {{
				                color: Highcharts.getOptions().colors[4]
				            }}
				        }},
				        labels: {{
				            format: '{{value}}',
				            style: {{
				                color: Highcharts.getOptions().colors[4]
				            }}
				        }},
				        opposite: true
				    }}],


        tooltip: {{
 pointFormat: '<span style="color:{{series.color}}">{{series.name}}</span> : {{point.y}} <br/>',
			split: true
        }},
        plotOptions: {{
					line: {{
							dataLabels: {{
									enabled: false
							}},
							enableMouseTracking: true
					}}
        }},
        series: [  {{
      name: 'illustrations',
      color: "#E52A07",
      data: [{for $d in ($illsData) return string(concat(data($d),',',codepoints-to-string(10)))} ]}},
      {{
      name: 'total',
      color: "#D2CFC8",
      data: [{for $d in ($illsTotData) return string(concat(data($d),',',codepoints-to-string(10)))} ]}},
      {{
      name: '{$mean}',
      yAxis: 1,
      type: 'spline',
      color: Highcharts.getOptions().colors[4],
      data: [{$meansData} ]}},
        {{
            type: 'pie',
            name: 'Total', 
            center: [90, 0],
            size: 60,
            showInLegend: false,
            dataLabels: {{
                enabled: true
            }},      
            data: [{{
                name: 'illustrations',
                y: {$totalData},
                color: "#E52A07"
            }},{{
                name: '{$other}',
                y: {$totalDataset - $totalData},
                color: "#D2CFC8"
            }}]
            
       }} ]
   }});
}});
</script>
</head>}
<body onload="">
<script src="https://code.highcharts.com/highcharts.js"></script>
<script src="https://code.highcharts.com/modules/exporting.js"></script>
<script src="https://code.highcharts.com/themes/dark-unica.js"></script>

{ let $queryString := request:parameter('q', '')
  return
<div>  
<div id="container" style="min-width: 500px; height: 800px; margin: 0 auto"></div>
<p style="font-family: sans-serif;font-size:8pt "><span class="fa">&#xf1c0; </span>&#8193;{$queryString}</p>
</div>
}
</body>
</html>
  };


(: execution de la requete sur la base :)

(:
collection('vogue')/analyseAlto/metad[matches(dateEdition,"1921")]/../contenus/pages/page/ills/ill[ (@couleur = 'coul') ]
collection('vogue')/analyseAlto/metad[matches(dateEdition,"1921")]/../contenus/pages/page/ills/ill


let $queryTest := "collection('vogue')/analyseAlto/contenus/pages/page/ills/ill[ (@couleur = 'coul') ]" 
let $data := local:evalQuery($queryTest) 
:)
 let $data := local:evalQuery(request:parameter('q', ''))  
  return
    local:createOutput($data)
