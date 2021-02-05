(:
 Recherche de pages illustrees par les annotations
:)

declare namespace functx = "http://www.functx.com";

declare option output:method 'html';

(: Arguments avec valeurs par defaut :)

(: nom de la base BaseX :)
declare variable $corpus as xs:string external :="1418" ;
declare variable $locale as xs:string external := "fr" ; (: langue :)
(: requete :)
declare variable $annotation as xs:string external := "voiture";
(: requete :)
declare variable $CS as xs:decimal external := 0.2;
declare variable $mode as xs:string external := "ibm";
declare variable $ad as xs:string external := "";

(: declare variable $fromPage as xs:integer external := 1;  par defaut toutes les pages :)
(: declare variable $toPage as xs:integer external := 2000; :)
declare variable $fromYear as xs:integer external := 1910;
declare variable $toYear as xs:integer external := 1920; 
declare variable $monthly as xs:string external := ""; 

(: URL Gallica de base :)
declare variable $rootURL as xs:string external := 'http://gallica.bnf.fr/ark:/12148/';
declare variable $rootIIIFURL as xs:string external := 'http://gallica.bnf.fr/iiif/ark:/12148/';

(: declare variable $years := (for $y in ($fromYear to $toYear)
   return $y); :)
   
declare variable $years := ("1920","1921","1922","1928","1936-01","1936-02", "1938", "1940");
    
declare variable $dates := (if ($monthly) then (
   (for $y in ($years)
    for $m in ("-01", "-02","-03","-04","-05","-06","-07","-08","-09","-10","-11", "-12")
   return concat($y,$m))
) else (
  (for $y in ($years)
   return $y)));

declare function local:evalQuery($query) {
    let $hits := xquery:eval($query)
    return $hits
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
let $totalData := count($data)
let $illsData := for $y in ($dates)   
    let $nills := if ($ad) then (count($data/analyseAlto/metad[matches(dateEdition,xs:string($y))]/../contenus/pages/page/ills/ill[not(@pub)])) else (
      count($data/analyseAlto/metad[matches(dateEdition,xs:string($y))]/../contenus/pages/page/ills/ill))
    return $nills
let $AdIllsData := for $y in ($dates)    
    let $nills := count($data/analyseAlto/metad[matches(dateEdition,xs:string($y))]/../contenus/pages/page/ills/ill[@pub])
    return $nills        
let $pagesData :=  for $y in ($dates)
    let $npages := sum($data/analyseAlto/metad[ matches(dateEdition,xs:string($y))]/nbPage)
    return $npages 
    
    
let $title := if ($locale='fr') then (concat ("Base : ",$corpus," &#x2014; documents : ",$totalData,"  (", $fromYear,"-",$toYear,")", if ($ad) then (" &#x2014; publicités : oui") )) else 
(concat ("Database: ",$corpus," &#x2014; documents: ",$totalData,"  (", $fromYear,"-",$toYear,")",if ($ad) then (" &#x2014; ads: yes")))
let $other := if ($locale='fr') then ('autres') else ('other')
let $mean := if ($locale='fr') then ('moyenne') else ('mean')
let $ads := if ($locale='fr') then ('publicités illustrées') else ('illustrated ads')
     
let $meansData := for $nills at $count in ($illsData) 
     let $npages := $pagesData[$count]
     let $mean := if ($npages = 0) then (0) else ($nills div $npages) 
     return string(concat(data(fn:round($mean,2)),',',codepoints-to-string(10)))          
let $meansAdData := for $nills at $count in ($AdIllsData) 
     let $npages := $pagesData[$count]
     let $mean := if ($npages = 0) then (0) else ($nills div $npages) 
     return string(concat(data(fn:round($mean,2)),',',codepoints-to-string(10)))          
   return
<head>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8"></meta>
		<title>Base : {$corpus}</title>
		<script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/1.8.2/jquery.min.js"></script>
		<script type="text/javascript">
$(function () {{
    $('#container').highcharts({{
         chart: {{
            type: 'spline'
        }},
        title: {{
            text: '{$title} '
        }},
        subtitle: {{
            text: 'Source : <a href="https://gallica.bnf.fr">Gallica</a>, BnF'
        }},
        xAxis: {{
            categories: [{concat ("""",string-join($dates, '","'),"""")}],
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
				            text: '{$mean} (illustrations/page)',
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
        series: [{{
      name: 'illustrations',
      color: "#D2CFC8",
      data: [{for $d in ($illsData) return string(concat(data($d),',',codepoints-to-string(10)))}]
    }},    
    {if ($ad) then (
          "{name: '",$ads,"', color: '#989da3', data: [",
       (for $d in ($AdIllsData) return string(concat(data($d),',',codepoints-to-string(10))))
     ,"]},"   ) }
      {{
      name: 'pages',
      color: "#E52A07",
      data: [{for $d in ($pagesData) return string(concat(data($d),',',codepoints-to-string(10)))}]
    }},
      {{ name: '{$mean} illustrations',
      yAxis: 1,
      type: 'line',
      color: Highcharts.getOptions().colors[4],
      data: [{$meansData}]
  }},
  {if ($ad) then (
  "{name: '",$mean,$ads,"', yAxis: 1, type: 'line', color: Highcharts.getOptions().colors[4], data: [", 
  $meansAdData, "]},")
  }
      {{
            type: 'pie',
            name: 'Total',       
            data: [{{
                name: 'illustrations',
                y: {sum($illsData)},
                color: "#D2CFC8",
            }},
              {if ($ad) then (concat("{name: '",$ads,"', y:", sum($AdIllsData), ", color: '#989da3'},")) else () }
           {{ 
           		name: 'pages',
							 y: {sum($pagesData)},
               color: "#E52A07"
					 }}],
            center: [80, 0],
            size: 60,
            showInLegend: false,
            dataLabels: {{
                enabled: true
            }}
            }}  ]
 }});
}});
</script>
</head>}
<body>
<script src="https://code.highcharts.com/highcharts.js"></script>
<script src="https://code.highcharts.com/modules/exporting.js"></script>
<script src="https://code.highcharts.com/themes/dark-unica.js"></script>

<div id="container" style="min-width: 500px; height: 800px; margin: 0 auto"></div>
</body>
</html>
  };


(: execution de la requete sur la base :)
let $data := collection($corpus) 
 
return
    local:createOutput($data)
