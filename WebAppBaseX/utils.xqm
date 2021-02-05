module namespace gp = "http:/gallicapix.bnf.fr/";


(: avoiding Server-side request forgery :)
declare  function gp:isAlphaNum($string as xs:string) as xs:boolean { 
  matches($string, '^([a-z]|[A-Z]|\d)+$')
};

declare function gp:is-a-number
  ( $value as xs:anyAtomicType? )  as xs:boolean {

   string(number($value)) != 'NaN'
 } ;
 
(: Conversion de formats de date
   Date formats conversion       :)
declare function gp:mmddyyyy-to-date
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

