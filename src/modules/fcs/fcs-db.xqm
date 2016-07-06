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

(:~ This module provides methods to serve XML-data via the FCS/SRU-interface fetched from the local exist-db 
: @see http://clarin.eu/fcs 
: @author Matej Durco
: @since 2011-11-01 
: @version 1.1 
:)
module namespace fcs-db = "http://clarin.eu/fcs/1.0/db";
 
declare namespace fcs = "http://clarin.eu/fcs/1.0";
declare namespace sru = "http://www.loc.gov/zing/srw/";
declare namespace zr = "http://explain.z3950.org/dtd/2.0/";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace cmd = "http://www.clarin.eu/cmd/";
declare namespace xhtml= "http://www.w3.org/1999/xhtml";
declare namespace aac = "urn:general";
declare namespace mets="http://www.loc.gov/METS/";

declare namespace xlink="http://www.w3.org/1999/xlink";

import module namespace functx = "http://www.functx.com";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace diag =  "http://www.loc.gov/zing/srw/diagnostic/" at  "../diagnostics/diagnostics.xqm";
import module namespace cr="http://aac.ac.at/content_repository" at "../../core/cr.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace kwic = "http://exist-db.org/xquery/kwic";
(:import module namespace cmdcoll = "http://clarin.eu/cmd/collections" at  "../cmd/cmd-collections.xqm"; :)
import module namespace cmdcheck = "http://clarin.eu/cmd/check" at  "../cmd/cmd-check.xqm";
(:import module namespace cql = "http://exist-db.org/xquery/cql" at "../query/cql.xqm";:)
import module namespace query  = "http://aac.ac.at/content_repository/query" at "../query/query.xqm";
(:import module namespace facs = "http://www.oeaw.ac.at/icltt/cr-xq/facsviewer" at "../facsviewer/facsviewer.xqm";:)
import module namespace facs = "http://aac.ac.at/content_repository/facs" at "../../core/facs.xqm";
import module namespace wc="http://aac.ac.at/content_repository/workingcopy" at "../../core/wc.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "../../core/project.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "../../core/resource.xqm";
import module namespace index="http://aac.ac.at/content_repository/index" at "../../core/index.xqm";
import module namespace rf="http://aac.ac.at/content_repository/resourcefragment" at "../../core/resourcefragment.xqm";


declare variable $fcs-db:explain as xs:string := "explain";
declare variable $fcs-db:scan  as xs:string := "scan";
declare variable $fcs-db:searchRetrieve as xs:string := "searchRetrieve";

declare variable $config:app-root external;

declare variable $fcs-db:scanSortText as xs:string := "text";
declare variable $fcs-db:scanSortSize as xs:string := "size";
declare variable $fcs-db:scanSortDefault := $fcs-db:scanSortText;
declare variable $fcs-db:indexXsl := doc(concat(system:get-module-load-path(),'/index.xsl'));
declare variable $fcs-db:flattenKwicXsl := doc(concat(system:get-module-load-path(),'/flatten-kwic.xsl'));
declare variable $fcs-db:kwicWidth := 40;
declare variable $fcs-db:filterScanMinLength := 2;
declare variable $fcs-db:defaultMaxTerms := 50;
declare variable $fcs-db:defaultMaxRecords := 10;

declare function fcs-db:explain($x-context as xs:string*, $config, $context-mappings as item()+) as item() {

    let $md-dbcoll := collection(repo-utils:config-value($config,'metadata.path'))

    let $server-host := config:param-value($config, "base-url"), 
        $database := repo-utils:config-value($config, 'project-id'),
        $title := concat( repo-utils:config-value($config, 'project-title'), 
                    if ($x-context != '') then concat(' - ', $context-mappings/xs:string(@title)) else '') ,
        $descr := repo-utils:config-value($config, 'teaser-text'),
        $author := repo-utils:config-value($config, 'author'),
        $contact := repo-utils:config-value($config, 'contact'),
        $date-modified := 'TODO'
      
      
    let $explain:=
    <sru:explainResponse>
 <sru:version>1.1</sru:version>
 <sru:record>

   <sru:recordSchema>http://explain.z3950.org/dtd/2.1/</sru:recordSchema>
   <sru:recordPacking>xml</sru:recordPacking>
   <sru:recordData>
    <zr:explain xmlns:zr="http://explain.z3950.org/dtd/2.0/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://explain.z3950.org/dtd/2.0/ file:/C:/Users/m/3lingua/corpus_shell/_repo2/corpus_shell/fcs/schemas/zeerex-2.0.xsd"
    authoritative="false" id="id1">
    <zr:serverInfo protocol="SRU" version="1.2" transport="http">
        <zr:host>{$server-host}</zr:host>
        <zr:port>80</zr:port>
        <zr:database>{$database}</zr:database>
    </zr:serverInfo>
    <zr:databaseInfo>
        <zr:title lang="en" primary="true">{$title}</zr:title>
        <zr:description lang="en" primary="true">{$descr}</zr:description>
        <zr:author>{$author}</zr:author>
        <zr:contact>{$contact}</zr:contact>
    </zr:databaseInfo>
    <zr:metaInfo>
        <zr:dateModified>{$date-modified}</zr:dateModified>
    </zr:metaInfo>
    <zr:indexInfo>
        <zr:set identifier="isocat.org/datcat" name="isocat">
            <zr:title>ISOcat data categories</zr:title>
        </zr:set>
        <zr:set identifier="clarin.eu/fcs" name="fcs">
            <zr:title>CLARIN - Federated Content Search</zr:title>
        </zr:set>
        <!-- <index search="true" scan="true" sort="false">
            <title lang="en">Resource</title>
            <map>
                <name set="fcs">resource</name>
            </map>
        </index> -->
        { for $index in $context-mappings//index
            let $ix-key := $index/xs:string(@key)
            let $ix-label := ($index/xs:string(@label),$ix-key)[1]
(: rather retain explicit order           order by $ix-key:)
            return
                <zr:index search="true" scan="{($index/data(@scan), 'false')[1]}" sort="{($index/data(@sort), 'false')[1]}" cr:type="{if ($index/@facet) then 'nested' else 'flat'}">
                <zr:title lang="en">{$ix-label}</zr:title>
                <zr:map>
                    <zr:name set="fcs">{$ix-key}</zr:name>
                </zr:map>
        </zr:index>
        }
    </zr:indexInfo>
    <zr:schemaInfo>
    <!--    <schema identifier="clarin.eu/cmd" location="" name="cmd" retrieve="true">
            <title lang="en">Component Metadata</title>
        </schema> -->
    </zr:schemaInfo>
    <zr:configInfo>
        <!-- should translate to x-cmd-context extension-parameter if correctly interpreted: http://explain.z3950.org/dtd/commentary.html#8 
                    or shall we rather directly write: x-cmd-context or x-fcs-context -->
<!--        <supports type="extraSearchData">cmd context</supports> -->
    </zr:configInfo>
</zr:explain>
   </sru:recordData>
 </sru:record>
</sru:explainResponse>

    return $explain
};

declare function fcs-db:scan($x-context as xs:string, $index-name as xs:string, $start-term as xs:string,
                          $max-terms as xs:integer, $response-position as xs:integer, $max-depth as xs:integer,
                          $x-filter as xs:string, $sort as xs:string?, $mode as xs:string,
                          $config, $context-mappings as item()+) as item() {
  (: get the base-index from cache, or create and cache :)
  let $index-doc-name := repo-utils:gen-cache-id("index", ($x-context, $index-name, $sort, $max-depth)),	
	  $sanitized-xcontext := repo-utils:sanitize-name($x-context), 
	  $project-id := if (config:project-exists($sanitized-xcontext)) then $sanitized-xcontext else cr:resolve-id-to-project-pid($sanitized-xcontext),
      $log := util:log-app("DEBUG", $config:app-name, "is in cache: "||repo-utils:is-in-cache($index-doc-name, $config)),              
      $index-scan :=
        (: scan overall existing indices, do NOT store the result! :)        
        if ($index-name= 'cql.serverChoice') then
        (: FIXME: the start-term/x-filter is temporary hack until the client-side adapts the new param-semantics :) 
                    fcs-db:scan-all($x-context, ($start-term, $x-filter)[1], $config)
        else
        if (repo-utils:is-in-cache($index-doc-name, $config) and not($mode='refresh')) then
          let $log := util:log-app("DEBUG", $config:app-name, "reading index "||$index-doc-name||" from cache"),
              $ret := repo-utils:get-from-cache($index-doc-name, $config),
              $logIndexScan := util:log-app("DEBUG", $config:app-name, "fcs-db:scan: $index-scan := "||substring(serialize($ret),1,80)||"...")
          return $ret          
        else
        (: TODO: cmd-specific stuff has to be integrated in a more dynamic way! :)
            let $log := util:log-app("DEBUG", $config:app-name, "generating index "||$index-doc-name)
            let $data :=
                (:
                if ($index-name eq $cmdcoll:scan-collection) then
                    let $starting-handle := if ($filter ne '') then $filter else $x-context
                    return cmdcoll:colls($starting-handle, $max-depth, cmdcoll:base-dbcoll($config))
                  (\: just a hack for now, handling of special indexes should be put solved in some more easily extensible way :\)  
                else :) 
                if ($index-name eq 'cmd.profile') then
(:(\:                    let $context := repo-utils:context-to-collection($x-context, $config):\):)
                    cmdcheck:scan-profiles($x-context, $config)
                    
                else 
                if (starts-with($index-name, 'fcs.')) then
                    let $log := util:log-app("TRACE", $config:app-name, "fcs:scan: fcs.* handling"),
                        $metsdivs := 
                           switch ($index-name)
                                (: resources only :)
                                case 'fcs.resource' return let $resources := project:list-resources($x-context)
                                                           return $resources!<mets:div>{./@*}</mets:div>
                                case 'fcs.rf' return if ($project-id eq $x-context) then project:list-resources($x-context)
                                                        else resource:get($x-context,$project-id)
                                case 'fcs.toc' return if ($project-id eq $x-context) then
                                    (: this delivers the whole structure of all resources - it may be too much in one shot 
                                        resource:get-toc($project-id) would deliver only up until chapter level 
                                        alternatively just take fcs.resource to get only resource-listing :)
                                        let $log := util:log-app("TRACE", $config:app-name, "fcs:scan toc for all resources in "||$project-id)
                                        return
                                            project:get-toc-resolved($project-id)
                                        else
                                        let $log := util:log-app("TRACE", $config:app-name, "fcs:scan toc for one resource "||$x-context||" in "||$project-id)
                                        return 
                                            resource:get-toc($x-context,$project-id)                                                        
                                                               
                            default return ()
                    (:let $map := 
(\:                        if ($x-context= ('', 'default')) then 
                             doc(repo-utils:config-value($config, 'mappings')):\)
                          if (not($context-map/xs:string(@key) = $x-context) ) then 
                                $context-map
                        else
                            (\: generate a map based on the indexes defined for given context :\) 
                            let $data-collection := repo-utils:context-to-collection($x-context, $config)
(\:                            let $context-map := fcs:get-mapping('', $x-context,$config):\)
                            let $fcs-resource-index := fcs:get-mapping('fcs.resource', $x-context,$config)
                            let $index-key-xpath := $fcs-resource-index/(path[xs:string(@type)='key'], path)[1]
                            let $index-label-xpath := $fcs-resource-index/(path[xs:string(@type)='label'], path)[1]
                            let $base-elem := $fcs-resource-index/xs:string(@base_elem)
                            return <map >{
                                ($context-map/@key, $context-map/@title, 
                                for $item in util:eval(concat("$data-collection/descendant-or-self::", $base-elem))
                                    let $key := util:eval(concat("$item/", $index-key-xpath ))
                                    let $label := util:eval(concat("$item/", $index-label-xpath ))
                                    return <map key="{$key}" title="{$label}" />
                                )}</map>
:)
(:                    let $mappings := doc(repo-utils:config-value($config, 'mappings')):)
                    (: use only module-config here - otherwise scripts.path override causes problems :) 
                    let $xsl := repo-utils:xsl-doc('metsdiv-scan', "xml", $config)
                    
                    (: if no data was retrieved ($metsdivs empty) pass at least an empty element, so that the basic envelope gets rendered 
                    FIXME: actually this should return an empty envelope without any sru:term if there is no data (now it is one) :)
                    return transform:transform(($metsdivs,<mets:div/>)[1],$xsl,())
(:                    return $context-map:)
                else
                    fcs-db:do-scan-default($index-name, $x-context, $sort, $config)         

          (: if empty result, return the empty result, but don't store
            to not fill cache with garbage:)
(:            return $data:)
        
        return  if (exists($data)) then 
                        let $log := util:log-app("DEBUG", $config:app-name, "generating index "||$index-doc-name||" with data "||substring(serialize($data),1,240)),
                            $ret := repo-utils:store-in-cache($index-doc-name , $data, $config,'indexes') 
(:                        let $logNotStroring := util:log-app("ERROR", $config:app-name, "caching disabled!"),
                            $ret := $data:)
                        return $ret
                    else 
                        let $dummy := util:log-app("DEBUG", $config:app-name, "no data for index "||$index-doc-name)
                        return ()

        (:if (number($data//sru:scanResponse/sru:extraResponseData/fcs:countTerms) > 0) then
        
                else $data:)

    
	(: extract the required subsequence (according to given sort) :)
	(:let $res-nodeset :=  if ($index-name= 'cql.serverChoice') then
	                           $index-scan
	                    else transform:transform($index-scan,$fcs-db:indexXsl, 
			<parameters><param name="scan-clause" value="{$scan-clause}"/>
			            <param name="mode" value="subsequence"/>
			            <param name="x-context" value="{$x-context}"/>
						<param name="sort" value="{$sort}"/>
						<param name="filter" value="{$filterx}"/>
						<param name="start-item" value="{$start-item}"/>
					    <param name="response-position" value="{$response-position}"/>
						<param name="max-items" value="{$max-items}"/>
			</parameters>),
		$count-items := count($res-nodeset/sru:term),
		(\: $colls := if (fn:empty($collection)) then '' else fn:string-join($collection, ","), :\)
        $colls := string-join( $x-context, ', ') ,
		$created := fn:current-dateTime():)
	
	(: extra handling if fcs.resource=root, and for cql.serverChoice (there we did the filtering already in scan-all() :)
    let $start-term-subseq := if (($index-name= 'fcs.resource' and $start-term='root') or $index-name='cql.serverChoice') then '' else $start-term,
        $log := util:log-app("DEBUG", $config:app-name, "fcs-db:scan: $start-term-subseq := "||$start-term-subseq||", $start-term := "||$start-term)
    
	let $terms-subsequence := fcs-db:scan-subsequence($index-scan/descendant-or-self::sru:scanResponse/sru:terms/sru:term, $start-term-subseq, $max-terms, $response-position, $x-filter)
    (:  return $res-nodeset   :)
(:    return $index-scan  :)
    (:DEBUG
    
    :)
    
    return <sru:scanResponse xmlns:fcs="http://clarin.eu/fcs/1.0">
            <sru:version>1.2</sru:version>
            <sru:terms>
            {$terms-subsequence}        
            </sru:terms>            
            {$index-scan/sru:scanResponse/sru:extraResponseData}            
            <sru:echoedScanRequest>
                <sru:scanClause>{$index-name}={$start-term}</sru:scanClause>
                <sru:maximumTerms>{$max-terms}</sru:maximumTerms>
                <fcs:x-context>{$x-context}</fcs:x-context>
                <fcs:x-filter>{$x-filter}</fcs:x-filter>
            </sru:echoedScanRequest>
        </sru:scanResponse>
};

(:~ returns appropriate subsequence of the index based on filter, startTerm and maximumTerms as defined in
@seeAlso http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/cs01/part6-scan/searchRetrieve-v1.0-cs01-part6-scan.html#responsePosition

@param $maximum-terms how many terms maximally to return; 0 => all; in nested scans limit is applied to every leaf-set separately
:)
declare function fcs-db:scan-subsequence($terms as element(sru:term)*, $start-term as xs:string?, $maximum-terms as xs:integer, $response-position as xs:integer, $x-filter as xs:string?) as item()* {
let $log := util:log-app("DEBUG", $config:app-name, "fcs-db:scan-subsequence: $start-term := "||$start-term||", $terms := "||substring(serialize($terms),1,80)||"...")
(:$max-depth as xs:integer, $p-sort as xs:string?, $mode as xs:string?, $config) as item()? {:)
let $x-filter-lc := lower-case($x-filter)

let $recurse-subsequence := if ($terms/sru:extraTermData/sru:terms/sru:term) then
                        let $log := util:log-app("TRACE", $config:app-name, "fcs-db:scan-subsequence: there are more levels of terms:"||serialize($terms/sru:extraTermData/sru:terms/sru:term[1]))
                        return
                        for $term in $terms
                                let $children-subsequence := if ($term/sru:extraTermData/sru:terms/sru:term) then (: go deeper if children terms :) 
                                            fcs-db:scan-subsequence($term/sru:extraTermData/sru:terms/sru:term, $start-term,$maximum-terms, $response-position, $x-filter)
                                            else ()
                                            (: only return term if it has any child terms (after filtering) :)
                                return if (exists($children-subsequence)) then 
                                          <sru:term>{($term/*[not(local-name()='extraTermData')],
                                         if ($term/sru:extraTermData) then (: if given term has extraTermData :)
                                                <sru:extraTermData>
                                                { if ($term/sru:extraTermData/sru:terms) then (: term could have extraTermData but no children terms :) 
                                                        ($term/sru:extraTermData/*[not(local-name()='terms')],
                                                        <sru:terms>{$children-subsequence}</sru:terms>)
                                                   else $term/sru:extraTermData/*                                                  
                                                } </sru:extraTermData>
                                              else ()
                                          )} </sru:term>
                                       else ()
                    else (: do filtering on flat terms-sequence or only on the leaf-nodes in case of nested terms-sequences (trees) :)
                        (: if $maximum-terms=0 return all terms :)
                        let $log := util:log-app("TRACE", $config:app-name, "fcs-db:scan-subsequence: do filtering on flat terms-sequence or only on the leaf-nodes in case of nested terms-sequences (trees) if $maximum-terms=0 return all terms")
                        let $maximum-terms-resolved := if ($maximum-terms=0) then count($terms) else $maximum-terms                    
                        return if ($x-filter='' or not(exists($x-filter))) then
                                    if ($start-term='' or not(exists($start-term))) then
                                        let $log := util:log-app("TRACE", $config:app-name, "fcs-db:scan-subsequence: no start-term and no x-filter, just return first $maximum-terms from the terms-sequence") 
                                        return subsequence($terms,1,$maximum-terms-resolved)
                                      else
                                        let $log := util:log-app("DEBUG", $config:app-name, "fcs-db:scan-subsequence: start-term and no x-filter, return the following siblings of the startTerm; regard response-position"),
                                            $logTerms := util:log-app("DEBUG", $config:app-name, "fcs-db:scan-subsequence: $terms := "||substring(serialize($terms),1,80)||"...")
(:                                        let $start-search-term-position := count($terms[starts-with(sru:value,$start-term)][1]/preceding-sibling::*) + 1:)
(:                                        let $start-search-term-position := $terms[starts-with(sru:value,$start-term)][1]/sru:extraTermData/fcs:position:)
                                            let $start-search-term-position := index-of ($terms, $terms[starts-with(sru:value,$start-term)][1])
                                        let $start-list-term-position := $start-search-term-position - $response-position + 1
                                        let $dummy := util:log-app("DEBUG", $config:app-name, "start-search/list-term position: "||$start-search-term-position||'/'||$start-list-term-position)
        (:                                $terms[$start-search-term-node/position() - $response-position]:)
                                        return subsequence($terms,$start-list-term-position,$maximum-terms-resolved)
                                  else       
                                    if ($start-term='' or not(exists($start-term))) then
                                    (: no start-term and x-filter, return the first $maximum-terms terms from the filtered! terms-sequence  :)
        (:  TODO: regard other types of matches :)
                                        subsequence($terms[starts-with(lower-case(sru:displayTerm),$x-filter-lc)],1,$maximum-terms-resolved)
                                      else 
                                      (: start-term and x-filter, return $maximum-terms terms from the filtered! terms-sequence starting from the $start-term :)
                                        let $filtered-terms := $terms[starts-with(lower-case(sru:displayTerm),$x-filter-lc)]
                                        let $start-search-term-position := index-of ($filtered-terms, $filtered-terms[starts-with(sru:value,$start-term)][1])
                                        (: thought would need to reapply the filter :)
(:                                        let $start-search-term-position := count($filtered-terms[starts-with(sru:value,$start-term)][1]/preceding-sibling::*[starts-with(lower-case(sru:displayTerm),$x-filter-lc)]) + 1:)
                                        let $start-list-term-position := $start-search-term-position - $response-position + 1
                                        let $dummy := util:log-app("DEBUG", $config:app-name, "start-search/list-term position: "||$start-search-term-position||'/'||count($filtered-terms))
                                        return subsequence($filtered-terms,$start-list-term-position,$maximum-terms-resolved)
        (:                                $terms[starts-with(sru:displayTerm,$start-term)]/following-sibling::sru:term[starts-with(sru:displayTerm,$x-filter)][position()<=$maximum-terms]:)
let $logRet := util:log-app("TRACE", $config:app-name, "fcs-db:scan-subsequence: $recurse-subsequence := "||serialize(subsequence($recurse-subsequence,1,3))||"...")
return  $recurse-subsequence
(:return subsequence($filteredData,  , $maximumTerms):)

};

(:~ delivers matching(!) terms from all indexes marked as scan=true(!) 
    to prevent too many records results are only returned, when the filter is at least $fcs-db:filterScanMinLength (current default=2)  
:)
declare function fcs-db:scan-all($project as xs:string, $filter as xs:string, $config ) as item()* {
(:  let $indexes :=  collection(project:path("abacus","indexes")):)
  let $index-definitions := index:map($project)//index[@scan='true']
  let $indexes := for $ix in $index-definitions    
                              let $index-doc-name := repo-utils:gen-cache-id("index", ($project, $ix/xs:string(@key), 'text', 1))
                             return repo-utils:get-from-cache($index-doc-name, $config)
  
  let $terms := if (string-length($filter) >= $fcs-db:filterScanMinLength) then
                    $indexes//sru:value[ft:query(., $filter)]/parent::sru:term union $indexes//sru:displayTerm[ft:query(., $filter)]/parent::sru:term
                  else ()
            (: get rid of nested terms  and adding cr:type :)
   let $terms-pruned := for $t in $terms
                                let $type := if (exists($t/sru:extraTermData/cr:type)) then () (: it will be copied anyhow :)
                                                else let $ix-key := root($t)//sru:scanClause/text()
                                                       let $ix-label := ($index-definitions[@key=$ix-key]/xs:string(@label),$ix-key)[1] 
                                                    return <cr:type l="{$ix-label}">{$ix-key}</cr:type> (: add if not provided :)
                                let $extraTermData := 
                                       <sru:extraTermData>{($t/sru:extraTermData/*[not(local-name()='terms')], $type)}</sru:extraTermData>                                 
                               return
                                <sru:term>{($t/@*, $t/*[not(local-name()='extraTermData')], $extraTermData) }</sru:term>
    let $dummy-log := util:log-app("DEBUG", $config:app-name, "terms/pruned:"||count($terms)||"/"||count($terms-pruned))
    
  return 
        <sru:scanResponse xmlns:fcs="http://clarin.eu/fcs/1.0">
            <sru:version>1.2</sru:version>
            <sru:terms>
            {$terms-pruned}
            </sru:terms>
            <sru:extraResponseData>
                
             </sru:extraResponseData>
            <sru:echoedScanRequest>
                <sru:scanClause>cql.serverChoice={$filter}</sru:scanClause>
                <sru:maximumTerms/>
            </sru:echoedScanRequest>
        </sru:scanResponse>
(:        <fcs:countTerms level="top">{count($terms)}</fcs:countTerms>
                <fcs:countTerms level="total">{count($terms//sru:term)}</fcs:countTerms>:)
};

declare function fcs-db:do-scan-default($index as xs:string, $x-context as xs:string, $sort as xs:string?, $config) as item()* {
    let $log := util:log-app("DEBUG", $config:app-name, "fcs-db:do-scan-default: $index := "||$index||", $x-context := "||$x-context||", $sort := "||$sort)
    let $logConfig := util:log-app("TRACE", $config:app-name, "fcs-db:do-scan-default: $config := "||substring(serialize($config),1,80)||"...")
    let $ts0 := util:system-dateTime()
    let $project-pid := repo-utils:context-to-project-pid($x-context,$config)
    let $facets := index:facets($index,$project-pid)
    let $index-elem := index:index($index,$project-pid),
        $log := util:log-app("DEBUG", $config:app-name, "fcs-db:do-scan-default: $facets: "||serialize($facets)||" $index-elem: "||serialize($index-elem) )
(:    let $path := index:index-as-xpath($scan-clause,$project-pid):)
    (:let $data-collection := repo-utils:context-to-collection($x-context, $config),
        $nodes := util:eval("$data-collection//"||$path):)
(:    let $context-parsed := repo-utils:parse-x-context($x-context,$config):)
    let $data := repo-utils:context-to-data($x-context,$config),
        $logData := util:log-app("DEBUG", $config:app-name, "fcs-db:do-scan-default: $data: "||count($data)),
    (: this limit is introduced due to performance problem >50.000?  nodes (100.000 was definitely too much) :)
(:        $nodes := subsequence(util:eval("$data//"||$path),1,$fcs-db:maxScanSize):)
        $nodes := index:apply-index($data, $index,$project-pid,())

    let $index-label := ($index-elem/xs:string(@label), $index-elem/xs:string(@key) )[1],
    $logSettings := util:log-app("DEBUG", $config:app-name, "fcs-db:do-scan-default: $project-pid :="||$project-pid||", $facets := "||serialize($facets)||", $index-elem := "||serialize($index-elem)||", $index-label := "||$index-label)
    let $terms :=
        if ($nodes) then 
            if ($facets/index)
                then fcs-db:group-by-facet($nodes, $sort, $facets/index, $project-pid)
                else fcs-db:term-from-nodes($nodes, $sort, $index, $project-pid)
           else ()
    let $ts1 := util:system-dateTime()
    let $dummy2 := util:log-app("DEBUG", $config:app-name, "fcs:do-scan-default: index: "||$index||", duration:"||($ts1 - $ts0))        
    return 
        <sru:scanResponse xmlns:fcs="http://clarin.eu/fcs/1.0">
            <sru:version>1.2</sru:version>
            {$terms}
            <sru:extraResponseData>
                <fcs:countTerms level="top">{count($terms)}</fcs:countTerms>
                <fcs:countTerms level="total">{count($terms//sru:term)}</fcs:countTerms>
                <fcs:indexLabel>{$index-label}</fcs:indexLabel>
             </sru:extraResponseData>
            <sru:echoedScanRequest>
                <sru:scanClause>{$index}</sru:scanClause>
                <sru:maximumTerms/>
            </sru:echoedScanRequest>
        </sru:scanResponse>
};

(:%private :)
declare function fcs-db:term-from-nodes($nodes as item()+, $order-param as xs:string?, $index-key as xs:string, $project-pid as xs:string) {
    let $ts0 := util:system-dateTime()
    let $dummy := util:log-app("DEBUG", $config:app-name, "fcs:term-from-nodes: "||$index-key)
    let $termlabels := project:get-termlabels($project-pid,$index-key)
    (:let $data :=  for $n in $node
                    let $term-value := index:apply-index($n,$index-key,$project-pid,'match-only')                                                    
                    return $term-value
    :)                
    (:let $data :=  for $n in $node
                    let $term-value := index:apply-index($n,$index-key,$project-pid,'match-only'),
                        $value-map := map:entry("value",$term-value)
                    let $term-label := fcs:term-to-label($term-value,$index-key,$project-pid,$termlabels)
                    let $label-value := if ($term-label) then $term-label
                                        else string-join(index:apply-index($n,$index-key,$project-pid,'label-only'),'')                                    
                            (\:switch(true())
                                case ($term-label!='') return $term-label
                                case ($label-path!='') return string-join(util:eval("$n/"||$label-path),'')
                                default return $term-value:\)                            
                    let $label-map := map:entry("label",$label-value)                            
                    return map:new(($value-map,$label-map)):)
    let $index-elem := index:index($index-key,$project-pid)
    let $sort := ($order-param,$index-elem/@sort[.=($fcs-db:scanSortSize,$fcs-db:scanSortText)],$fcs-db:scanSortDefault)[1],
        $logSettings := util:log-app("DEBUG", $config:app-name, "fcs:term-from-nodes: $sort :="||$sort||", $index-elem := "||substring(serialize($index-elem),1,240))
    let $ts1 := util:system-dateTime()
    (: since an expression like  
        group by $x 
        let $y 
        order by $y 
     is not possible in eXist (although a xquery 3.0 use case cf. http://www.w3.org/TR/xquery-30-use-cases/#groupby_q6) we have to separated 
     the group operation from the sort operation here     
    :)
    let $terms-unordered :=           
        for $g at $pos in $nodes
        let $term-value-g := string-join(index:apply-index($g,$index-key,$project-pid,'match-only'),' ')
        group by $term-value-g 
        return
            let $m-value := map:entry("value",$term-value-g),
                $m-count := map:entry("count",count($g)),
                $firstOccurence := map:entry("firstOccurence",$g[1]),
                $log := util:log-app("TRACE", $config:app-name, 'fcs-db:term-from-nodes: $terms-unordered value => '||$term-value-g||', count => '||count($g))
            return map:new(($m-value,$m-count,$firstOccurence))
    let $terms := 
            for $t in $terms-unordered
            let $t-value := $t("value"),
                $t-count := $t("count"),
                $firstOccurence := $t("firstOccurence"),
                $label := 
                    let  $log := util:log-app("TRACE", $config:app-name, 'fcs-db:term-from-nodes: $terms value => '||$t("value")||', count => '||$t("count")||', $firstOccurence := '||substring(serialize($t("firstOccurence")),1,240)||'...'),
                         $term-label := string-join(fcs-db:term-to-label($t-value,$index-key,$project-pid,$termlabels,$firstOccurence),'')
                    return
                        if ($term-label) 
                        then $term-label[1]
                        else string-join(index:apply-index($firstOccurence,$index-key,$project-pid,'label-only'),''),
                $log := util:log-app("TRACE", $config:app-name, 'fcs-db:term-from-nodes: $terms label => '||$label)
            order by 
                if ($sort='size') then $t-count else true() descending,
                if ($sort='text') then $label else true() ascending
                 collation "?lang=de-DE"
            return map:new((map:entry("value",$t-value),map:entry("count",$t-count),map:entry("label",$label)))
            
   let $ts2 := util:system-dateTime(),
       $dummy2 := util:log-app("TRACE", $config:app-name, "fcs-db:term-from-nodes: after ordering; index: "||$index-key||", duration:"||($ts2 - $ts1)),
       $ret := 
       <sru:terms> 
        {
        for $term at $pos in $terms
        return <sru:term>
                    <sru:value>{$term("value")}</sru:value>
                    <sru:displayTerm>{$term("label")}</sru:displayTerm>
                    <sru:numberOfRecords>{$term("count")}</sru:numberOfRecords>
                    <sru:extraTermData>
                        <fcs:position>{$pos}</fcs:position>
                    </sru:extraTermData>
                </sru:term>
                }
       </sru:terms>,
       $logRet := util:log-app("TRACE", $config:app-name, "fcs-db:term-from-nodes return "||substring(serialize($ret),1,480))
   return $ret
};



declare %private function fcs-db:group-by-facet($data as node()*, $order-param as xs:string?, $index as element(index), $project-pid) as item()* {
    let $index-key := $index/xs:string(@key)
    let $log := util:log-app("DEBUG", $config:app-name, "fcs:group-by-facet($data, "||$order-param||", "||$index/@key||", "||$project-pid||")")
    let $termlabels := project:get-termlabels($project-pid,$index-key)
    let $index-sorting-key := $index/@sort
    let $facet_sort := ($order-param,$index-sorting-key[.=($fcs-db:scanSortSize,$fcs-db:scanSortText)],$fcs-db:scanSortDefault)[1]
    let $groups := 
        let $maps := 
            for $x in $data 
              let $g := index:apply-index ($x, $index-key, $project-pid,'match-only')              
            group by $g 
                return if (exists($g)) then                    
                        map:entry(($g)[1],$x)
                    else ()
        let $map := map:new($maps)
        return $map
    let $group-keys := map:keys($groups)
    let $log := (util:log-app("DEBUG", $config:app-name, "fcs:group-by-facet: $group-keys: "||string-join($group-keys,', ')),
                 util:log-app("DEBUG", $config:app-name, "fcs:group-by-facet: $order-param="||$order-param||", $index-sorting-key="||$index-sorting-key||", $fcs-db:scanSortDefault="||$fcs-db:scanSortDefault),
                 util:log-app("DEBUG", $config:app-name, "fcs:group-by-facet: sorting facet "||$index-key||" by "||$facet_sort))
    let $terms := 
        for $group-key in $group-keys
        let $entries := map:get($groups, $group-key)        
         let $term-label := fcs-db:term-to-label($group-key,$index-key,$project-pid,$termlabels)
         let $label := if ($term-label) then $term-label
                                        else index:apply-index($entries[1],$index-key,$project-pid,'label-only')
        let $count := count($entries)        
        order by
            if ($facet_sort='size') then $count else true() descending,
            if ($facet_sort='text') then $label else true() ascending            
        return
            <sru:term>
                <sru:displayTerm>{$label}</sru:displayTerm>
                <sru:value>{$group-key}</sru:value>
                <sru:numberOfRecords>{$count}</sru:numberOfRecords>
                <sru:extraTermData>
                    <cr:type>{$index-key}</cr:type>
                    {if ($index/index)
                    then fcs-db:group-by-facet($entries, $order-param, $index/index, $project-pid)
                    else fcs-db:term-from-nodes($entries, $order-param, root($index)/index/@key, $project-pid)}
                </sru:extraTermData>
            </sru:term> 
    return
        (: we might have situations where different levels of nesting of facets is required, e.g.  
            Index "index"
              |
              |- Facet "a"
              |     |
              |     |- Subfacet "a1"
              |            |- Value 1
              |            |- Value 2
              |                ...
              |
              |     |- Subfacet "a1"
              |            |- Value 1
              |            |- Value 2
              |                 ...
              |- Facet "b"
                    |- Value 1
                    |- Value 2
                         ...
                         
        Since the map definitions of the subfacet will be applied to facet "b" as well, 
        there would occur grouping where this is undesired. 
        For this a special handling is introduced here: whenever the facet of a term returns 
        only one term and when this term is the same as its parent term, the facet will be "ignored" (i.e. 
        will not be output as a term on its own right) and its child terms will be output directly to their 
        grandparent term. E.g.
        
        Data:        
            <v type="a1x">...</v>
            <v type="a1y">...</v>
            <v type="a2x">...</v>
            <v type="a2y">...</v>
            <v type="bx">...</v>
            <v type="by">...</v>
        
        Index definitions:  
            <index key="index" facet="facet">
                <path match="@type">v</path>
            </index>
            
            <index key="facet" facet="subfacet">
                <path match="if (@type = ('a1x','a1y','a2x','a2y')) then 'a' else 'b'">v</path>
            </index>
            
            <index key="subfacet">
                <path match="if (@type = ('a1x','a1y')) then 'a1' else if (@type = ('a2x','a2y')) then 'a2' else 'b'">v</path>
            </index>
        
        defining some values of 'subfacet' to be the same as its parent 'facet', the subgrouping will be ignored and a flat list 
        of values will be output instead
        
        :)
        if (count($group-keys)=1 and count($terms) = 1 and $terms/sru:value/text() = $group-keys)
        then 
            let $log := util:log-app("INFO",$config:app-name,"fcs:group-by-facet: flattening facet "||$index-key||" w/ value "||$terms/sru:value/text()||" because it contains only 1 term with the same index-key as its parent")
            return $terms/sru:extraTermData/sru:terms
        else <sru:terms>{$terms}</sru:terms>
};

(:~ lookup a label to a term using a freshly loaded the projects termlabel map 
you really should try to use the second method with termlabels already resolved
it spears you a lot of time  
:)
(:%private :)
declare function fcs-db:term-to-label($term as xs:string?, $index as xs:string, $project-pid as xs:string) as xs:string?{
    let $log := util:log-app('TRACE', $config:app-name, 'fcs-db:term-to-label $term := '||$term||', $index := '||$index),
        $ret := if ($term) then 
                   let $termlabels := project:get-termlabels($project-pid)
                   return fcs-db:term-to-label($term,$index,$project-pid, $termlabels)
                else (),
         $logRet := util:log-app('TRACE', $config:app-name, 'fcs-db:term-to-label return '||$ret)
    return $ret
};

declare function fcs-db:term-to-label($term as xs:string?, $index as xs:string, $project-pid as xs:string, $termlabels) {
    fcs-db:term-to-label($term, $index, $project-pid, $termlabels, ())
};
(:~ lookup a label to a term using the termlabel map passed as argument
this is the preferred method, the resolution of the projects termlabels map should happen before the scan loop, 
to prevent repeated lookup of this map, which has serious performance impact
~:)
declare function fcs-db:term-to-label($term as xs:string?, $index as xs:string, $project-pid as xs:string, $termlabels, $firstOccurence as node()?) as xs:string?{
    let $log := util:log-app('TRACE', $config:app-name, 'fcs-db:term-to-label $term := '||$term||', $index := '||$index||', $termlabels := '||substring(serialize($termlabels),1,240)),
        $ret := if ($term and $termlabels) then 
            $termlabels//term[data(@key) eq $term][ancestor::*/data(@key) eq $index]
         else if ($term and $firstOccurence[@ref]) then fcs-db:term-to-label-from-xml-id($term, $index, $project-pid, $firstOccurence)
         else (),
        $logRet := util:log-app('TRACE', $config:app-name, 'fcs-db:term-to-label return '||$ret)
    return $ret
};
(:~ lookup a label to a term using a ref attribute that links an occurence to some other part of the same document.
This may not scale very well so cached indexes are used here to speed up further scans.
~:)
declare function fcs-db:term-to-label-from-xml-id($term as xs:string, $index as xs:string, $project-pid as xs:string, $firstOccurence as node()) as xs:string? {
    let $referencedNode := fcs-db:get-referenced-node($firstOccurence),
        $log := util:log-app('TRACE', $config:app-name, 'fcs-db:term-to-label-from-xml-id $term := '||$term||', $index := '||$index||', $firstOccurence := '||substring(serialize($firstOccurence),1,240)||'...,  $referencedNode := '||substring(serialize($referencedNode),1,240)||'...'),
        $ret := if ($referencedNode) then index:apply-index($referencedNode, $index, $project-pid, 'label-only') else (),
        $logRet := util:log-app('TRACE', $config:app-name, 'fcs-db:term-to-label-from-xml-id return '||$ret) 
    return $ret
};

declare %private function fcs-db:get-referenced-node($node as node()) as node() {
    root($node)//*[@xml:id eq replace(data($node/@ref), '^#', '')]
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
 : @see fcs:format-record-data()
~:)
declare function fcs-db:search-retrieve($query as xs:string, $x-context as xs:string*,
                                     $startRecord as xs:integer, $maximumRecords as xs:integer,
                                     $x-dataview as xs:string*, $recordPacking as xs:string,
                                     $config, $context-mappings as item()+) as item()* {
        
        let $start-time := util:system-dateTime()                        
        let $project-id := cr:resolve-id-to-project-pid($x-context)
        let $context-parsed:=repo-utils:parse-x-context($x-context,$config)
                        
        (: basically search on workingcopy, just in case of resourcefragment lookup, we have to go to resourcefragments :)        
        (:let $data := if (contains($query,$config:INDEX_INTERNAL_RESOURCEFRAGMENT)) 
                        then collection(project:path($project-id, 'resourcefragments'))  
                        else repo-utils:context-to-collection($x-context, $config):)
        
        (: basically we search on working copies and filter out fragments and resoruces  
           (prefixed with a minus sign, e.g. &x-context=abacus2,-abacus2.1) below :)
        (: FIXME add support for index 'fcs.resource' :)
        let $data := if (contains($query,$config:INDEX_INTERNAL_RESOURCEFRAGMENT)) 
                     then collection(project:path($project-id, 'resourcefragments'))  
                     else repo-utils:context-map-to-data($context-parsed,$config)
        
        let $xpath-query := query:query-to-xpath($query,$project-id),
            $log := util:log-app("TRACE", $config:app-name, "fcs-db:search-retrieve: $xpath-query = "||$xpath-query) 
        
         (: ! results are only actual matching elements (no wrapping base_elem, i.e. resourcefragments ! :)
        let $result-unfiltered:= query:execute-query ($query,$data,$project-id)                         
        (: filter excluded resources or fragments unless this is a direct fragment request :)
        let $result := 
                if (contains($query,$config:INDEX_INTERNAL_RESOURCEFRAGMENT)) then
                let $log := util:log-app("TRACE", $config:app-name, "fcs-db:search-retrieve: query contains"||$config:INDEX_INTERNAL_RESOURCEFRAGMENT)
                return $result-unfiltered
                else repo-utils:filter-by-context($result-unfiltered,$context-parsed,$config),
            $log := util:log-app("TRACE", $config:app-name, "fcs-db:search-retrieve: $result = "||serialize($result))
        let	$result-count := fn:count($result),            
            $facets := if (contains($x-dataview,'facets') and $result-count > 1) then fcs-db:generateFacets($result, $query) else (),

            $ordered-result := if (contains($query,$config:INDEX_INTERNAL_RESOURCEFRAGMENT))
                then $result
                else fcs-db:sort-result($result, $query, $config),                
            $log := util:log-app("TRACE", $config:app-name, "fcs-db:search-retrieve: $ordered-result = "||serialize($ordered-result)),                               
            $result-seq := fn:subsequence($ordered-result, $startRecord, $maximumRecords),
(:            $result-seq := fn:subsequence($result, $startRecord, $maximumRecords),:)
            $seq-count := fn:count($result-seq),        
            $end-time := util:system-dateTime(),
            $log := util:log-app("TRACE", $config:app-name, "fcs-db:search-retrieve: $result-seq["||$startRecord||", +"||$maximumRecords||"] :"||serialize($result-seq))
        (: when displaying certain indexes (e.g. toc) we only want to show the first resource fragment :) 
        let $config-param :=    if (contains($query,'fcs.toc')) 
                                then 
                                    map{
                                        "config" := $config,
                                        "x-highlight" := "off",
                                        "no-of-rf" := 1 
                                    }
                                else 
                                    $config,
            $log := util:log-app("TRACE", $config:app-name, "fcs:search-retrieve $config instance of map() "||($config instance of map())), 
            $result-seq-expanded := if (not($config-param instance of map()) or $config-param("x-highlight") != "off") then
               let $log := util:log-app("DEBUG", $config:app-name, "fcs:search-retrieve x-highlight = on")
               return util:expand($result-seq)
            else
               let $log := util:log-app("DEBUG", $config:app-name, "fcs:search-retrieve x-highlight = off")
               return $result-seq
       
             let $records :=
               <sru:records>{
                for $rec at $pos in $result-seq-expanded
         	    let $rec-data := fcs-db:format-record-data($result-seq[$pos], $rec, $x-dataview, $x-context, $config-param)
                return 
                for $rec-data-part in $rec-data return 
         	          <sru:record>
         	              <sru:recordSchema>http://clarin.eu/fcs/1.0/Resource.xsd</sru:recordSchema>
         	              <sru:recordPacking>xml</sru:recordPacking>         	              
         	              <sru:recordData>{$rec-data-part}</sru:recordData>         	              
         	              <sru:recordPosition>{$pos}</sru:recordPosition>
         	              <sru:recordIdentifier>{($rec-data-part/fcs:ResourceFragment[1]/data(@ref),$rec-data-part/data(@ref))[1]}</sru:recordIdentifier>
         	          </sru:record>
         	   }</sru:records>,
             $end-time2 := util:system-dateTime(),
             $log := util:log-app("TRACE", $config:app-name, "fcs-db:search-retrieve: $records = "||serialize($records))
             
             return 
                switch (true())
                    case ($xpath-query instance of element(sru:diagnostics)) return  
                        <sru:searchRetrieveResponse>
                            <sru:version>1.2</sru:version>
                            <sru:numberOfRecords>{$result-count}</sru:numberOfRecords>
                            {$xpath-query}
                        </sru:searchRetrieveResponse>
                
                    case ($startRecord > $result-count + 1 ) return
                        <sru:searchRetrieveResponse>
                            <sru:version>1.2</sru:version>
                            <sru:numberOfRecords>{$result-count}</sru:numberOfRecords>
                            {diag:diagnostics('start-out-of-range',concat( $startRecord , ' > ', $result-count))}
                        </sru:searchRetrieveResponse>
                        
                    default return
                        <sru:searchRetrieveResponse>
                            <sru:version>1.2</sru:version>
                            <sru:numberOfRecords>{$result-count}</sru:numberOfRecords>
                            <sru:echoedSearchRetrieveRequest>
                                <sru:version>1.2</sru:version>
                                <sru:query>{$query}</sru:query>
                                <fcs:x-context>{$x-context}</fcs:x-context>
                                <fcs:x-dataview>{$x-dataview}</fcs:x-dataview>
                                <sru:startRecord>{$startRecord}</sru:startRecord>
                                <sru:maximumRecords>{$maximumRecords}</sru:maximumRecords>
                                <sru:query>{$query}</sru:query>
                                <sru:baseUrl>{repo-utils:config-value($config, "base.url")}</sru:baseUrl>
                            </sru:echoedSearchRetrieveRequest>
                            <sru:extraResponseData>
                              	<fcs:returnedRecords>{$seq-count}</fcs:returnedRecords>

                                <fcs:duration>{($end-time - $start-time, $end-time2 - $end-time) }</fcs:duration>
                                <fcs:transformedQuery>{ $xpath-query }</fcs:transformedQuery>
                            </sru:extraResponseData>
                            {$records}
                            {   if ($xpath-query instance of element(diagnostics)) 
                                then  <sru:diagnostics>{$xpath-query/*}</sru:diagnostics> 
                                else ()
                            }
                            {$facets}                     
                        </sru:searchRetrieveResponse>
                        
(:                                <fcs:numberOfMatches>{ () (\: count($match) :\)}</fcs:numberOfMatches>:)
};

(:~ sort result 
currently supporting only default sort by resource (the explicit resource order as defined in project.xml 
TODO: read the sortkeys from orig-query and order by those :)
declare function fcs-db:sort-result ($result, $orig-query as xs:string, $config) as node()* {
let $project-id := ($result/xs:string(@cr:project-id))[1]
let $resources-in-result := distinct-values ( $result/data(@cr:resource-pid))
let $resource-list := project:list-resources($project-id)[xs:string(@ID) = $resources-in-result]
 
for $res in $resource-list
        let $res-id := $res/data(@ID)
        let $resource-hits := $result[data(@cr:resource-pid) = $res-id ]
          return $resource-hits
 
};

(:~ facets are only available in SRU 2.0, but we need them now.

For now only for faceting over resources

xsi:schemaLocation="http://docs.oasis-open.org/ns/search-ws/facetedResults http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/os/schemas/facetedResults.xsd"
:)
declare function fcs-db:generateFacets($result, $orig-query) {
 let $project-id := ($result/xs:string(@cr:project-id))[1]
 let $resources-in-result := distinct-values ( $result/data(@cr:resource-pid)) 
 (:for $hit in $result
                let $id := $hit/data(@cr:resource-pid)                 
                group by $id
                return 
 :)
 (: using this to get a consistent / the correct order :)  
 let $resource-list := project:list-resources($project-id)[xs:string(@ID) = $resources-in-result]
 
return <sru:facetedResults>
    <sru:facet>
<sru:terms>{
                for $res in $resource-list
                let $res-id := $res/data(@ID)
                let $count := count($result[data(@cr:resource-pid) = $res-id ])
                let $label := $res/data(@LABEL)
(:                resource:label($res-id,$project-id):)
                return <sru:term>
                <sru:actualTerm>{$label}</sru:actualTerm>
                <sru:query>{$res-id}</sru:query>
                <sru:requestUrl>?operation=searchRetrieve&amp;query={$orig-query}&amp;x-context={$res-id}</sru:requestUrl>
                <sru:count>{$count}</sru:count>
            </sru:term>
            }
      <sru:facetDisplayLabel>Resource</sru:facetDisplayLabel>
        <sru:index>fcs.resource</sru:index>
        <sru:relation>=</sru:relation>        
        </sru:terms>
    </sru:facet>
</sru:facetedResults>

};

declare function fcs-db:format-record-data($record-data as node(), $data-view as xs:string*, $x-context as xs:string*, $config-param as item()*) as item()*  {
    let $result-seq-expanded := if ($config-param("x-highlight") ne "off") then
         let $log := util:log-app("TRACE", $config:app-name, "fcs:search-retrieve x-highlight = on")
         return util:expand($result-seq)
     else
         let $log := util:log-app("TRACE", $config:app-name, "fcs:search-retrieve x-highlight = off")
         return $result-seq
    return 
    fcs-db:format-record-data($record-data, $result-seq-expanded, $data-view, $x-context, $config-param)
};



(:~ generates the inside of one record according to fcs/Resource.xsd 
fcs:Resource, fcs:ResourceFragment, fcs:DataView 
all based on mappings and parameters (data-view)

@param $orig-sequence-record-data - the node from the original not expanded search result, so that we can optionally navigate outside the base_elem (for resource_fragment or so)
                    if not providable, setting the same data as in $record-data-input works mostly (expect, when you want to move out of the base_elem)
@param $record-data-input the base-element with the match hits inside (marked with exist:match) 
:)
declare function fcs-db:format-record-data($orig-sequence-record-data as node(), $expanded-record-data-input as node(), $data-view as xs:string*, $x-context as xs:string*, $config as item()*) as item()*  {
    
    let $title := index:apply-index($orig-sequence-record-data, "title", $x-context),
        $log := util:log-app("DEBUG", $config:app-name, "fcs-db:format-record-data for "||$title||" data-views: "||string-join($data-view, ', '))
    (: this is (hopefully) temporary FIX: the resource-pid attribute is in fcs-namespace (or no namespace?) on resourceFragment element!  	:)
	let $resource-pid:= ($expanded-record-data-input/ancestor-or-self::*[1]/data(@*[local-name()=$config:RESOURCE_PID_NAME]),
(:	                      index:apply-index($orig-sequence-record-data, "fcs.resource",$config,'match-only'))[1]:)
	                      index:apply-index($orig-sequence-record-data, "fcs.resource",$x-context,'match-only'))[1]
	
	let $resource-ref :=   if (exists($resource-pid)) 
	                               then 
	                                   concat('?operation=searchRetrieve&amp;query=fcs.resource="',
	                                           replace(xmldb:encode-uri(replace($resource-pid[1],'//','__')),'__','//'),
	                                           '"&amp;x-context=', $x-context,
	                                           '&amp;x-dataview=title,full',
	                                           '&amp;version=1.2'
	                                           (: rather nohighlight for full resource now
	                                           if (exists(util:expand($record-data)//exist:match/ancestor-or-self::*[@cr:id][1]))
	                                           then '&amp;x-highlight='||string-join(distinct-values(util:expand($record-data)//exist:match/ancestor-or-self::*[@cr:id][1]/@cr:id),',')
	                                           else ():)
	                                         )
	                               else ""
	
	let $project-id := cr:resolve-id-to-project-pid($x-context)
    let $match-elem := 'w'
    let $match-ids := distinct-values(
                      let $log := util:log-app("TRACE", $config:app-name, "fcs:format-record-data $expanded-record-data-input := "||substring(serialize($expanded-record-data-input), 1, 240))
                      return
                      if (exists($expanded-record-data-input//exist:match/ancestor::*[@cr:id]))
                      then 
                          let $exist-matches := $expanded-record-data-input//exist:match
                          let $log := util:log-app("TRACE", $config:app-name, "fcs:format-record-data match parents: "||string-join($exist-matches/ancestor::*[@cr:id][1]/data(@cr:id),'; '))
                          return (:$exist-matches/parent::*/data(@cr:id):)
                                for $exist-match in $exist-matches
                                return
                                    if (normalize-space(string-join($exist-match/ancestor::*[@cr:id][1]//text(), '')) eq normalize-space($exist-match//text())) 
                                    then 
                                       let $ret := fcs-db:get-complete-match-id-and-offsets-in-ancestors($exist-match),
                                           $log2 := util:log-app("TRACE", $config:app-name, "fcs:format-record-data $record-data-input match parents whole tags "||string-join($ret, '; '))
                                       return $ret
                                    else
                                       let $log := util:log-app("TRACE", $config:app-name, "fcs:format-record-data match parent: "||substring(string-join($exist-match/parent::*//text(), '<>'),1,1000)),
                                           $ret := fcs-db:recalculate-length-of-exist-match-if-cut-by-tag($exist-match/parent::*,$exist-match),
                                           $log := util:log-app("TRACE", $config:app-name, "fcs:format-record-data $record-data-input match parents with offsets "||string-join($ret, '; '))
                                       return $ret
                      else 
                        (: if no exist:match, take the root of the matching snippet,:)   
                        let $log := util:log-app("TRACE", $config:app-name, "fcs-db:format-record-data $expanded-record-data-input contains no exist:match, falling back to its own @cr:id")
                        return $expanded-record-data-input/data(@cr:id)
                      )
    (: if the match is a whole resourcefragment we dont need a lookup, its ID is in the attribute :)
    let $match-ids-without-offsets := for $m in $match-ids return fcs-db:remove-offset-from-match-id-if-exists($m)
    let $resourcefragment-pids :=   if ($expanded-record-data-input/ancestor-or-self::*[1]/@*[local-name() = $config:RESOURCEFRAGMENT_PID_NAME]) 
                                    then $expanded-record-data-input/ancestor-or-self::*[1]/data(@*[local-name() = $config:RESOURCEFRAGMENT_PID_NAME])
                                    else 
                                        if (exists($match-ids)) 
                                        then distinct-values((for $m in $match-ids-without-offsets return rf:lookup-id($m,$resource-pid,$project-id)))
                                        else util:log-app("ERROR", $config:app-name, "fcs-db:format-record-data $match-ids is empty")
    let $rfs :=      if ($expanded-record-data-input/@*[local-name()=$config:RESOURCEFRAGMENT_PID_NAME] or empty($match-ids)) 
                    then $expanded-record-data-input 
                    else
                        (: for some indexes we might only want to return a certain number of 
                           resource fragments, e.g. fcs.toc only the first one - this is defined in the
                           config map by fcs:search-retrieve() :)
                        if ($config instance of map()) 
                        then
                            if ($config("no-of-rf") castable as xs:integer)
                            then
                                for $rpid in $resourcefragment-pids[position() le xs:integer($config("no-of-rf"))] 
                                return rf:get($rpid,$resource-pid, $project-id)
                            else 
                                for $rpid in $resourcefragment-pids 
                                return rf:get($rpid,$resource-pid, $project-id)
                        else 
                            for $rpid in $resourcefragment-pids 
                            return rf:get($rpid,$resource-pid, $project-id),
         $log := util:log-app("DEBUG",$config:app-name,"fcs-db:format-record-data rfs = "||string-join(for $rf in $rfs return substring(serialize($rf),1,240), '; ')),
         $match-ids-page-splitted := fcs-db:recalculate-offset-for-match-ids-on-page-split($match-ids, $rfs)
                    
    (: iterate over all resourcefragments:)
    return
    for $rf  in $rfs
    return 
        let $resourcefragment-pid := $rf/@resourcefragment-pid
        let $dumy := util:log-app("TRACE",$config:app-name,"fcs-db:format-record-data $match-ids-page-splitted := "||string-join($match-ids-page-splitted,' ')||", $resourcefragment-pid := "||$resourcefragment-pid)                    
        let $rf-entry :=  if (exists($resourcefragment-pid)) then rf:record($resourcefragment-pid,$resource-pid, $project-id)
        else ()
        let $res-entry := $rf-entry/parent::mets:div[@TYPE=$config:PROJECT_RESOURCE_DIV_TYPE]
	
        (: $match-ids-page-splitted are always cr:ids of whole elements - it may be :)
        
(:        let $matches-to-highlight := (tokenize(request:get-parameter("x-highlight",""),","),$match-ids-page-splitted):)
(:  the predicate makes the function by SLOWER by factor 10 !!! [rf:lookup-id(.,$resource-pid, $project-id) = $resourcefragment-pid]:)
    let $matches-to-highlight:= 
      let $highlight-requests := (tokenize(request:get-parameter("x-highlight",""),","),$match-ids-page-splitted),
          $log := util:log-app("TRACE", $config:app-name, "fcs-db:format-record-data $highlight-requests := "||substring(serialize($highlight-requests),1,240))
      return $highlight-requests[fcs-db:remove-offset-from-match-id-if-exists(.) = $rf//@cr:id]
    
    let $dumy4 := util:log-app("TRACE",$config:app-name,"$resourcefragment-pid => $matches-to-highlight: "||$resourcefragment-pid||" => "||string-join($matches-to-highlight,'; '))

    let $parent-elem := ('p', 'u') (: TODO: read from configuration cql.serverChoice  :) 
    let $record-data-toprocess := <rec> { if (not($expanded-record-data-input/local-name() = $parent-elem)) then $rf else $orig-sequence-record-data } </rec>,
        $log :=  util:log-app("TRACE", $config:app-name, "fcs:format-record-data $record-data-toprocess := "||substring(serialize($record-data-toprocess),1,240))
         let $log := util:log-app("TRACE", $config:app-name, "record-data-topprocess: "||name($record-data-toprocess/*)||" record-data-input/name():"||local-name($record-data-input))
         let $log := util:log-app("TRACE", $config:app-name, "$matches-to-highlight: "||string-join($matches-to-highlight,';'))
         
                                                
        let $record-data-highlighted := 
        (: not sure if to work with $expanded-record-data-input or $rf :)
            if (exists($matches-to-highlight) and (request:get-parameter("x-highlight","") != 'off'))
                                then
                                    if ($config instance of map())
                            then 
                                    if ($config("x-highlight") = "off") 
                                        then $record-data-toprocess
                                        else fcs-db:highlight-matches-in-copy($record-data-toprocess, $matches-to-highlight, $resourcefragment-pid)
                                     else fcs-db:highlight-matches-in-copy($record-data-toprocess, $matches-to-highlight, $resourcefragment-pid)
                                else $record-data-toprocess,
            $log := util:log-app("TRACE", $config:app-name, "fcs-db:format-record-data $record-data-highlighted: "||substring(serialize($record-data-highlighted),1,24000))
    (: to repeat current $x-format param-value in the constructed requested :)
    	let $x-format := request:get-parameter("x-format", $repo-utils:responseFormatXml)
    	let $resourcefragment-ref :=   if (exists($resourcefragment-pid)) 
    	                               then 
	                                   concat('?operation=searchRetrieve&amp;query=fcs.rf="',
	                                           replace(xmldb:encode-uri(replace($resourcefragment-pid[1],'//','__')),'__','//'),
	                                           '"&amp;x-context=', $x-context,
	                                           '&amp;x-dataview=title,full',
	                                           '&amp;version=1.2',
    	                                           if (exists(util:expand($record-data-highlighted)//exist:match/ancestor-or-self::*[@cr:id][1]))
    	                                           then '&amp;x-highlight='||string-join($matches-to-highlight,',')
	                                           else ()
	                                         )
	                                   else ""
    	
        
        let $rf-window := if (config:param-value($config,"rf.window") != '' and config:param-value($config,"rf.window") castable as xs:integer) 
                          then xs:integer(config:param-value($config,"rf.window")) 
                          else 1
        
        let $rf-window-prev := for $rfp in reverse(subsequence(reverse($rf-entry/preceding-sibling::mets:div[@TYPE = $config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE]),1,$rf-window)) 
                               return rf:get($rfp/@ID,$resource-pid,$project-id)/*
                                
        let $rf-window-next := for $rfp in subsequence($rf-entry/following-sibling::mets:div[@TYPE = $config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE],1,$rf-window) 
                                return rf:get($rfp/@ID,$resource-pid,$project-id)/*
        
    (:    let $rf2 := <ref>{($record-data-highlighted)}</ref>:)
    let $rf2 := fcs-db:highlight-matches-in-copy($expanded-record-data-input, $matches-to-highlight, $resourcefragment-pid)
    (:    ,$rf-window-next:)
    (:   let $debug :=   <fcs:DataView type="debug" count="{count($record-data-highlighted)}">{transform:transform($record-data-highlighted, $fcs:flattenKwicXsl,())}</fcs:DataView>:)
         let $debug :=   <fcs:DataView type="debug" count="{count($rf)}" matchids="{$matches-to-highlight}">{$record-data-highlighted}</fcs:DataView>
        
        let $want-kwic := contains($data-view,'kwic'), 
            $kwic := if ($want-kwic) then
                     let $kwic-config := <config width="{$fcs-db:kwicWidth}"/>
                   (: tentatively kwic-ing from original input - to get the closest match
                    however this fails when matching on attributes, where the exist:match is only added in the highlighting function,
                    thus we need the processed record-data :)
    (:                   let $kwic-html := kwic:summarize($expanded-record-data-input, $kwic-config):)
                (: we create the kwic from the working copy, thus we look up the resourcefragment :)
                     (:let $wc-fragment :=  (for $m in $matches-to-highlight return wc:lookup($m,$resource-pid,$project-id))/ancestor-or-self::*[string-length(.) > $fcs:kwicWidth][1]
                 let $wc-fragment-highlighted := fcs:highlight-matches-in-copy($wc-fragment,$matches-to-highlight) 
                     let $flattened-record := transform:transform($wc-fragment-highlighted, $fcs:flattenKwicXsl,()):)
    (:                  let $kwicInput := $record-data[1]:)
     (:(\:DEBUG             :\)  let $kwicInput := ($record-data[1],$orig-sequence-record-data/ancestor-or-self::*[string-length(.) ge $fcs:kwicWidth][1])[1]
                     let $kwicInput-highlighted := $kwicInput
    (\:                 let $kwicInput-highlighted := fcs:highlight-matches-in-copy($kwicInput,$matches-to-highlight):\):)
                     (:let $log := util:log-app("TRACE", $config:app-name, $orig-sequence-record-data/ancestor::*[string-length(.) gt $fcs:kwicWidth][1]):)
                     let $flattened-record := transform:transform($record-data-highlighted, $fcs-db:flattenKwicXsl,()),
                         $logfr := util:log-app("TRACE", $config:app-name, "fcs-db:format-record-data $flattened-record := "||substring(serialize($flattened-record),1,240))
    (:                 let $flattened-record := repo-utils:serialise-as($record-data[1], 'html', $fcs:searchRetrieve, $config):)
                 
                     let $kwic-html := kwic:summarize($flattened-record, $kwic-config,util:function(xs:QName("fcs-db:filter-kwic"),2))
    (:                       DEBUG:)
    (:                    let $kwic-html := $record-data[1]:)
                       
                    return 
                           ( if (exists($kwic-html)) 
                        then  
                            for $match at $pos in $kwic-html
                            (: when the exist:match is complex element kwic:summarize leaves the keyword (= span[2]) empty, 
                            so we try to fall back to the exist:match :)
                                let $kw := if (exists($match/span[2][text()])) then $match/span[2]/text() else $record-data-highlighted[1]//exist:match[$pos]//text(),
                                    $log := util:log-app("TRACE", $config:app-name, "fcs-db:format-record-data match $kwic-html := "||substring(serialize($match), 1, 240))
                            return (<fcs:c type="left">{$match/span[1]/text()}</fcs:c>, 
                                       (: <c type="left">{kwic:truncate-previous($exp-rec, $matches[1], (), 10, (), ())}</c> :)
                                                      <fcs:kw>{$kw}</fcs:kw>,
                                                      <fcs:c type="right">{$match/span[3]/text()}</fcs:c>)            	                       
                                       (: let $summary  := kwic:get-summary($exp-rec, $matches[1], $config) :)
                        (:	                               <fcs:DataView type="kwic-html">{$kwic-html}</fcs:DataView>:)
                        
     (:DEBUG :)                                            
                        else (: if no kwic-match let's take first 100 characters 
                                        There c/should be some more sophisticated way to extract most significant info 
                                        e.g. match on the query-field :)
                            substring($record-data-highlighted[1],1,(2 * $fcs-db:kwicWidth)) ,
                            () )
                        (:<fcs:DataView>{$flattened-record}</fcs:DataView>, 
                           <fcs:DataView>{kwic:summarize($flattened-record, $kwic-config)}</fcs:DataView> ):)
                         else (),
            $log := util:log-app("TRACE", $config:app-name, "fcs:format-record-data $kwic := "||substring(serialize($kwic),1,240))                        
                         
                        
        (: prev-next :)                     
        let $dv-navigation:= if (contains($data-view,'navigation')) then
                                (:let $context-map := fcs:get-mapping("",$x-context, $config)
                              let $sort-index := if (exists($context-map/@sort)) then $context-map/@sort
                                                     else "title":)
                               (: WATCHME: this only works if default-sort and title index are the same :)
                               (:important is the $responsePosition=2 :)
    (:                          let $prev-next-scan := fcs:scan(concat($sort-index, '=', $title),$x-context, 1,3,2,1,'text','',$config):)
                                        (: handle also edge situations  
                                            expect maximum 3 terms, on the edges only 2 terms:)
                              (:let $rf-prev := if (count($prev-next-scan//sru:terms/sru:term) = 3
                                                or not($prev-next-scan//sru:terms/sru:term[1]/sru:value = $title)) then
                                                     $prev-next-scan//sru:terms/sru:term[1]/sru:value
                                                else ""
                                                     
                              let $rf-next := if (count($prev-next-scan//sru:terms/sru:term) = 3) then
                                                    $prev-next-scan//sru:terms/sru:term[3]/sru:value
                                                 else if (not($prev-next-scan//sru:terms/sru:term[2]/sru:value = $title)) then
                                                     $prev-next-scan//sru:terms/sru:term[2]/sru:value
                                                else "" 
                              :)
                              let $rf-prev := $rf-entry/preceding-sibling::mets:div[@TYPE = $config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE][1]
                              let $rf-next := $rf-entry/following-sibling::mets:div[@TYPE = $config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE][1]
                              let $log:= util:log-app("TRACE",$config:app-name,("$rf-entry := ",$rf-entry))
                              let $log:= util:log-app("TRACE",$config:app-name,("$rf-prev := ",$rf-prev))
                              let $log:= util:log-app("TRACE",$config:app-name,("$rf-next := ",$rf-next))
        
                              
                              let $rf-prev-ref := if (exists($rf-prev)) then concat('?operation=searchRetrieve&amp;query=', $config:INDEX_INTERNAL_RESOURCEFRAGMENT, '="', xmldb:encode-uri($rf-prev/data(@ID)), '"&amp;x-dataview=full&amp;x-dataview=navigation&amp;x-context=', $x-context) else ""                                                 
                              let $rf-next-ref:= if (exists($rf-next)) then concat('?operation=searchRetrieve&amp;query=', $config:INDEX_INTERNAL_RESOURCEFRAGMENT, '="', xmldb:encode-uri($rf-next/data(@ID)), '"&amp;x-dataview=full&amp;x-dataview=navigation&amp;x-context=', $x-context) else ""
                               return
                                 (<fcs:ResourceFragment type="prev" pid="{$rf-prev/data(@ID)}" ref="{$rf-prev-ref}" label="{$rf-prev/data(@LABEL)}"  />,
                                 <fcs:ResourceFragment type="next" pid="{$rf-next/data(@ID)}" ref="{$rf-next-ref}" label="{$rf-next/data(@LABEL)}"  />)
                            else ()
                            
        let $dv-facs :=     if (contains($data-view,'facs')) 
                            then 
    (:                            let $facs-uri:=fcs-db:apply-index ($expanded-record-data-input, "facs-uri",$x-context, $config):)
                                let $facs-uri := facs:get-url($resourcefragment-pid, $resource-pid, $project-id)
        				        return <fcs:DataView type="facs" ref="{$facs-uri[1]}"/>
        				    else ()
        let $dv-facs-prev := if (($rf-window gt 1) and contains($data-view,'facs') and contains($data-view,'full')) 
                            then 
                            for $rfp in reverse(subsequence(reverse($rf-entry/preceding-sibling::mets:div[@TYPE = $config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE]),1,$rf-window))
                                let $facs-uri := facs:get-url($rfp/@ID, $resource-pid, $project-id)
        				        return <fcs:DataView type="facs" ref="{$facs-uri[1]}"/>
        				    else ()
                                
        let $dv-facs-next := if (($rf-window gt 1) and contains($data-view,'facs') and contains($data-view,'full')) 
                            then for $rfp in subsequence($rf-entry/following-sibling::mets:div[@TYPE = $config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE],1,$rf-window)
                                let $facs-uri := facs:get-url($rfp/@ID, $resource-pid, $project-id)
        				        return <fcs:DataView type="facs" ref="{$facs-uri[1]}"/>
        				    else ()
                         
        let $dv-title := let $title_ := if (exists($title) and not($title='')) then $title else $res-entry/data(@LABEL)||", "||$rf-entry/data(@LABEL) 
        
                        return <fcs:DataView type="title">{$title_[1]}</fcs:DataView>
    
        let $dv-cite := if (contains($data-view,'cite')) then
                            if ($rf-entry) then rf:cite($resourcefragment-pid, $resource-pid, $project-id, $config)
                                else resource:cite($resource-pid, $project-id, $config)
                           else ()
        
        let $dv-xmlescaped := if (contains($data-view,'xmlescaped')) 
                              then <fcs:DataView type="xmlescaped">{util:serialize($record-data-highlighted,'method=xml, indent=yes')}</fcs:DataView>
                              else ()
        
        (:return if ($data-view = 'raw') then $record-data 
                else <fcs:Resource pid="{$resource-pid}">
                           <fcs:ResourceFragment pid="{$resourcefragment-pid}" ref="{$resourcefragment-ref}">{
                        ($dv-title, $kwic,
                             if ('full' = $data-view or not(exists($kwic))) then <fcs:DataView type="full">{$record-data}</fcs:DataView>
                                 else () 
                               )}</fcs:ResourceFragment>
                               {$dv-navigation}
                           </fcs:Resource>:)
                           (:                                        case "full"         return util:expand($record-data):)
        return
            if ($data-view = "raw") then $record-data-highlighted
            else if ($want-kwic and normalize-space(string-join($kwic, '')) = "") then ()
            else <fcs:Resource pid="{$resource-pid}" ref="{$resource-ref}">                
                    { (: if not resource-fragment couldn't be identified, don't put it in the result, just DataViews directly into Resource :)
                    if ($rf-entry) then 
                        <fcs:ResourceFragment pid="{$resourcefragment-pid}" ref="{$resourcefragment-ref}">{
                        for $d in tokenize($data-view,',\s*') 
                        return 
                            let $data:= switch ($d)
    (:                                        case "full"         return $rf[1]/*:)
                                            case "debug"         return $debug 
                                            case "full"         return (if ($rf-window gt 1) then $rf-window-prev else (),
                                                                       $record-data-highlighted[1]/*/*,
                                                                       if ($rf-window gt 1) then $rf-window-next else ())
                                            case "facs"         return (if ($rf-window gt 1) then $dv-facs-prev else (),
                                                                       $dv-facs,
                                                                       if ($rf-window gt 1) then $dv-facs-next else ())
                                            case "title"        return $dv-title
                                            case "cite"        return $dv-cite
                                            case "kwic"         return $kwic
                                            case "navigation"   return $dv-navigation
                                            case "xmlescaped"   return $dv-xmlescaped
                                            default             return ()
                             return if ($data instance of element(fcs:DataView)) then $data else <fcs:DataView type="{$d}">{$data}</fcs:DataView>
                    }</fcs:ResourceFragment>
                     else 
                         for $d in tokenize($data-view,',\s*') 
                            return 
                                let $data:= switch ($d)
        (:                                        case "full"         return $rf[1]/*:)
                                                case "full"         return $record-data-highlighted[1]/*/*
                                                case "facs"         return $dv-facs
                                                case "title"        return $dv-title
                                                case "cite"        return $dv-cite
                                                case "kwic"         return $kwic
                                                case "navigation"   return $dv-navigation
                                                case "xmlescaped"   return $dv-xmlescaped
                                                default             return ()
                                 return if ($data instance of element(fcs:DataView)) then $data else <fcs:DataView type="{$d}">{$data}</fcs:DataView>
                     }
                </fcs:Resource>
};

declare %private function fcs-db:remove-offset-from-match-id-if-exists($match-id as xs:string) as xs:string {
    (: There is no need to explicitly guard against replacing where there is no match :)
    (:if (matches($match-id,':\d+:\d+$')) then :)replace($match-id,':\d+:\d+.*$','')(: else $match-id:)    
};

declare %private function fcs-db:get-offset-from-mactch-id($match-id as xs:string) as xs:integer {
    replace($match-id,'^[^:]+:(\d+):(\d+).*$','$1') 
};

declare %private function fcs-db:get-match-length-from-mactch-id($match-id as xs:string) as xs:integer {
    replace($match-id,'^[^:]+:(\d+):(\d+).*$','$2') 
};

declare %private function fcs-db:get-complete-match-id-and-offsets-in-ancestors($exist-match as node()) {
let $log := util:log-app("TRACE",$config:app-name,"fcs-db:get-complete-match-id-and-offsets-in-ancestors $exist-match := "||substring(serialize($exist-match), 1, 240)),
    $logForOldMatchLogic :=  util:log-app("TRACE", $config:app-name, "fcs-db:format-record-data $exist-match := "||substring(serialize($exist-match),1,24000)||
     " $exist-match/ancestor::* := "||string-join(for $anc in $exist-match/ancestor::* return substring(serialize($anc),1,240), ' <> ')),
    $ret := (data($exist-match/ancestor::*[@cr:id][1]/@cr:id),
       for $anc in $exist-match/ancestor::*[@cr:id and exist:match] return fcs-db:recalculate-length-of-exist-match-if-cut-by-tag($anc, $exist-match)
       ),
    $logRest := util:log-app("TRACE",$config:app-name,"fcs-db:get-complete-match-id-and-offsets-in-ancestors return "||string-join($ret, '; '))
return $ret
};

(: Hack that works around exist:match highlighter not considering (empty) inline elements and stoping the match completely before that. :) 
declare %private function fcs-db:recalculate-length-of-exist-match-if-cut-by-tag($parent as node(), $exist-match as node()) {
let $exist-match-follwing-context := ($exist-match/following-sibling::*|$exist-match/following-sibling::text()),
    $log := util:log-app("TRACE",$config:app-name,"fcs-db:recalculate-length-of-exist-match-if-cut-by-tag $parent := "||substring(serialize($parent), 1, 240)||
                                                  " $exist-match := "||substring(serialize($exist-match), 1, 240)||
                                                  " $exist-match-follwing-context[1] instance of text() "||$exist-match-follwing-context[1] instance of text()||
                                                  " $exist-match-follwing-context[2] "||substring(serialize($exist-match-follwing-context[2]),1,240)),
    $ret := 
       for $substrPos in functx:index-of-string(fcs-db:get-string-for-offset-length-search($parent),$exist-match)
       let $additional-length := string-length(
          if (exists($exist-match-follwing-context[1]) and not($exist-match-follwing-context[1] instance of text())) then
          functx:substring-before-match($exist-match-follwing-context[2], '[ .,;:?!]') else ())
       return data($parent/@cr:id)||":"||$substrPos||":"||(string-length($exist-match) + $additional-length),
    $logRet := util:log-app("TRACE",$config:app-name,"fcs-db:recalculate-length-of-exist-match-if-cut-by-tag return "||string-join($ret, '; '))
return $ret
};

declare %private function fcs-db:get-string-for-offset-length-search($elt as node()+) as xs:string {
let $log := util:log-app("TRACE",$config:app-name,"fcs-db:get-string-for-offset-length-search $elt := "||string-join(for $n in $elt return substring(serialize($n), 1, 240), ' <> ')),
    (: needs to be kept in sync with highlight-matches.xsl: match="*[@cr:id = $all-ids]"! :)
    $ret := string-join((for $n in $elt/(*|text()) return if ($n[@orig]) then concat(' ', data($n/@orig)) else data($n)), ''),
    $logRet := util:log-app("TRACE",$config:app-name,"fcs-db:get-string-for-offset-length-search return "||$ret)
return $ret
};

declare function fcs-db:get-pid($mdRecord as element()) {
    let $log := util:log-app("INFO",$config:app-name,name($mdRecord))
    return
    switch (name($mdRecord))
        case "teiHeader" return $mdRecord//(idno|tei:idno)[@type='cr-xq']/xs:string(.)
        case "cmdi" return ()
        default return ()
}; 


declare function fcs-db:highlight-matches-in-copy($copy as element()+, $ids as xs:string*, $rfpid as xs:string) as element()? {
    let $stylesheet-file := "highlight-matches.xsl",
        $stylesheet:=   doc($stylesheet-file),
        $params := <parameters>
           <param name="cr-ids" value="{string-join($ids,',')}"/>
           <param name="rfpid" value="{$rfpid}"/>
        </parameters>,
        $log := util:log-app("TRACE",$config:app-name,"fcs-db:highlight-matches-in-copy $copy := "||substring(serialize($copy),1,240)||" $stylesheet := "||substring(serialize($stylesheet),1,240)||", $params := "||substring(serialize($params),1,240)),
        $ret := 
            if (exists($stylesheet)) 
            then 
                for $c in $copy
                return transform:transform($copy,$stylesheet,$params) 
            else util:log-app("ERROR",$config:app-name,"stylesheet "||$stylesheet-file||" not available."),
        $logRet := util:log-app("TRACE",$config:app-name,"fcs-db:highlight-matches-in-copy return "||substring(serialize($ret),1,240))
    return $ret
}; 

declare function fcs-db:recalculate-offset-for-match-ids-on-page-split($match-ids as xs:string*, $rfs as node()*) as xs:string* {
   let $log := util:log-app("TRACE",$config:app-name,"fcs-db:split-offset-match-ids-on-page-split $match-ids = "||string-join($match-ids, '; ')||" $rfs = "||string-join(for $rf in $rfs return substring(serialize($rf),1 ,200), '; ')),
       $ret := if ((count($rfs) <= 1) or (count($match-ids) = 0)) then $match-ids
               else
      for $m in $match-ids
         let $match-id-without-offset := fcs-db:remove-offset-from-match-id-if-exists($m),
             $matching-rfs-parts := $rfs//*[@cr:id = $match-id-without-offset],
             $match-id-splitted := count($matching-rfs-parts) = 2,
             $throw-error-on-more := if (count($rfs//*[@cr:id = $match-id-without-offset]) > 2) then error("CR_XQ_M_SPLIT_OVER_MORE_THAN_2_RF", "Not implementerd yet!") else (), 
             $log := util:log-app("TRACE",$config:app-name,"fcs-db:split-offset-match-ids-on-page-split $match-id-splitted = "||$match-id-splitted)
         return
            if (not($match-id-splitted)) then (: add rfpids only to offset+length matches :)
               if (matches($m, '^[^:]+:(\d+):(\d+).*$')) then $m||':'||$matching-rfs-parts/ancestor::fcs:resourceFragment/@resourcefragment-pid
               else $m
            else
            let $text-lengths := for $p in $matching-rfs-parts return string-length(xs:string($p)),
                $rfpids := for $p in $matching-rfs-parts return $p/ancestor::fcs:resourceFragment/@resourcefragment-pid,
                $offsets := fcs-db:calculate-offsets($text-lengths), 
                $log := util:log-app("TRACE",$config:app-name,"fcs-db:split-offset-match-ids-on-page-split current $match-id = "||$m||
                " $text-lengths = "||string-join($text-lengths, '; ')||
                " $offsets = "||string-join($offsets, '; ')),
                $new-matches := for $o at $i in $offsets
                   let $new-offset := fcs-db:get-offset-from-mactch-id($m) - $offsets[$i]
                   return if (($new-offset < 0) or 
                              ($new-offset > $offsets[$i] + $text-lengths[$i])) then () else 
                      fcs-db:remove-offset-from-match-id-if-exists($m)||":"||$new-offset||
                      ":"||fcs-db:get-match-length-from-mactch-id($m)||":"||$rfpids[$i],
                $log2 := util:log-app("TRACE",$config:app-name,"fcs-db:split-offset-match-ids-on-page-split $new-matches = "||string-join($new-matches, '; '))
            return $new-matches    
   let $logRet := util:log-app("TRACE",$config:app-name,"fcs-db:split-offset-match-ids-on-page-split return "||string-join($ret, '; '))
   return $ret
};

declare function fcs-db:calculate-offsets($text-lengths as xs:integer*) as xs:integer* {
    if (empty($text-lengths)) then ()
    else (fcs-db:calculate-offsets(subsequence($text-lengths, 1, count($text-lengths) -1)),
    sum(subsequence($text-lengths, 1, count($text-lengths) - 1)) - count(subsequence($text-lengths, 1, count($text-lengths) -1)))
};

declare function fcs-db:filter-kwic($node as node(), $mode as xs:string) as xs:string? {
    if ($mode eq 'before')
    then concat($node,' ')
    else concat(' ',$node)
};