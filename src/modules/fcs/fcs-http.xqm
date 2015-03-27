xquery version "3.0";
(:
: Module Name: FCS
: Date: 2012-03-01
: 
: XQuery 
: Specification : XQuery v3.0
: Module Overview: Federated Content Search
:)

(:~ This module provides methods to serve XML-data via the FCS/SRU-interface fetched from a remote HTTP endpoint
: @see http://clarin.eu/fcs 
: @author Omar Siam
: @since 2015-03-26 
: @version 1.0 
:)
module namespace fcs = "http://clarin.eu/fcs/1.0/http";

import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace hc = "http://exist-db.org/xquery/httpclient";
import module namespace diag =  "http://www.loc.gov/zing/srw/diagnostic/" at  "../diagnostics/diagnostics.xqm";

declare function fcs:explain($x-context as xs:string*, $config, $context-mappings as item()+) as item()+ {
   let $log := util:log-app("DEBUG", $config:app-name, "explain http: $context-mapping/@url='"||data($context-mappings/@url)||"'"),
       $url := $context-mappings/@url||'?version=1.2&amp;operation=explain'
   return fcs:get-result-or-diag($url)
};

declare function fcs:get-result-or-diag($url as xs:anyURI) as item()+ {
   let $log := (util:log-app("DEBUG", $config:app-name, "get-result-or-diag http: GET: "||$url)),
       $response := httpclient:get($url, false(), ()),
       $logResp := (util:log-app("DEBUG", $config:app-name, "get-result-or-diag http: $response statusCode:"||$response/@statusCode),
                    util:log-app("DEBUG", $config:app-name, "get-result-or-diag http: $response type:"||$response/hc:body/@type))
   return
      if ($response/@statusCode != 200) then
        diag:diagnostics('general-error', ("&#10;GET: ", $url, "&#10;", util:serialize($response, ())))
      else if ($response/hc:body/@type != 'xml') then
        diag:diagnostics('general-error', ("&#10;GET: ", $url, "&#10;", util:serialize($response, ())))
      else 
        $response/hc:body/*
};


declare function fcs:scan($x-context as xs:string, $index-name as xs:string, $start-term as xs:string,
                          $max-terms as xs:integer, $response-position as xs:integer, $max-depth as xs:integer,
                          $x-filter as xs:string, $sort as xs:string?, $mode as xs:string,
                          $config, $context-mappings as item()+) as item()+ {
   let $query := fcs:get-query-for-scan($x-context, $index-name, $start-term, $max-terms, $response-position, $max-depth, $x-filter, $sort, $mode, $config, $context-mappings),
       $url := $context-mappings/@url||$query
   return
     fcs:get-result-or-diag($url)
};

declare function fcs:get-query-for-scan($x-context as xs:string, $index-name as xs:string, $start-term as xs:string,
                          $max-terms as xs:integer, $response-position as xs:integer, $max-depth as xs:integer,
                          $x-filter as xs:string, $sort as xs:string?, $mode as xs:string,
                          $config, $context-mappings as item()+) as xs:string {
    let $log := util:log-app("DEBUG", $config:app-name, "get-query: type "||$context-mappings/@type)
    return
    if ($context-mappings/@type = 'noske') then
       '?version=1.2&amp;operation=scan'||
       '&amp;scanClause='||$index-name||'='||$start-term||
       '&amp;maximumTerms='||$max-terms||
       '&amp;responsePosition='||$response-position
    else if ($context-mappings/@type = 'cr-xq-mets') then
       '?version=1.2&amp;operation=scan&amp;x-context='||$x-context||
       '&amp;scanClause='||$index-name||'='||$start-term||
       '&amp;maximumTerms='||$max-terms||
       '&amp;responsePosition='||$response-position||
       '&amp;x-filter='||$x-filter
    else
       '?version=1.2&amp;operation=scan&amp;x-context='||$x-context||
       '&amp;scanClause='||$index-name||'='||$start-term||
       '&amp;maximumTerms='||$max-terms||
       '&amp;responsePosition='||$response-position
};

declare function fcs:search-retrieve($query as xs:string, $x-context as xs:string*,
                                     $startRecord as xs:integer, $maximumRecords as xs:integer,
                                     $x-dataview as xs:string*, $recordPacking as xs:string,
                                     $config, $context-mappings as item()+) as item()+ {
   let $query := fcs:get-query-for-searchRetrieve($query, $x-context, $startRecord, $maximumRecords, $x-dataview, $recordPacking, $config, $context-mappings),
       $url := $context-mappings/@url||$query
   return
     fcs:get-result-or-diag($url)
};

declare function fcs:get-query-for-searchRetrieve($query as xs:string, $x-context as xs:string*,
                                     $startRecord as xs:integer, $maximumRecords as xs:integer,
                                     $x-dataview as xs:string*, $recordPacking as xs:string,
                                     $config, $context-mappings as item()+) as item()+ {
    let $log := util:log-app("DEBUG", $config:app-name, "get-query: type "||$context-mappings/@type)
    return
    if ($context-mappings/@type = 'noske') then
       '?version=1.2&amp;operation=searchRetrieve'||
       '&amp;query='||$query||
       '&amp;startRecord='||$startRecord||
       '&amp;maximumRecords='||$maximumRecords||
       '&amp;x-dataview='||$x-dataview||
       '&amp;recordPacking='||$recordPacking
    else if ($context-mappings/@type = 'cr-xq-mets') then
       '?version=1.2&amp;operation=searchRetrieve&amp;x-context='||$x-context||
       '&amp;query='||$query||
       '&amp;maximumTerms='||$startRecord||
       '&amp;maximumRecords='||$maximumRecords||
       '&amp;x-dataview='||$x-dataview||
       '&amp;recordPacking='||$recordPacking
    else
       '?version=1.2&amp;operation=searchRetrieve&amp;x-context='||$x-context||
       '&amp;query='||$query||
       '&amp;maximumTerms='||$startRecord||
       '&amp;maximumRecords='||$maximumRecords                                 
};