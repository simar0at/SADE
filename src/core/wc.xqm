xquery version "3.0";

module namespace wc="http://aac.ac.at/content_repository/workingcopy";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm"; 
import module namespace resource="http://aac.ac.at/content_repository/resource" at "resource.xqm";
import module namespace master="http://aac.ac.at/content_repository/master" at "master.xqm";
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";

(:~
 : Getter / setter / storage functions for the entity "working copy".
 :
 : Creating a working copy is the first step of ingesting data into the content repository.
 : Essentially it is an identity transformation of the data with the following information bits
 : added to each element():
 : 
 : - a locally unique xml:id (@cr:id)
 : - the project wide unique pid of the cr resource which it represents (@cr:resource-pid)
 : - the content repository wide unique id of the project the resource is part of (@cr:project-id)
 :
 : All queries which are performed on a project's dataset, are performed on working copies, while 
 : the master of the data is just kept as reference. This is crucial as it facilitates 
 : mapping the arbitrary search result on the FCS data structure (i.e. 'resources' and 
 : 'resource fragments'), as well as consistent match higlighting between structural searches (i.e. 
 : standard xpath) and fulltext or ngram searches which do not offer match highlighting for attribute 
 : values.
 :
 : Stored working copies have to be registered with a resource in the project's mets:record by adding a
 : mets:file element to the resource's mets:fileGrp with an appropriate value in its @USE attribute. 
 : This value is globally set in the variable $config:RESOURCE_WORKINGCOPY_FILE_USE, by default it is 'WORKING COPY'.
 :
 : The storage path of a working copy may be defined in the project's config, in a parameter 
 : with the key 'working-copies.path'. The default path is set globally in the 
 : variable $config:default-working-copy-path.
 :
 : @author daniel.schopper@oeaw.ac.at
 : @since 2013-11-08
~:)



(: declaration of helper namespaces for better code structuring :)
declare namespace param="userinput.parameters";
declare namespace this="current.object";

declare namespace mets="http://www.loc.gov/METS/";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace fcs = "http://clarin.eu/fcs/1.0";
declare namespace cr="http://aac.ac.at/content_repository";


(:~
 : Path to the stylesheet which creates the working copy.
~:)
declare variable $wc:path-to-xsl:=      "wc.xsl";
declare variable $wc:default-path:=     $config:default-workingcopy-path;
declare variable $wc:filename-prefix:=  $config:RESOURCE_WORKINGCOPY_FILENAME_PREFIX;

(:~
 : Generates a working copy from the $resource-pid, stores it in the database and 
 : registers it with the resources entry.
 : 
 : @param $param:resource-pid the pid of the resource 
 : @param $param:project-id the id of the project to work in
 : @return the path to the working copy
~:)
declare function wc:generate($param:resource-pid as xs:string, $param:project-id as xs:string) as xs:string? {
    let $config:=config:config($param:project-id),
        $wc:path-param:=replace(resource:path($param:resource-pid,$param:project-id,'workingcopies'),'/$',''),
        $master:file:=master:get($param:resource-pid,$param:project-id)/mets:FLocat/xs:string(@xlink:href),
        $master:filename:=tokenize($master:file/mets:FLocat/xs:string(@xlink:href),'/')[last()],
        $wc:filename := $wc:filename-prefix||$master:filename
    return 
    switch(true())
            case $wc-path eq '' 
                return util:log("INFO","$wc-path empty!")
            case not(exists(collection($wc-path)))
                return util:log("INFO","$wc-path does not exist, cannot store working copy for resource "||$param:resource-pid)
            default 
                return  
                    let $xsl-params:=
                                <parameters>
                                    <param name="resource-pid" value="{$resource-pid}"/>
                                    <param name="project-id" value="{$project}"/>
                                </parameters>,
                        $wc:generated:=transform:transform($doc,doc($wc:path-to-xsl),$xsl-params),
                        $store-wc := repo-utils:store-in-cache($wc-filename,$wc-path,$wc:generated,$config)
                    (: register working copy with :)
                    let $update-mets:= if ($store-wc) then wc:add($wc-path||"/"||$wc-filename,$resource-pid,$project) else ()
                    return $store-wc 
};

(:~
 : Removes the data of a working copy from the database.
 :  
 : @param $param:resource-pid pid of the resource 
 : @param $param:x-context id of the project
 : @return empty()
~:)
declare function wc:remove-data($param:resource-pid,$param:x-context) as empty() {
    let $wc:path:=          wc:get-path($param:resource-pid, $param:x-context),
        $wc:filename:=      tokenize($wc:path,'/')[last()],
        $wc:collection:=    substring-before($wc:path,$wc:filename)
    return xmldb:remove($wc:collection,$wc:filename)
};

(:~
 : Gets the registered working copy as its mets:file.
 : 
 : @param $param:resource-pid pid of the resource 
 : @param $param:x-context id of the project
 : @return the mets:file entry of the working copy.
~:)
declare function wc:get($param:resource-pid,$param:x-context) as element(mets:file)? {
    let $mets:record:=config:config($param:x-context),
        $mets:resource:=resource:get($param:resource-pid,$param:x-context),
        $mets:resource-files:=resource:get-resourcefiles($param:resource-pid,$param:x-context)
        (: the working copy is one of several <fptr> elements directly under the resource's mets:div, e.g. :)
        (: <div TYPE='resource'>
                    <fptr FILEID="id-of-masterfile"/>
                    <fptr FILEID="id-of-workingcopy"/>
                    <fptr FILEID="id-of-resourcefragments-file"/>
                    ....
                </div>
        :)
        (: we have to find the right <file> element by looking at all of them and determining each one's @USE attribute :)
    let $mets:workingcopy:=$mets:resource-files/mets:file[@USE eq $config:RESOURCE_WORKINGCOPY_FILE_USE]
    return $mets:workingcopy
};

(:~
 : Returns the database path to the content of the resource's working copy.
 : 
 : @param $param:resource-pid the pid of the resource
 : @param $param:x-context: the id of the current project
 : @return the path the workingcopy of the resource as xs:anyURI 
~:)
declare function wc:get-path($param:resource-pid,$param:x-context) as xs:anyURI? {
    let $wc:=wc:get($param:resource-pid,$param:x-context)
    return xs:anyURI($wc/mets:FLocat/@xlink:href)
};

(:~
 : Returns the content of a working copy as a document-node().
 : 
 : @param $param:resource-pid the pid of the resource
 : @param $x-context: the id of the current project
 : @return if available, the document node of the working copy, otherwise an empty sequence. 
~:)
declare function wc:get-data($param:resource-pid,$param:x-context) as document-node()? {
    let $wc-path:=wc:get-path($param:resource-pid,$param:x-context)
    return 
        if (doc-available($wc-path))
        then doc($wc-path)
        else util:log("INFO","requested file at "||$wc-path||" is not available.")
};


(:~
 : Registers the data of a working copy with the resource by appending a mets:file element to
 : the resources mets:fileGrp.
 : If there is already a working copy registered with this resource, it will be replaced.
 : Note that this function does not actually create and store the working copy. This is done by 
 : wc:generate() which calls this function.
 : 
 : @param $param:path the path to the stored working copy
 : @param $param:resource-pid the pid of the resource
 : @param $param:x-context: the id of the current project
 : @return the added mets:file element 
~:)
declare function wc:add($param:path as xs:string,$param:resource-pid as xs:string,$param:context as xs:string) as element(mets:file)? {
    let $mets:resource:=resource:get($param:resource-pid,$param:context)
    let $mets:wc-file:=wc:get($param:resource-pid,$param:context),
        $mets:wc-fptr:=$mets:resource//mets:fptr[@FILEID eq $mets:wc-file/@ID]
    let $this:wc-fileid:=$param:resource-pid||$config:RESOURCE_WORKINGCOPY_FILEID_SUFFIX,
        $this:wc-file:=resource:make-file($this:wc-fileid,$param:path,"wc"), 
        $this:wc-fptr:=<mets:fptr FILEID="{$this:wc-fileid}"/>
    return
        if (exists($mets:wc-file))
        then 
            let $replace-file:=update replace $mets:wc-file with $this:wc-file
            let $replace-fileptr:=update replace $mets:wc-fptr with $this:wc-fptr
            return $this:wc-file
        else 
            (: we insert the wc <file> right after the resource's master <file> :)
            let $insert-file:=update insert $this:wc-file preceding resource:get-resourcefiles($param:resource-pid,$param:context)/mets:*[1]
            (: we insert the wc <fptr> right after the <fptr> to the resource's master file :)
            let $insert-fileptr:=update insert $this:wc-fptr following $mets:resource/mets:fptr[1]
            return $this:wc-file            
};