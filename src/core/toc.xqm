xquery version "3.0";

module namespace toc="http://aac.ac.at/content_repository/toc";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "project.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "resource.xqm";
import module namespace ltb="http://aac.ac.at/content_repository/lookuptable" at "lookuptable.xqm";
import module namespace fcs = "http://clarin.eu/fcs/1.0" at "../modules/fcs/fcs.xqm";
import module namespace wc="http://aac.ac.at/content_repository/workingcopy" at "wc.xqm";

declare namespace mets="http://www.loc.gov/METS/";
declare namespace cr="http://aac.ac.at/content_repository";
(:~
 : Getter and Setter for tables of contents of resources. 
 :)
 
 
(:~
 : generates the table of contents of a resource. The structure of the resource is defined
 : by one or more index definitions in the project's mappings. The functions scans the 
 : resource's working copy for matching elements recursively and writes the toc to a 
 : special mets:structMap TYPE="toc" ID="{$resource-pid}_toc"
 :)
declare function toc:generate($mapping-keys as xs:string+, $resource-pid as xs:string, $project-pid as xs:string) as item()* {
   let $mappings:=project:map($project-pid),
       $indexes := for $m in $mapping-keys return $mappings//index[@key eq $m],
       $paths := for $i in $indexes return fcs:index-as-xpath($i,$project-pid,()),
       $ltb-path := "xmldb:exist://"||resource:path($resource-pid,$project-pid,"lookuptable"),
       $project-path := "xmldb:exist://"||project:filepath($project-pid)

   let $resource-label := resource:label($resource-pid, $project-pid)
   let $resource-ref := '#'||$resource-pid
   let $xslTemplates:= 
                for $p at $pos in $paths
                    let $index := $indexes[position() eq $pos]
                    return
                        <xsl:template xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:mets="http://www.loc.gov/METS/" match="{$p}">
                            <xsl:variable name="cr:id" select="@cr:id"/>
                            <xsl:variable name="content" as="item()*">
                                <xsl:apply-templates/>
                            </xsl:variable>
                            
                            <mets:div TYPE="{$index/@key}" ID="&#x007b;$cr:id&#x007d;">
                                {if (exists($index/path/@label))
                                then 
                                    <xsl:attribute name="LABEL" select="({string-join($index/path/@label,'|')})[1]"/>
                                else 
                                    <xsl:attribute name="LABEL" select="concat('{$index/@key} ',count(preceding::{$p})+1)"/>
                                }
                                <xsl:choose>
                                    <xsl:when test="empty($content)">
                                        <xsl:for-each select="key('rf',$cr:id,$ltb)">
                                            <xsl:sequence select="key('rf-div',@resourcefragment-pid,$project)/mets:fptr[mets:area]"/>
                                        </xsl:for-each>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:sequence select="$content"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                                
                                
                            </mets:div>
                        </xsl:template>
    let $xsl := 
                <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                    xmlns:xs="http://www.w3.org/2001/XMLSchema"
                    xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
                    xmlns:mets="http://www.loc.gov/METS/"
                    xmlns:xlink="http://www.w3.org/1999/xlink"
                    xmlns:fcs="http://clarin.eu/fcs/1.0"
                    xmlns:cr="http://aac.ac.at/content_repository"
                    xmlns:tei="http://www.tei-c.org/ns/1.0"
                    exclude-result-prefixes="#all"
                    version="2.0">
                     
                    <xsl:output method="xml" indent="yes"/>
                    
                    
                    <xsl:variable name="ltb" select="doc('{$ltb-path}')"/>
                    <xsl:variable name="project" select="doc('{$project-path}')"/>
                    <xsl:key name="rf" match="fcs:{$config:RESOURCE_RESOURCEFRAGMENT_ELEMENT_NAME}" use="cr:id"/>
                    <xsl:key name="rf-div" match="mets:div" use="@ID"/>
                    
                    
                    <xsl:template match="text()"/>
                    
                    <xsl:template match="*">
                        <xsl:apply-templates/>
                    </xsl:template>
                    
                    
                    <xsl:template match="/" priority="1">
                        <mets:div TYPE="resource" CONTENTIDS="#{$resource-pid}" LABEL="{$resource-label/text()}" ID="{$resource-pid}_toc">
                            <xsl:apply-templates/>
                        </mets:div>
                    </xsl:template>
                    
                    {$xslTemplates}
                    
                </xsl:stylesheet>

    
    let $resource := wc:get-data($resource-pid,$project-pid),
        $toc := transform:transform($resource,$xsl,())
        
   let $mets:record := project:get($project-pid),
       $mets:structMap-exists := $mets:record//mets:structMap[@TYPE=$config:PROJECT_TOC_STRUCTMAP_TYPE]
  
 return (if (not(exists($mets:record))) then util:log-app("INFO",$config:app-name,"no METS-Record found in config for "||$project-pid )
        else if(exists($mets:structMap-exists)) then 
                    if (exists($mets:structMap-exists/mets:div/mets:div[@CONTENTIDS=$resource-ref])) then 
                        update replace $mets:structMap-exists/mets:div/mets:div[@CONTENTIDS=$resource-ref] 
                               with $toc
                      else 
                        update insert $toc 
                               into $mets:structMap-exists/mets:div 
            else update insert <mets:structMap TYPE="{$config:PROJECT_TOC_STRUCTMAP_TYPE}" >
                                   <mets:div>{$toc}</mets:div>
                               </mets:structMap>
                        into $mets:record,
        util:log-app("INFO",$config:app-name,"generated TOC from indexes "||string-join($mapping-keys,',')||"for resource "||$resource-pid||" in cr-project "||$project-pid||"." )
     )
};

declare %private function toc:expand-cr-ids($item as item()) as item() {
    typeswitch($item)
        case document-node()    return toc:expand-cr-ids($item)
        case element(mets:area) return 
                                    let $rf-pids:=ltb:lookup(xs:string(.),$resource-pid, $project-pid)
                                    return element {name($item)} {
                                                $item/@*,
                                                attribute BEGIN     {$rf-pids[1]},
                                                attribute END       {$rf-pids[last()]},
                                                attribute BETYPE    {"IDREF"}
                                           }
        case element()          return 
                                    element {name($item)} {
                                        $item/@*,
                                        for $i in $item/node() return toc:expand-cr-ids($i)
                                      }
        default                 return $item 
};

(:~
 : Sets the (logical) TOC of a given resource. 
~:)
declare function toc:set($data as element(mets:div), $resource-pid as xs:string, $project-pid as xs:string) {
    let $toc := toc:get($resource-pid,$project-pid)
    return 
        if (exists($toc))
        then update replace $toc with $data
        else 
            let $tocStructMap := toc:get($resource-pid,$project-pid)
            return 
                if (exists($tocStructMap))
                then update insert $data into $tocStructMap
                else
                    let $newStructMap := 
                        <mets:structMap TYPE="{$config:PROJECT_TOC_STRUCTMAP_TYPE}" ID="{$project-pid}_toc">
                            <div TYPE="{$config:PROJECT_TOC_STRUCTMAP_ROOT_TYPE}">{$data}</div>
                        </mets:structMap>
                    let $doc := project:get($project-pid)
                return update insert $newStructMap into $doc 
};

(:~
 : Returns the (logical) TOC of a given resource. 
~:)
declare function toc:get($resource-pid as xs:string, $project-pid as xs:string) as element(mets:div)? {
    toc:get($project-pid)/mets:div[@CONTENTIDS='#'||$resource-pid]
};

(:~
 : Returns the (logical) TOC of a given project. 
~:)
declare function toc:get($project-pid as xs:string) as element(mets:div)? {
    project:get($project-pid)//mets:structMap[@TYPE=$config:PROJECT_TOC_STRUCTMAP_TYPE]/mets:div
};

