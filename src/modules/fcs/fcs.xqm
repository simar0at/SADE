xquery version "3.0";

(:
The MIT License (MIT)

Copyright (c) 2016 Austrian Centre for Digital Humanities at the Austrian Academy of Sciences

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE
:)
(:
: Module Name: FCS
: Date: 2012-03-01
: 
: XQuery 
: Specification : XQuery v1.0
: Module Overview: Federated Content Search
:)

(:~ This module provides methods to serve XML-data via the FCS/SRU-interface  
: @see http://clarin.eu/fcs 
: @author Matej Durco
: @since 2011-11-01 
: @version 1.1 
:)
module namespace fcs = "http://clarin.eu/fcs/1.0";
 
declare namespace sru = "http://www.loc.gov/zing/srw/";

declare variable $fcs:explain as xs:string := "explain";
declare variable $fcs:scan  as xs:string := "scan";
declare variable $fcs:searchRetrieve as xs:string := "searchRetrieve";
declare variable $fcs:defaultMaxTerms := 50;
declare variable $fcs:defaultMaxRecords := 10;declare variable $fcs:scanSortText as xs:string := "text";
declare variable $fcs:scanSortSize as xs:string := "size";
declare variable $fcs:scanSortDefault := $fcs:scanSortText;

import module namespace functx = "http://www.functx.com";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace diag = "http://www.loc.gov/zing/srw/diagnostic/" at  "../diagnostics/diagnostics.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at "../../core/repo-utils.xqm";
import module namespace index="http://aac.ac.at/content_repository/index" at "../../core/index.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace cr="http://aac.ac.at/content_repository" at "../../core/cr.xqm";

import module namespace project="http://aac.ac.at/content_repository/project" at "../../core/project.xqm";
import module namespace query  = "http://aac.ac.at/content_repository/query" at "../query/query.xqm";
import module namespace cmdcheck = "http://clarin.eu/cmd/check" at  "../cmd/cmd-check.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "../../core/resource.xqm";

import module namespace fcs-db = "http://clarin.eu/fcs/1.0/db" at "fcs-db.xqm";
import module namespace fcs-http = "http://clarin.eu/fcs/1.0/http" at "fcs-http.xqm";

(:~ The main entry-point. Processes request-parameters
regards config given as parameter + the predefined sys-config
@returns the result document (in xml, html or json)
:)
(: declare function fcs:repo($config-file as xs:string) as item()* { :)
declare function fcs:main($config) as item()* {
  let $key := request:get-parameter("key", "index"),        
        (: accept "q" as synonym to query-param; "query" overrides:)    
    $q := request:get-parameter("q", ""),
    $query := request:get-parameter("query", $q),    
        (: if query-parameter not present, 'explain' as DEFAULT operation, otherwise 'searchRetrieve' :)
    $operation :=  if ($query eq "") then request:get-parameter("operation", $fcs:explain)
                    else request:get-parameter("operation", $fcs:searchRetrieve),
    $recordPacking:= request:get-parameter("recordPacking", 'xml'),
      
    (: take only first format-argument (otherwise gives problems down the line) 
        TODO: diagnostics :)
    $x-format := (request:get-parameter("x-format", $repo-utils:responseFormatXml))[1],
    $x-context_ := request:get-parameter("x-context", request:get-parameter("project", "")),
    $x-context := if ($x-context_ eq '') then request:get-parameter("project", "") else $x-context_,
                                              $max-depth as xs:integer := xs:integer(request:get-parameter("maxdepth", 1))

  let $result :=
      if ($operation[1] eq $fcs:explain) then
          fcs:explain($x-context, $config)		
      else if ($operation eq $fcs:scan) then
        (: allow optional $index-parameter to be prefixed to the scanClause 
            this is just to simplify input on the client-side :) 
        let $index := request:get-parameter("index", ""),
            $scanClause-param := request:get-parameter("scanClause", ""),
		    $scanClause :=    if ($index ne '' and  not(starts-with($scanClause-param, $index)) ) 
		                      then concat( $index, '=', $scanClause-param)
		                      else $scanClause-param,
		    $mode := request:get-parameter("x-mode", ""),		    
(:		    protocol defines startTerm as the term in the scanClause
            $start-term := request:get-parameter("startTerm", 1),  :)
		    $response-position := request:get-parameter("responsePosition", 1),
		    $max-terms := request:get-parameter("maximumTerms", $fcs:defaultMaxTerms),
	        $x-filter := request:get-parameter("x-filter", ''),
	        $max-depth := request:get-parameter("x-maximumDepth", 1),	        
		    (: removing default value for $sort in order to allow for default @sort on <index> :)
		    $sort := request:get-parameter("sort", ())
		 return fcs:scan($scanClause, $x-context, $max-terms, $response-position, $max-depth, $x-filter, $sort, $mode, $config)
	  else if ($operation eq $fcs:searchRetrieve) then 
      	 let $start-record:= request:get-parameter("startRecord", 1),
			 $maximum-records  := request:get-parameter("maximumRecords", $fcs:defaultMaxRecords),
			 $x-dataview := request:get-parameter("x-dataview", repo-utils:config-value($config, 'default.dataview')),
			 $queryType := request:get-parameter("queryType", ())
         return 
            fcs:search-retrieve($query, $x-context, $start-record, $maximum-records, $x-dataview, $recordPacking, $queryType, $config)
    else 
      diag:diagnostics('unsupported-operation',$operation)
    
   return repo-utils:serialise-as($result, $x-format, $operation, $config, $x-context, ())
   
};


(:~ handles the explain-operation requests.
: @param $x-context optional, identifies a resource to return the explain-record for. (Accepts both MD-PID or Res-PID (MdSelfLink or ResourceRef/text))
: @returns either the default root explain-record, or - when provided with the $x-context parameter - the explain-record of given resource
:)
declare function fcs:explain($x-context as xs:string*, $config) as item() {
    
    let $log := util:log-app("DEBUG", $config:app-name, "explain switch: x-context="||$x-context),
        $context-mapping := index:map($x-context)
    return
       if (exists($context-mapping/@url)) then
          fcs-http:explain($x-context, $config, $context-mapping)
       else
          fcs-db:explain($x-context, $config, $context-mapping)
};

(:~ This function handles the scan-operation requests
:  (derived from cmd:scanIndex function)
: two phases: 
:   1. one create full index for given path/element within given collection (for now the collection is stored in the name - not perfect) (and cache)
:	2. select wished subsequence (on second call, only the second step is performed)
	
: actually wrapping function handling caching of the actual scan result (coming from do-scan-default())
: or fetching the cached result (if available)
: also dispatching to cmd-collections for the scan-clause=cmd.collections
:   there either scanClause-filter or x-context is used as constraint (scanClause-filter is prefered))

:)
declare function fcs:scan($scan-clause  as xs:string, $x-context as xs:string+, $max-terms as xs:string, $response-position as xs:string, $max-depth as xs:string, $x-filter as xs:string?, $p-sort as xs:string?, $mode as xs:string?, $config) as item() {
 
  let $error-in-parameters := fcs:check-scan-parameters-and-return-error($scan-clause, $max-terms, $response-position)
  return if (exists($error-in-parameters)) then $error-in-parameters
  else
  let $scx := tokenize($scan-clause,'='),
	  $index-name := $scx[1],
      (: from the protocol spec:
      The term [from the scan clause] is the position within the ordered list of terms at which to start, and is referred to as the start term. :)
 	  $start-term:= ($scx[2],'')[1],	 
      (: precedence of sort parameter: 1) user input (via $sort), 2) index map definition @sort in <index>, 3) fallback = 'text' via $fcs:scanSortText :)
      (: keyword 'text' and 'size', otherwise fall back on index map definitions :)
    $sort := if ($p-sort eq $fcs:scanSortText or $p-sort eq $fcs:scanSortSize) then $p-sort else ()	
	 
	 let $sanitized-xcontext := repo-utils:sanitize-name($x-context)
	 let $project-id := if (config:project-exists($x-context)) then $x-context else cr:resolve-id-to-project-pid($x-context)
    let $index-doc-name := repo-utils:gen-cache-id("index", ($sanitized-xcontext, $index-name, $sort, $max-depth)),
        $dummy2 := util:log-app("DEBUG", $config:app-name, "fcs:scan: is in cache: "||repo-utils:is-in-cache($index-doc-name, $config) ),
      $log := (util:log-app("DEBUG", $config:app-name, "cache-mode: "||$mode),
               util:log-app("DEBUG", $config:app-name, "scan-clause="||$scan-clause||": index: "||$index-name||"start term: "||$start-term),
               util:log-app("DEBUG", $config:app-name, "x-context="||$x-context||" $sanitized-xcontext="||$sanitized-xcontext),
               util:log-app("DEBUG", $config:app-name, "x-filter="||$x-filter),
               util:log-app("DEBUG", $config:app-name, "max-terms="||$max-terms),
               util:log-app("DEBUG", $config:app-name, "max-depth="||$max-depth),
                util:log-app("DEBUG", $config:app-name, "p-sort="||($p-sort,'no user input (falling back to @sort on <index> map definition)')[1]),
                util:log-app("DEBUG", $config:app-name, "$index-name="||$index-name),
                util:log-app("DEBUG", $config:app-name, "$start-term="||($start-term, "no start term given")[1])
      ),
      $context-mapping := index:map($x-context),
      $sort-or-default := ($sort, $context-mapping//index[@key = $index-name]/@sort)[1],
      $log2 := util:log-app("DEBUG", $config:app-name, "$sort-or-default="||$sort-or-default)
   return
     if (exists($context-mapping/@url)) then
       fcs-http:scan($x-context, $index-name, $start-term, xs:integer($max-terms), xs:integer($response-position), xs:integer($max-depth), $x-filter, $sort, $mode, $config, $context-mapping)
     else
       fcs-db:scan($x-context, $index-name, $start-term, xs:integer($max-terms), xs:integer($response-position), xs:integer($max-depth), $x-filter, $sort, $mode, $config, $context-mapping) 
};

declare function fcs:check-scan-parameters-and-return-error($scan-clause  as xs:string, $max-terms as xs:string, $response-position as xs:string) as item()? {
if ($scan-clause='') then
<sru:scanResponse>
   <sru:version>1.2</sru:version>
   {diag:diagnostics('param-missing',"scanClause")}
</sru:scanResponse>
else if (not(number($max-terms)=number($max-terms)) or number($max-terms) < 0 ) then
<sru:scanResponse>
   <sru:version>1.2</sru:version>
   {diag:diagnostics('unsupported-param-value',"maximumTerms")}
</sru:scanResponse>
else if (not(number($response-position)=number($response-position)) or number($response-position) < 0 ) then
 <sru:scanResponse>
    <sru:version>1.2</sru:version>
   {diag:diagnostics('unsupported-param-value',"responsePosition")}
</sru:scanResponse>
else ()
};

declare function fcs:search-retrieve($query as xs:string, $x-context as xs:string*, $startRecord as xs:string, $maximumRecords as xs:string, $x-dataview as xs:string*, $recordPacking as xs:string, $config) as item()* {
  fcs:search-retrieve($query, $x-context, $startRecord, $maximumRecords, $x-dataview, $recordPacking, (), $config)
};

(:~ 
 : Main search function that handles the searchRetrieve-operation request)
 :
 : @param $query: The FCS Query as input by the user
 : @param $x-context: The CR-Context of the query
 : @param $startRecord: The nth of all results to display
 : @param $maxmimumRecords: The maximum of records to display
 : @param $x-dataview: A comma-separated list of keywords for the output viwe on the results. This depends on <code>fcs:format-record-data()</code>.
 : @param $config: The project's config
 : @param $queryType: A means for switching the interpretation of $query between CQL (unset) and CQP ("native") and maybe others in the future.
 : @see fcs:format-record-data()
~:)
declare function fcs:search-retrieve($query as xs:string, $x-context as xs:string*, $startRecord as xs:string, $maximumRecords as xs:string, $x-dataview as xs:string*, $recordPacking as xs:string, $queryType as xs:string?, $config) as item()* {
  let $error-in-parameters := fcs:check-searchRetrieve-parameters-and-return-error($query, $recordPacking, $maximumRecords, $startRecord)
  return if (exists($error-in-parameters)) then $error-in-parameters
  else
  let $log := (util:log-app("DEBUG", $config:app-name, "query="||$query),
               util:log-app("DEBUG", $config:app-name, "x-context="||$x-context),
               util:log-app("DEBUG", $config:app-name, "startRecord="||$startRecord),
               util:log-app("DEBUG", $config:app-name, "maximumRecords="||$maximumRecords),
               util:log-app("DEBUG", $config:app-name, "x-dataview="||$x-dataview),
               util:log-app("DEBUG", $config:app-name, "recordPacking="||$recordPacking),
               if (exists($queryType)) then util:log-app("DEBUG", $config:app-name, "queryType="||$queryType) else ()
      ), $context-mapping := index:map($x-context)
  return
    if (exists($context-mapping/@url)) then
      fcs-http:search-retrieve($query, $x-context, xs:integer($startRecord), xs:integer($maximumRecords), $x-dataview, $recordPacking, $queryType, $config, $context-mapping)
    else
      fcs-db:search-retrieve($query, $x-context, xs:integer($startRecord), xs:integer($maximumRecords), $x-dataview, $recordPacking, $config, $context-mapping)
};

declare function fcs:check-searchRetrieve-parameters-and-return-error($query as xs:string, $recordPacking as xs:string, $maximum-records as xs:string, $start-record as xs:string) {
if ($query eq "") then <sru:searchRetrieveResponse><sru:version>1.2</sru:version><sru:numberOfRecords>0</sru:numberOfRecords>
                                {diag:diagnostics("param-missing", "query")}</sru:searchRetrieveResponse>
        else            if (not($recordPacking = ('string','xml'))) then 
                        <sru:searchRetrieveResponse><sru:version>1.2</sru:version><sru:numberOfRecords>0</sru:numberOfRecords>
                                {diag:diagnostics("unsupported-record-packing", $recordPacking)}</sru:searchRetrieveResponse>
                else if (not(number($maximum-records)=number($maximum-records)) or number($maximum-records) < 0 ) then
                        <sru:searchRetrieveResponse><sru:version>1.2</sru:version><sru:numberOfRecords>0</sru:numberOfRecords>
                                {diag:diagnostics("unsupported-param-value", "maximumRecords")}</sru:searchRetrieveResponse>
                else if (not(number($start-record)=number($start-record)) or number($start-record) <= 0 ) then
                        <sru:searchRetrieveResponse><sru:version>1.2</sru:version><sru:numberOfRecords>0</sru:numberOfRecords>
                                {diag:diagnostics("unsupported-param-value", "startRecord")}</sru:searchRetrieveResponse>
                else ()
};

