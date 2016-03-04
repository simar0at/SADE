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
module namespace fcs-http = "http://clarin.eu/fcs/1.0/http";

declare namespace fcs = "http://clarin.eu/fcs/1.0";

import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace hc = "http://exist-db.org/xquery/httpclient";
import module namespace diag =  "http://www.loc.gov/zing/srw/diagnostic/" at  "../diagnostics/diagnostics.xqm";

declare function fcs-http:explain($x-context as xs:string*, $config, $context-mappings as item()+) as item()+ {
   let $log := util:log-app("TRACE", $config:app-name, "explain http: $context-mapping/@url='"||data($context-mappings/@url)||"'"),
       $url := $context-mappings/@url||'?version=1.2&amp;operation=explain'
   return fcs-http:get-result-or-diag($url)
};

declare function fcs-http:get-result-or-diag($url as xs:anyURI) as item()+ {
   let $log := (util:log-app("DEBUG", $config:app-name, "get-result-or-diag http: GET: "||$url)), 
       $userPWSearch := '^(https?://)([^:@]+?:[^:@]+?)@(.*)$',
       $urlWithoutUserPW := replace($url, $userPWSearch, '$1$3'),
       $userPW := if ($url != $urlWithoutUserPW) then tokenize(replace($url, $userPWSearch, '$2'), ':') else (),
       $log2 := (util:log-app("TRAGE", $config:app-name, "get-result-or-diag http: $urlWithoutUserPW := "||$urlWithoutUserPW||" $userPW := "||string-join($userPW, ':'))),
       $response := try {httpclient:get($urlWithoutUserPW, false(), fcs-http:get-basic-auth-headers($userPW))} catch * {
       <hc:response statusCode="500">
         <hc:headers>
           <hc:header name="Content-Type" value="text/plain; charset=iso-8859-1"/>
         </hc:headers>
         <hc:body>
           {$err:code}: {$err:description}
         </hc:body>
       </hc:response>},
       $logResp := (util:log-app("TRACE", $config:app-name, "get-result-or-diag http: $response statusCode:"||$response/@statusCode),
                    util:log-app("TRACE", $config:app-name, "get-result-or-diag http: $response type:"||$response/hc:body/@type))
   let $ret :=
      if ($response/@statusCode != 200) then
        diag:diagnostics('general-error', ("&#10;GET: ", $url, "&#10;", util:serialize($response, ())))
      else if (lower-case($response/hc:body/@mimetype) != 'application/xml' and 
               lower-case($response/hc:body/@mimetype) != 'text/xml; charset=UTF-8') then
        diag:diagnostics('general-error', ("&#10;GET: ", $url, "&#10;", util:serialize($response, ())))
      else if (lower-case($response/hc:body/@encoding) = 'base64encoded') then
        util:base64-decode($response/hc:body/text())
      else 
        $response/hc:body/*,
       $retLog := util:log-app("DEBUG", $config:app-name, "get-result-or-diag http: return: "||substring(serialize($ret), 1, 1000))      
   return $ret
};

(: Create the HTTP basic authentication header if user credentials available :)
declare function fcs-http:get-basic-auth-headers($credentials as xs:string*) {
  if (empty($credentials)) then ()
  else
    let $auth := concat('Basic ', util:string-to-binary(concat($credentials[1], ':', $credentials[2])))
    return
      <headers>
        <header name="Authorization" value="{$auth}"/>
      </headers>
};


declare function fcs-http:scan($x-context as xs:string, $index-name as xs:string, $start-term as xs:string,
                          $max-terms as xs:integer, $response-position as xs:integer, $max-depth as xs:integer,
                          $x-filter as xs:string, $sort as xs:string?, $mode as xs:string,
                          $config, $context-mappings as item()+) as item()+ {
   let $query := fcs-http:get-query-for-scan($x-context, $index-name, $start-term, $max-terms, $response-position, $max-depth, $x-filter, $sort, $mode, $config, $context-mappings),
       $url := $context-mappings/@url||$query
   return
     fcs-http:get-result-or-diag($url)
};

declare function fcs-http:get-query-for-scan($x-context as xs:string, $index-name as xs:string, $start-term as xs:string,
                          $max-terms as xs:integer, $response-position as xs:integer, $max-depth as xs:integer,
                          $x-filter as xs:string, $sort as xs:string?, $mode as xs:string,
                          $config, $context-mappings as item()+) as xs:string {
    let $log := util:log-app("DEBUG", $config:app-name, "get-query: type "||$context-mappings/@type)
    return
    if ($context-mappings/@type = 'noske') then
       '?version=1.2&amp;operation=scan'||
       '&amp;scanClause='||$index-name||'='||escape-uri($start-term, true())||
       '&amp;maximumTerms='||$max-terms||
       '&amp;responsePosition='||$response-position
    else if ($context-mappings/@type = 'cr-xq-mets') then
       '?version=1.2&amp;operation=scan&amp;x-context='||$x-context||
       '&amp;scanClause='||$index-name||'='||escape-uri($start-term, true())||
       '&amp;maximumTerms='||$max-terms||
       '&amp;responsePosition='||$response-position||
       '&amp;x-filter='||$x-filter
    else
       '?version=1.2&amp;operation=scan&amp;x-context='||$x-context||
       '&amp;scanClause='||$index-name||'='||escape-uri($start-term, true())||
       '&amp;maximumTerms='||$max-terms||
       '&amp;responsePosition='||$response-position
};

declare function fcs-http:search-retrieve($query as xs:string, $x-context as xs:string*,
                                     $startRecord as xs:integer, $maximumRecords as xs:integer,
                                     $x-dataview as xs:string*, $recordPacking as xs:string, $queryType as xs:string?,
                                     $config, $context-mappings as item()+) as item()+ {
   let $query := fcs-http:get-query-for-searchRetrieve($query, $x-context, $startRecord, $maximumRecords, $x-dataview, $recordPacking, $queryType, $config, $context-mappings),
       $url := $context-mappings/@url||$query
   return
     fcs-http:get-result-or-diag($url)
};

declare function fcs-http:get-query-for-searchRetrieve($query as xs:string, $x-context as xs:string*,
                                     $startRecord as xs:integer, $maximumRecords as xs:integer,
                                     $x-dataview as xs:string*, $recordPacking as xs:string, $queryType as xs:string?,
                                     $config, $context-mappings as item()+) as item()+ {
    let $queryTypeParam := if (exists($queryType)) then '&amp;queryType='||$queryType else (),
        $log := util:log-app("DEBUG", $config:app-name, "get-query: type "||$context-mappings/@type)
    return
    if ($context-mappings/@type = 'noske') then
       '?version=1.2&amp;operation=searchRetrieve'||
       '&amp;query='||escape-uri($query, true())||
       '&amp;startRecord='||$startRecord||
       '&amp;maximumRecords='||$maximumRecords||
       '&amp;x-dataview='||
       '&amp;recordPacking='||$recordPacking||
       $queryTypeParam
    else if ($context-mappings/@type = 'cr-xq-mets') then
       '?version=1.2&amp;operation=searchRetrieve&amp;x-context='||$x-context||
       '&amp;query='||escape-uri($query, true())||
       '&amp;maximumTerms='||$startRecord||
       '&amp;maximumRecords='||$maximumRecords||
       '&amp;x-dataview='||$x-dataview||
       '&amp;recordPacking='||$recordPacking
    else
       '?version=1.2&amp;operation=searchRetrieve&amp;x-context='||$x-context||
       '&amp;query='||escape-uri($query, true())||
       '&amp;maximumTerms='||$startRecord||
       '&amp;maximumRecords='||$maximumRecords                                 
};